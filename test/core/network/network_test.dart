import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_grids/core/l10n/l10n.dart';
import 'package:the_grids/core/network/api_exception.dart';
import 'package:the_grids/core/network/auth_interceptor.dart';

import '../../helpers/fakes.dart';

void main() {
  group('ApiException.fromDio', () {
    final options = RequestOptions(path: '/x');

    test('reads the API error envelope', () {
      final e = ApiException.fromDio(DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 400,
          data: apiError('OTP_INVALID', details: {'attemptsLeft': 3}),
        ),
      ));
      expect(e.code, 'OTP_INVALID');
      expect(e.statusCode, 400);
      expect(e.attemptsLeft, 3);
    });

    test('no response means network', () {
      expect(ApiException.fromDio(offline(options)).code, ApiException.network);
    });

    test('unexpected bodies become UNKNOWN', () {
      final e = ApiException.fromDio(DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 502, data: '<html>'),
      ));
      expect(e.code, ApiException.unknown);
    });
  });

  test('describeError maps codes to localised text', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(describeError(l10n, const ApiException(code: 'NOT_REGISTERED', message: '')),
        'Not registered – contact your society admin');
    expect(describeError(l10n, const ApiException(code: 'OTP_INVALID', message: '', details: {'attemptsLeft': 1})),
        'Incorrect code. 1 attempt left.');
    expect(describeError(l10n, const ApiException(code: 'OTP_COOLDOWN', message: '', details: {'retryAfterSeconds': 12})),
        'Please wait 12s before requesting a new code.');
    expect(describeError(l10n, StateError('boom')), l10n.errorGeneric);
  });

  group('AuthInterceptor', () {
    late String? token;
    late int refreshes;
    late int expirations;
    late Future<bool> Function() refresh;

    /// The server accepts only the token "fresh".
    (int, Object?) server(RequestOptions o) =>
        o.headers['Authorization'] == 'Bearer fresh' ? (200, {'ok': true}) : (401, apiError('UNAUTHENTICATED'));

    Dio client() {
      final adapter = FakeHttpAdapter(server);
      final retry = Dio()..httpClientAdapter = adapter;
      return Dio()
        ..httpClientAdapter = adapter
        ..interceptors.add(AuthInterceptor(
          retryClient: retry,
          accessToken: () => token,
          refresh: () => refresh(),
          onSessionExpired: () => expirations++,
        ));
    }

    setUp(() {
      token = 'stale';
      refreshes = 0;
      expirations = 0;
      refresh = () async {
        refreshes++;
        token = 'fresh';
        return true;
      };
    });

    test('refreshes once on 401 and replays the request', () async {
      final response = await client().get<Map<String, dynamic>>('/me');
      expect(response.data, {'ok': true});
      expect(refreshes, 1);
      expect(expirations, 0);
    });

    test('concurrent 401s share a single refresh', () async {
      final dio = client();
      final results = await Future.wait([dio.get<dynamic>('/a'), dio.get<dynamic>('/b'), dio.get<dynamic>('/c')]);
      expect(results.map((r) => r.statusCode), [200, 200, 200]);
      expect(refreshes, 1);
    });

    test('signs out when the session cannot be refreshed', () async {
      refresh = () async => false;
      await expectLater(client().get<dynamic>('/me'), throwsA(isA<DioException>()));
      expect(expirations, 1);
    });

    test('keeps the session when refresh fails because the network is down', () async {
      refresh = () async => throw const ApiException(code: ApiException.network, message: 'offline');
      await expectLater(client().get<dynamic>('/me'), throwsA(isA<DioException>()));
      expect(expirations, 0);
    });
  });
}
