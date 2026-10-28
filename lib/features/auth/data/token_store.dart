import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The access token lives only in memory (short-lived); the refresh token is
/// kept in the platform keystore so the session survives restarts. A copy of
/// the last `/me` profile is kept too, so the app can open offline.
class TokenStore {
  TokenStore(this._secure);

  final FlutterSecureStorage _secure;
  static const _refreshKey = 'auth.refreshToken';
  static const _profileKey = 'auth.profile';

  String? _accessToken;
  String? _refreshToken;

  String? get accessToken => _accessToken;

  Future<String?> readRefreshToken() async => _refreshToken ??= await _secure.read(key: _refreshKey);

  Future<void> save({required String accessToken, required String refreshToken}) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    await _secure.write(key: _refreshKey, value: refreshToken);
  }

  Future<void> saveProfile(String meJson) => _secure.write(key: _profileKey, value: meJson);

  Future<String?> readProfile() => _secure.read(key: _profileKey);

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    await _secure.delete(key: _refreshKey);
    await _secure.delete(key: _profileKey);
  }
}
