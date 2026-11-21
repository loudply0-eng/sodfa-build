import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'sodfa_secure_session_store.dart';

const _compiledApiBaseUrl = String.fromEnvironment(
  'SODFA_API_BASE_URL',
  defaultValue: '',
);

class SodfaApiConfigurationException implements Exception {
  const SodfaApiConfigurationException(this.message);
  final String message;

  @override
  String toString() => 'SodfaApiConfigurationException: $message';
}

class SodfaApiException implements Exception {
  const SodfaApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => 'SodfaApiException($statusCode, $code): $message';
}

class SodfaApiClient {
  SodfaApiClient({
    http.Client? httpClient,
    SodfaCredentialStore? credentials,
    String? baseUrl,
  })  : _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null,
        _credentials = credentials ?? SodfaSecureSessionStore(),
        _baseUri = _parseBaseUri(baseUrl ?? _compiledApiBaseUrl);

  static final SodfaApiClient instance = SodfaApiClient();

  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final SodfaCredentialStore _credentials;
  final Uri? _baseUri;
  Future<bool>? _refreshing;

  bool get isConfigured => _baseUri != null;

  static Uri? _parseBaseUri(String raw) {
    if (raw.trim().isEmpty) return null;

    final uri = Uri.parse(raw.trim());
    final host = uri.host.toLowerCase();
    final isLoopback = host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1';

    if (!uri.hasAuthority ||
        host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const SodfaApiConfigurationException(
        'The SODFA API URL must be a clean absolute URL.',
      );
    }

    if (uri.scheme != 'https' && !(uri.scheme == 'http' && isLoopback)) {
      throw const SodfaApiConfigurationException(
        'SODFA API connections require HTTPS. HTTP is allowed only for loopback development.',
      );
    }

    final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
    return uri.replace(path: path);
  }

  Uri _endpoint(String path) {
    final base = _baseUri;
    if (base == null) {
      throw const SodfaApiConfigurationException(
        'The SODFA API is not configured in this build.',
      );
    }
    if (!path.startsWith('/')) {
      throw ArgumentError.value(path, 'path', 'API paths must start with /.');
    }
    return base.resolve(path);
  }

  Future<http.Response> _sendRaw(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? accessToken,
  }) async {
    final request = http.Request(method, _endpoint(path));
    request.headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }
    if (accessToken != null && accessToken.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }

    final streamed = await _httpClient
        .send(request)
        .timeout(const Duration(seconds: 20));
    return http.Response.fromStream(streamed)
        .timeout(const Duration(seconds: 30));
  }

  Map<String, dynamic> _decode(http.Response response) {
    Object? decoded;
    if (response.body.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        decoded = null;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final root = decoded is Map ? decoded : const <String, dynamic>{};
      final rawError = root['error'];
      final error = rawError is Map ? rawError : const <String, dynamic>{};
      throw SodfaApiException(
        statusCode: response.statusCode,
        code: error['code']?.toString() ?? 'HTTP_${response.statusCode}',
        message: error['message']?.toString() ?? 'The request could not be completed.',
      );
    }

    if (decoded == null && response.body.trim().isEmpty) {
      return <String, dynamic>{};
    }
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('The SODFA API returned an unexpected response.');
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool authenticated = true,
    bool allowRefresh = true,
  }) async {
    final accessToken = authenticated
        ? await _credentials.readAccessToken()
        : null;
    var response = await _sendRaw(
      method,
      path,
      body: body,
      accessToken: accessToken,
    );

    if (authenticated &&
        allowRefresh &&
        response.statusCode == 401 &&
        await _refreshSession()) {
      final renewedAccessToken = await _credentials.readAccessToken();
      response = await _sendRaw(
        method,
        path,
        body: body,
        accessToken: renewedAccessToken,
      );
    }

    return _decode(response);
  }

  Future<bool> _refreshSession() async {
    final activeRefresh = _refreshing;
    if (activeRefresh != null) return activeRefresh;

    final pending = _performRefresh();
    _refreshing = pending;
    try {
      return await pending;
    } finally {
      _refreshing = null;
    }
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await _credentials.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    final response = await _sendRaw(
      'POST',
      '/v1/auth/refresh',
      body: {'refreshToken': refreshToken},
    );

    if (response.statusCode == 400 || response.statusCode == 401) {
      await _credentials.clear();
      return false;
    }

    final payload = _decode(response);
    await _saveTokens(payload);
    return true;
  }

  Future<void> _saveTokens(Map<String, dynamic> payload) async {
    final accessToken = payload['accessToken'];
    final refreshToken = payload['refreshToken'];
    final expiresIn = payload['expiresIn'];

    if (accessToken is! String ||
        refreshToken is! String ||
        expiresIn is! num ||
        accessToken.isEmpty ||
        refreshToken.isEmpty ||
        expiresIn <= 0) {
      throw const FormatException('The SODFA API returned an invalid session.');
    }

    await _credentials.writeTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.now().toUtc().add(
        Duration(seconds: expiresIn.toInt()),
      ),
    );
  }

  Map<String, dynamic> _withoutSecrets(Map<String, dynamic> payload) {
    final result = Map<String, dynamic>.from(payload);
    result.remove('accessToken');
    result.remove('refreshToken');
    result.remove('tokenType');
    return result;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String username,
    required String displayName,
    required String password,
  }) {
    return _request(
      'POST',
      '/v1/auth/register',
      authenticated: false,
      body: {
        'email': email,
        'username': username,
        'displayName': displayName,
        'password': password,
      },
    );
  }

  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String code,
  }) {
    return _request(
      'POST',
      '/v1/auth/verify-email',
      authenticated: false,
      body: {'email': email, 'code': code},
    );
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final payload = await _request(
      'POST',
      '/v1/auth/login',
      authenticated: false,
      body: {'email': email, 'password': password},
    );
    await _saveTokens(payload);
    return _withoutSecrets(payload);
  }

  Future<Map<String, dynamic>> currentUser() =>
      _request('GET', '/v1/me');

  Future<Map<String, dynamic>> getFeed({
    String scope = 'following',
    int limit = 20,
    String? before,
  }) {
    if (!const {'following', 'discover'}.contains(scope)) {
      throw ArgumentError.value(scope, 'scope');
    }
    if (limit < 1 || limit > 50) throw ArgumentError.value(limit, 'limit');
    final query = <String, String>{
      'scope': scope,
      'limit': '$limit',
      if (before != null && before.isNotEmpty) 'before': before,
    };
    return _request('GET', '/v1/feed?${Uri(queryParameters: query).query}');
  }

  Future<Map<String, dynamic>> createPost({
    required String body,
    String visibility = 'public',
  }) {
    if (!const {'public', 'followers'}.contains(visibility)) {
      throw ArgumentError.value(visibility, 'visibility');
    }
    return _request(
      'POST',
      '/v1/posts',
      body: {'body': body, 'visibility': visibility},
    );
  }

  Future<Map<String, dynamic>> searchUsers(String query, {int limit = 20}) {
    if (query.trim().length < 2) {
      throw ArgumentError.value(query, 'query', 'Enter at least two characters.');
    }
    if (limit < 1 || limit > 50) throw ArgumentError.value(limit, 'limit');
    final parameters = Uri(queryParameters: {
      'q': query.trim(),
      'limit': '$limit',
    }).query;
    return _request('GET', '/v1/discover/users?$parameters');
  }

  Future<Map<String, dynamic>> getStories({int limit = 20, String? before}) {
    if (limit < 1 || limit > 50) throw ArgumentError.value(limit, 'limit');
    final query = <String, String>{
      'limit': '$limit',
      if (before != null && before.isNotEmpty) 'before': before,
    };
    return _request('GET', '/v1/stories?${Uri(queryParameters: query).query}');
  }

  Future<Map<String, dynamic>> getConversations() =>
      _request('GET', '/v1/conversations');

  Future<Map<String, dynamic>> createDirectConversation(String userId) {
    final id = _uuidSegment(userId, 'userId');
    return _request(
      'POST',
      '/v1/conversations/direct',
      body: {'userId': id},
    );
  }


  static String _uuidSegment(String value, String name) {
    const pattern =
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$';
    if (!RegExp(pattern).hasMatch(value)) {
      throw ArgumentError.value(value, name, 'A valid UUID is required.');
    }
    return value;
  }

  Future<Map<String, dynamic>> resendVerification({required String email}) =>
      _request(
        'POST',
        '/v1/auth/resend-verification',
        authenticated: false,
        body: {'email': email},
      );

  Future<Map<String, dynamic>> updateMyProfile({
    String? displayName,
    String? bio,
    bool? isPrivate,
    bool? discoverable,
    String? preferredLanguage,
  }) {
    final body = <String, Object?>{
      if (displayName != null) 'displayName': displayName,
      if (bio != null) 'bio': bio,
      if (isPrivate != null) 'isPrivate': isPrivate,
      if (discoverable != null) 'discoverable': discoverable,
      if (preferredLanguage != null) 'preferredLanguage': preferredLanguage,
    };
    if (body.isEmpty) throw ArgumentError('At least one profile field is required.');
    return _request('PATCH', '/v1/me/profile', body: body);
  }

  Future<Map<String, dynamic>> getProfile(String username) {
    final value = username.trim();
    if (!RegExp(r'^[a-zA-Z0-9_]{3,24}$').hasMatch(value)) {
      throw ArgumentError.value(username, 'username');
    }
    return _request('GET', '/v1/users/' + value);
  }

  Future<Map<String, dynamic>> followUser(String userId) {
    final id = _uuidSegment(userId, 'userId');
    return _request('POST', '/v1/users/' + id + '/follow', body: const {});
  }

  Future<Map<String, dynamic>> unfollowUser(String userId) =>
      _request('DELETE', '/v1/users/' + _uuidSegment(userId, 'userId') + '/follow');

  Future<Map<String, dynamic>> getFollowStatus(String userId) =>
      _request('GET', '/v1/users/' + _uuidSegment(userId, 'userId') + '/follow-status');

  Future<Map<String, dynamic>> getFollowers() =>
      _request('GET', '/v1/me/followers');

  Future<Map<String, dynamic>> getFollowing() =>
      _request('GET', '/v1/me/following');

  Future<Map<String, dynamic>> getFollowRequests() =>
      _request('GET', '/v1/me/follow-requests');

  Future<Map<String, dynamic>> acceptFollowRequest(String userId) {
    final id = _uuidSegment(userId, 'userId');
    return _request('POST', '/v1/me/follow-requests/' + id + '/accept', body: const {});
  }

  Future<Map<String, dynamic>> declineFollowRequest(String userId) {
    final id = _uuidSegment(userId, 'userId');
    return _request('POST', '/v1/me/follow-requests/' + id + '/decline', body: const {});
  }

  Future<Map<String, dynamic>> getProfilePosts(
    String username, {
    int limit = 20,
    String? before,
  }) {
    final value = username.trim();
    if (!RegExp(r'^[a-zA-Z0-9_]{3,24}$').hasMatch(value)) {
      throw ArgumentError.value(username, 'username');
    }
    _validatePage(limit, max: 50);
    final cursor = before == null ? null : _uuidSegment(before, 'before');
    return _request(
      'GET',
      '/v1/users/' + value + '/posts?' + _pageQuery(limit, cursor),
    );
  }

  Future<Map<String, dynamic>> getPost(String postId) =>
      _request('GET', '/v1/posts/' + _uuidSegment(postId, 'postId'));

  Future<Map<String, dynamic>> deletePost(String postId) =>
      _request('DELETE', '/v1/posts/' + _uuidSegment(postId, 'postId'));

  Future<Map<String, dynamic>> likePost(String postId) {
    final id = _uuidSegment(postId, 'postId');
    return _request('POST', '/v1/posts/' + id + '/like', body: const {});
  }

  Future<Map<String, dynamic>> unlikePost(String postId) =>
      _request('DELETE', '/v1/posts/' + _uuidSegment(postId, 'postId') + '/like');

  Future<Map<String, dynamic>> bookmarkPost(String postId) {
    final id = _uuidSegment(postId, 'postId');
    return _request('POST', '/v1/posts/' + id + '/bookmark', body: const {});
  }

  Future<Map<String, dynamic>> unbookmarkPost(String postId) =>
      _request('DELETE', '/v1/posts/' + _uuidSegment(postId, 'postId') + '/bookmark');

  Future<Map<String, dynamic>> getBookmarks({
    int limit = 20,
    String? before,
  }) {
    _validatePage(limit, max: 50);
    final cursor = before == null ? null : _uuidSegment(before, 'before');
    return _request('GET', '/v1/me/bookmarks?' + _pageQuery(limit, cursor));
  }

  Future<Map<String, dynamic>> getPostComments(
    String postId, {
    int limit = 20,
    String? before,
  }) {
    final id = _uuidSegment(postId, 'postId');
    _validatePage(limit, max: 50);
    final cursor = before == null ? null : _uuidSegment(before, 'before');
    return _request(
      'GET',
      '/v1/posts/' + id + '/comments?' + _pageQuery(limit, cursor),
    );
  }

  Future<Map<String, dynamic>> createComment({
    required String postId,
    required String body,
  }) {
    final id = _uuidSegment(postId, 'postId');
    final value = body.trim();
    if (value.isEmpty || value.length > 1000) {
      throw ArgumentError.value(body, 'body');
    }
    return _request(
      'POST',
      '/v1/posts/' + id + '/comments',
      body: {'body': value},
    );
  }

  Future<Map<String, dynamic>> deleteComment({
    required String postId,
    required String commentId,
  }) {
    final post = _uuidSegment(postId, 'postId');
    final comment = _uuidSegment(commentId, 'commentId');
    return _request('DELETE', '/v1/posts/' + post + '/comments/' + comment);
  }

  Future<Map<String, dynamic>> createStory({
    required String body,
    String visibility = 'public',
  }) {
    final value = body.trim();
    if (value.isEmpty || value.length > 2000) {
      throw ArgumentError.value(body, 'body');
    }
    if (!const {'public', 'followers'}.contains(visibility)) {
      throw ArgumentError.value(visibility, 'visibility');
    }
    return _request(
      'POST',
      '/v1/stories',
      body: {'body': value, 'visibility': visibility},
    );
  }

  Future<Map<String, dynamic>> getStory(String storyId) =>
      _request('GET', '/v1/stories/' + _uuidSegment(storyId, 'storyId'));

  Future<Map<String, dynamic>> markStoryViewed(String storyId) {
    final id = _uuidSegment(storyId, 'storyId');
    return _request('POST', '/v1/stories/' + id + '/view', body: const {});
  }

  Future<Map<String, dynamic>> getStoryViewers(String storyId) =>
      _request('GET', '/v1/stories/' + _uuidSegment(storyId, 'storyId') + '/viewers');

  Future<Map<String, dynamic>> deleteStory(String storyId) =>
      _request('DELETE', '/v1/stories/' + _uuidSegment(storyId, 'storyId'));

  Future<Map<String, dynamic>> createGroupConversation({
    required String title,
    required List<String> memberIds,
  }) {
    final cleanTitle = title.trim();
    if (cleanTitle.length < 2 || cleanTitle.length > 80) {
      throw ArgumentError.value(title, 'title');
    }
    if (memberIds.isEmpty ||
        memberIds.length > 49 ||
        memberIds.toSet().length != memberIds.length) {
      throw ArgumentError.value(memberIds, 'memberIds');
    }
    final cleanIds = memberIds.map((id) => _uuidSegment(id, 'memberIds')).toList();
    return _request(
      'POST',
      '/v1/conversations/group',
      body: {'title': cleanTitle, 'memberIds': cleanIds},
    );
  }

  Future<Map<String, dynamic>> getConversationMembers(String conversationId) =>
      _request(
        'GET',
        '/v1/conversations/' + _uuidSegment(conversationId, 'conversationId') + '/members',
      );

  Future<Map<String, dynamic>> getMessages(
    String conversationId, {
    int limit = 50,
    String? before,
  }) {
    final id = _uuidSegment(conversationId, 'conversationId');
    _validatePage(limit, max: 100);
    final cursor = before == null ? null : _uuidSegment(before, 'before');
    return _request(
      'GET',
      '/v1/conversations/' + id + '/messages?' + _pageQuery(limit, cursor),
    );
  }

  Future<Map<String, dynamic>> sendEncryptedMessage({
    required String conversationId,
    required String ciphertext,
    required String nonce,
    required String senderKeyId,
  }) {
    final id = _uuidSegment(conversationId, 'conversationId');
    final keyId = _uuidSegment(senderKeyId, 'senderKeyId');
    if (!RegExp(r'^[A-Za-z0-9_-]{16,16000}$').hasMatch(ciphertext)) {
      throw ArgumentError.value(ciphertext, 'ciphertext');
    }
    if (!RegExp(r'^[A-Za-z0-9_-]{16,128}$').hasMatch(nonce)) {
      throw ArgumentError.value(nonce, 'nonce');
    }
    return _request(
      'POST',
      '/v1/conversations/' + id + '/messages',
      body: {
        'ciphertext': ciphertext,
        'nonce': nonce,
        'senderKeyId': keyId,
        'protocolVersion': 'opaque-v1',
      },
    );
  }

  Future<Map<String, dynamic>> markConversationRead({
    required String conversationId,
    required String messageId,
  }) =>
      _request(
        'POST',
        '/v1/conversations/' + _uuidSegment(conversationId, 'conversationId') + '/read',
        body: {'messageId': _uuidSegment(messageId, 'messageId')},
      );

  Future<Map<String, dynamic>> blockUser(String userId) {
    final id = _uuidSegment(userId, 'userId');
    return _request('POST', '/v1/users/' + id + '/block', body: const {});
  }

  Future<Map<String, dynamic>> unblockUser(String userId) =>
      _request('DELETE', '/v1/users/' + _uuidSegment(userId, 'userId') + '/block');

  Future<Map<String, dynamic>> reportUser({
    required String userId,
    required String category,
    String? details,
  }) {
    const categories = {
      'harassment',
      'spam',
      'impersonation',
      'inappropriate_content',
      'underage',
      'other',
    };
    if (!categories.contains(category)) {
      throw ArgumentError.value(category, 'category');
    }
    if (details != null && details.trim().length > 1000) {
      throw ArgumentError.value(details, 'details');
    }
    return _request(
      'POST',
      '/v1/users/' + _uuidSegment(userId, 'userId') + '/report',
      body: {
        'category': category,
        if (details != null && details.trim().isNotEmpty)
          'details': details.trim(),
      },
    );
  }

  Future<WebSocket> connectRealtime() async {
    final token = await _credentials.readAccessToken();
    if (token == null || token.isEmpty) {
      throw const SodfaApiException(
        statusCode: 401,
        code: 'AUTHENTICATION_REQUIRED',
        message: 'Sign in before opening a realtime connection.',
      );
    }
    final endpoint = _endpoint('/v1/realtime');
    final socketUri = endpoint.replace(
      scheme: endpoint.scheme == 'https' ? 'wss' : 'ws',
    );
    return WebSocket.connect(
      socketUri.toString(),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));
  }

  static void _validatePage(int limit, {required int max}) {
    if (limit < 1 || limit > max) throw ArgumentError.value(limit, 'limit');
  }

  static String _pageQuery(int limit, String? before) {
    final query = <String, String>{
      'limit': '$limit',
      if (before != null && before.isNotEmpty) 'before': before,
    };
    return Uri(queryParameters: query).query;
  }

  Future<Map<String, dynamic>> logout() async {
    try {
      return await _request(
        'POST',
        '/v1/auth/logout',
        body: const <String, Object?>{},
      );
    } finally {
      await _credentials.clear();
    }
  }

  void close() {
    if (_ownsHttpClient) _httpClient.close();
  }
}
