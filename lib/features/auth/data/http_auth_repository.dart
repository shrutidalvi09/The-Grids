import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';
import '../domain/session.dart';
import '../domain/user_role.dart';
import 'auth_dto.dart';
import 'token_store.dart';

class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository({required Dio dio, required TokenStore tokens})
      : _dio = dio,
        _tokens = tokens;

  /// Unauthenticated client: these endpoints carry their own credentials.
  final Dio _dio;
  final TokenStore _tokens;

  @override
  String? get accessToken => _tokens.accessToken;

  @override
  Future<List<Society>> searchSocieties(String query) => _call(() async {
        final response = await _dio.get<List<dynamic>>(
          '/societies',
          queryParameters: {if (query.trim().isNotEmpty) 'search': query.trim()},
        );
        return [for (final s in response.data!) societyFromJson(s as Json)];
      });

  @override
  Future<OtpChallenge> requestOtp({
    required String phone,
    required String societyId,
    required UserRole role,
  }) =>
      _call(() async {
        final response = await _dio.post<Json>(
          '/auth/otp/request',
          data: {'phone': phone, 'societyId': societyId, 'role': role.apiName},
        );
        return otpChallengeFromJson(response.data!);
      });

  @override
  Future<AppSession> verifyOtp({required String challengeId, required String code}) => _call(() async {
        final response = await _dio.post<Json>(
          '/auth/otp/verify',
          data: {'challengeId': challengeId, 'code': code},
        );
        return _store(response.data!);
      });

  @override
  Future<AppSession?> restoreSession() async {
    if (await _tokens.readRefreshToken() == null) return null;
    try {
      return await _refresh();
    } on ApiException catch (e) {
      if (e.code == ApiException.network) {
        // Offline at launch: open with the last known profile; screens show
        // cached data and the session refreshes on the first request online.
        final saved = await _tokens.readProfile();
        if (saved != null) return sessionFromMeJson(jsonDecode(saved) as Json);
        rethrow; // keep the token; retry later
      }
      await _tokens.clear();
      return null;
    }
  }

  @override
  Future<bool> refreshSession() async {
    try {
      return await _refresh() != null;
    } on ApiException catch (e) {
      if (e.code == ApiException.network) rethrow;
      await _tokens.clear();
      return false;
    }
  }

  @override
  Future<AppSession> switchMembership(String membershipId) => _call(() async {
        Future<Response<Json>> send() async => _dio.post<Json>(
              '/auth/switch',
              data: {'membershipId': membershipId, 'refreshToken': await _tokens.readRefreshToken()},
              options: Options(headers: {'Authorization': 'Bearer ${_tokens.accessToken}'}),
            );

        Response<Json> response;
        try {
          response = await send();
        } on DioException catch (e) {
          // Access token expired: refresh once and try again.
          if (e.response?.statusCode != 401 || !await refreshSession()) rethrow;
          response = await send();
        }
        return _store(response.data!);
      });

  @override
  Future<void> signOut() async {
    final refreshToken = await _tokens.readRefreshToken();
    await _tokens.clear();
    if (refreshToken == null) return;
    try {
      await _dio.post<void>('/auth/logout', data: {'refreshToken': refreshToken});
    } on DioException {
      // Best effort: the token is gone locally and expires server-side anyway.
    }
  }

  Future<AppSession?> _refresh() => _call(() async {
        final refreshToken = await _tokens.readRefreshToken();
        if (refreshToken == null) return null;
        final response = await _dio.post<Json>('/auth/refresh', data: {'refreshToken': refreshToken});
        return _store(response.data!);
      });

  Future<AppSession> _store(Json body) async {
    await _tokens.save(
      accessToken: body['accessToken'] as String,
      refreshToken: body['refreshToken'] as String,
    );
    final me = body['me'] as Json;
    await _tokens.saveProfile(jsonEncode(me));
    return sessionFromMeJson(me);
  }

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
