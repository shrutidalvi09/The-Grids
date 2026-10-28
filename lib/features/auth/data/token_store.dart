import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The access token lives only in memory (short-lived); the refresh token is
/// kept in the platform keystore so the session survives restarts.
class TokenStore {
  TokenStore(this._secure);

  final FlutterSecureStorage _secure;
  static const _refreshKey = 'auth.refreshToken';

  String? _accessToken;
  String? _refreshToken;

  String? get accessToken => _accessToken;

  Future<String?> readRefreshToken() async => _refreshToken ??= await _secure.read(key: _refreshKey);

  Future<void> save({required String accessToken, required String refreshToken}) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    await _secure.write(key: _refreshKey, value: refreshToken);
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    await _secure.delete(key: _refreshKey);
  }
}
