import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sodfa/services/sodfa_api_client.dart';
import 'package:sodfa/services/sodfa_secure_session_store.dart';

class MemoryCredentialStore implements SodfaCredentialStore {
  String? accessToken;
  String? refreshToken;
  DateTime? expiresAt;

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    this.expiresAt = expiresAt;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    expiresAt = null;
  }
}

http.Response jsonResponse(int status, Map<String, Object?> body) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: const {'content-type': 'application/json'},
    );

void main() {
  test('API remains disabled when no production base URL is configured', () async {
    var called = false;
    final client = SodfaApiClient(
      baseUrl: '',
      httpClient: MockClient((request) async {
        called = true;
        return jsonResponse(200, const {});
      }),
      credentials: MemoryCredentialStore(),
    );

    expect(client.isConfigured, isFalse);
    await expectLater(
      client.currentUser(),
      throwsA(isA<SodfaApiConfigurationException>()),
    );
    expect(called, isFalse);
  });

  test('refuses non-HTTPS remote API URLs', () {
    expect(
      () => SodfaApiClient(
        baseUrl: 'http://api.example.com',
        httpClient: MockClient((_) async => jsonResponse(200, const {})),
        credentials: MemoryCredentialStore(),
      ),
      throwsA(isA<SodfaApiConfigurationException>()),
    );
  });

  test('login stores tokens and never returns token values', () async {
    final credentials = MemoryCredentialStore();
    final client = SodfaApiClient(
      baseUrl: 'https://api.sodfa.example',
      credentials: credentials,
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/v1/auth/login');
        return http.Response(
          jsonEncode({
            'user': {'id': 'u1'},
            'tokenType': 'Bearer',
            'accessToken': 'access-secret',
            'refreshToken': 'refresh-secret',
            'expiresIn': 900,
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );

    final result = await client.login(email: 'a@example.com', password: 'long-password');

    expect(result.containsKey('accessToken'), isFalse);
    expect(result.containsKey('refreshToken'), isFalse);
    expect(credentials.accessToken, 'access-secret');
    expect(credentials.refreshToken, 'refresh-secret');
    expect(credentials.expiresAt, isNotNull);
    client.close();
  });

  test('expired access token is refreshed once and request is retried', () async {
    final credentials = MemoryCredentialStore()
      ..accessToken = 'expired-access'
      ..refreshToken = 'old-refresh';
    final seen = <String>[];
    final client = SodfaApiClient(
      baseUrl: 'https://api.sodfa.example',
      credentials: credentials,
      httpClient: MockClient((request) async {
        seen.add('${request.url.path}:${request.headers['authorization'] ?? ''}');
        if (request.url.path == '/v1/me' &&
            request.headers['authorization'] == 'Bearer expired-access') {
          return http.Response(
            jsonEncode({'error': {'code': 'INVALID_ACCESS_TOKEN', 'message': 'expired'}}),
            401,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/v1/auth/refresh') {
          expect(request.body, contains('old-refresh'));
          return http.Response(
            jsonEncode({
              'tokenType': 'Bearer',
              'accessToken': 'new-access',
              'refreshToken': 'new-refresh',
              'expiresIn': 900,
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/v1/me' &&
            request.headers['authorization'] == 'Bearer new-access') {
          return http.Response(
            jsonEncode({'user': {'id': 'u1', 'username': 'test'}}),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return jsonResponse(500, const {'error': {'code': 'UNEXPECTED'}});
      }),
    );

    final result = await client.currentUser();

    expect((result['user'] as Map)['username'], 'test');
    expect(credentials.accessToken, 'new-access');
    expect(credentials.refreshToken, 'new-refresh');
    expect(seen.where((item) => item.startsWith('/v1/me:')).length, 2);
    expect(seen.where((item) => item.startsWith('/v1/auth/refresh:')).length, 1);
    client.close();
  });


  test('post and story methods use authenticated endpoints and valid payloads', () async {
    final credentials = MemoryCredentialStore()..accessToken = 'access-token';
    final calls = <String>[];
    final client = SodfaApiClient(
      baseUrl: 'https://api.sodfa.example',
      credentials: credentials,
      httpClient: MockClient((request) async {
        calls.add(request.method + ' ' + request.url.path + '?' + request.url.query);
        expect(request.headers['authorization'], 'Bearer access-token');
        if (request.url.path == '/v1/posts') {
          expect(jsonDecode(request.body), {
            'body': 'منشور جديد',
            'visibility': 'followers',
          });
          return jsonResponse(201, const {'post': {'id': 'post-1'}});
        }
        if (request.url.path == '/v1/stories') {
          expect(jsonDecode(request.body), {
            'body': 'قصة قصيرة',
            'visibility': 'public',
          });
          return jsonResponse(201, const {'story': {'id': 'story-1'}});
        }
        if (request.url.path == '/v1/discover/users') {
          expect(request.url.queryParameters['q'], 'أحمد علي');
          return jsonResponse(200, const {'users': []});
        }
        return jsonResponse(404, const {'error': {'code': 'NOT_FOUND'}});
      }),
    );

    final post = await client.createPost(
      body: 'منشور جديد',
      visibility: 'followers',
    );
    final story = await client.createStory(body: 'قصة قصيرة');
    await client.searchUsers('أحمد علي');

    expect((post['post'] as Map)['id'], 'post-1');
    expect((story['story'] as Map)['id'], 'story-1');
    expect(calls.length, 3);
    expect(
      () => client.createStory(body: ' '),
      throwsA(isA<ArgumentError>()),
    );
    client.close();
  });

  test('encrypted message helper rejects invalid envelope fields and invalid IDs', () async {
    final credentials = MemoryCredentialStore()..accessToken = 'access-token';
    final client = SodfaApiClient(
      baseUrl: 'https://api.sodfa.example',
      credentials: credentials,
      httpClient: MockClient((_) async => jsonResponse(201, const {'message': {}})),
    );

    expect(
      () => client.sendEncryptedMessage(
        conversationId: 'conversation-1',
        ciphertext: 'hello this is plaintext',
        nonce: 'invalid',
        senderKeyId: 'not-a-uuid',
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => client.createDirectConversation('not-a-uuid'),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => client.reportUser(userId: 'not-a-uuid', category: 'spam'),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => client.reportUser(
        userId: '123e4567-e89b-42d3-a456-426614174000',
        category: 'made_up_category',
      ),
      throwsA(isA<ArgumentError>()),
    );
    client.close();
  });

  test('realtime connection refuses to proceed without an access token', () async {
    final client = SodfaApiClient(
      baseUrl: 'https://api.sodfa.example',
      credentials: MemoryCredentialStore(),
      httpClient: MockClient((_) async => jsonResponse(200, const {})),
    );

    await expectLater(
      client.connectRealtime(),
      throwsA(isA<SodfaApiException>()),
    );
    client.close();
  });

  test('logout clears local credentials even when API call fails', () async {
    final credentials = MemoryCredentialStore()
      ..accessToken = 'access'
      ..refreshToken = 'refresh';
    final client = SodfaApiClient(
      baseUrl: 'https://api.sodfa.example',
      credentials: credentials,
      httpClient: MockClient((_) async => jsonResponse(
        503,
        const {'error': {'code': 'UNAVAILABLE', 'message': 'offline'}},
      )),
    );

    await expectLater(client.logout(), throwsA(isA<SodfaApiException>()));
    expect(credentials.accessToken, isNull);
    expect(credentials.refreshToken, isNull);
    client.close();
  });
}
