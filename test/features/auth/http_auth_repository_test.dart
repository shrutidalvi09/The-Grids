import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_grids/core/network/api_exception.dart';
import 'package:the_grids/features/auth/data/http_auth_repository.dart';
import 'package:the_grids/features/auth/data/token_store.dart';
import 'package:the_grids/features/auth/domain/user_role.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeHttpAdapter adapter;
  late HttpAuthRepository repo;
  late FlutterSecureStorage storage;
  late (int, Object?) Function(RequestOptions) handler;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    storage = const FlutterSecureStorage();
    handler = (o) => (404, apiError('NOT_FOUND'));
    adapter = FakeHttpAdapter((o) => handler(o));
    repo = HttpAuthRepository(
      dio: Dio(BaseOptions(baseUrl: 'http://api/v1'))..httpClientAdapter = adapter,
      tokens: TokenStore(storage),
    );
  });

  Future<String?> storedRefresh() => storage.read(key: 'auth.refreshToken');

  test('requestOtp sends the role as the API spells it and parses the challenge', () async {
    handler = (o) => (200, {'challengeId': 'c1', 'expiresInSeconds': 300, 'resendInSeconds': 30, 'devCode': '111111'});
    final challenge = await repo.requestOtp(phone: '9000000001', societyId: 's1', role: UserRole.tenant);

    expect(adapter.requests.single.data, {'phone': '9000000001', 'societyId': 's1', 'role': 'TENANT'});
    expect(challenge.resendIn, const Duration(seconds: 30));
    expect(challenge.devCode, '111111');
  });

  test('errors surface as ApiException with the server code', () async {
    handler = (o) => (404, apiError('NOT_REGISTERED'));
    await expectLater(
      repo.requestOtp(phone: '9', societyId: 's1', role: UserRole.owner),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'NOT_REGISTERED')),
    );
  });

  test('verifyOtp stores tokens and returns the session with all memberships', () async {
    handler = (o) => (200, sessionJson());
    final session = await repo.verifyOtp(challengeId: 'c1', code: '123456');

    expect(session.displayName, 'Shruti Chetan Dalvi');
    expect(session.role, UserRole.owner);
    expect(session.flatLabel, 'Tower-C, 502');
    expect(session.memberships.map((m) => m.role), [UserRole.owner, UserRole.admin]);
    expect(repo.accessToken, 'a1');
    expect(await storedRefresh(), 'r1');
  });

  group('restoreSession', () {
    test('nothing saved → null, without calling the server', () async {
      expect(await repo.restoreSession(), isNull);
      expect(adapter.requests, isEmpty);
    });

    test('rotates the saved refresh token', () async {
      await storage.write(key: 'auth.refreshToken', value: 'r1');
      handler = (o) => (200, sessionJson(access: 'a2', refresh: 'r2'));

      final session = await repo.restoreSession();
      expect(session, isNotNull);
      expect(adapter.requests.single.data, {'refreshToken': 'r1'});
      expect(await storedRefresh(), 'r2');
    });

    test('a rejected token is cleared', () async {
      await storage.write(key: 'auth.refreshToken', value: 'r1');
      handler = (o) => (401, apiError('INVALID_REFRESH_TOKEN'));

      expect(await repo.restoreSession(), isNull);
      expect(await storedRefresh(), isNull);
    });

    test('offline after a previous sign-in opens with the saved profile', () async {
      handler = (o) => (200, sessionJson());
      await repo.verifyOtp(challengeId: 'c1', code: '123456');

      handler = (o) => throw offline(o);
      final session = await repo.restoreSession();
      expect(session!.displayName, 'Shruti Chetan Dalvi');
      expect(session.role, UserRole.owner);
      expect(await storedRefresh(), 'r1'); // refreshes once back online
    });

    test('signing out forgets the saved profile too', () async {
      handler = (o) => (200, sessionJson());
      await repo.verifyOtp(challengeId: 'c1', code: '123456');
      await repo.signOut();
      expect(await storage.read(key: 'auth.profile'), isNull);
    });

    test('offline with no saved profile keeps the token and reports a network error', () async {
      await storage.write(key: 'auth.refreshToken', value: 'r1');
      handler = (o) => throw offline(o);

      await expectLater(
        repo.restoreSession(),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiException.network)),
      );
      expect(await storedRefresh(), 'r1');
    });
  });

  test('switchMembership refreshes an expired access token and retries', () async {
    handler = (o) => (200, sessionJson(access: 'old', refresh: 'r1'));
    await repo.verifyOtp(challengeId: 'c', code: '123456');

    handler = (o) => switch (o.path) {
          '/auth/switch' when o.headers['Authorization'] == 'Bearer old' => (401, apiError('UNAUTHENTICATED')),
          '/auth/refresh' => (200, sessionJson(access: 'new', refresh: 'r2')),
          '/auth/switch' => (200, sessionJson(access: 'switched', refresh: 'r3', role: 'ADMIN')),
          _ => (404, null),
        };

    final session = await repo.switchMembership('m2');
    expect(session.role, UserRole.admin);
    expect(adapter.requests.last.data, {'membershipId': 'm2', 'refreshToken': 'r2'});
    expect(repo.accessToken, 'switched');
  });

  test('signOut clears locally even when the server is unreachable', () async {
    handler = (o) => (200, sessionJson());
    await repo.verifyOtp(challengeId: 'c', code: '123456');

    handler = (o) => throw offline(o);
    await repo.signOut();
    expect(repo.accessToken, isNull);
    expect(await storedRefresh(), isNull);
  });
}
