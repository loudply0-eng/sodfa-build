import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SodfaCredentialStore {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  });
  Future<void> clear();
}

class SodfaSecureSessionStore implements SodfaCredentialStore {
  SodfaSecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? FlutterSecureStorage(
          aOptions: AndroidOptions(),
        );

  static const _accessTokenKey = 'sodfa.session.access.v1';
  static const _refreshTokenKey = 'sodfa.session.refresh.v1';
  static const _expiresAtKey = 'sodfa.session.expires_at.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<DateTime?> readExpiresAt() async {
    final value = await _storage.read(key: _expiresAtKey);
    if (value == null) return null;
    final milliseconds = int.tryParse(value);
    if (milliseconds == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  }

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) async {
    if (accessToken.trim().isEmpty || refreshToken.trim().isEmpty) {
      throw ArgumentError('SODFA session tokens must not be empty.');
    }

    // Store the refresh token first so an interrupted write never leaves an
    // apparently valid access token with no way to renew the session.
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(
      key: _expiresAtKey,
      value: '${expiresAt.toUtc().millisecondsSinceEpoch}',
    );
    await _storage.write(key: _accessTokenKey, value: accessToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _expiresAtKey);
  }
}
