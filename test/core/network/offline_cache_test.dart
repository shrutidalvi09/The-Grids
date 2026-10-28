import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_grids/core/network/auth_interceptor.dart';
import 'package:the_grids/core/network/offline_cache.dart';

import '../../helpers/fakes.dart';

void main() {
  late bool online;
  late String? scope;
  late MemoryResponseCache cache;
  late List<bool> statusReports;

  Dio client(FakeHttpAdapter adapter) => Dio(BaseOptions(baseUrl: 'http://api.test/v1'))
    ..httpClientAdapter = adapter
    ..interceptors.add(OfflineCacheInterceptor(cache: cache, scope: () => scope, onOnlineChanged: statusReports.add));

  setUp(() {
    online = true;
    scope = 'membership-1';
    cache = MemoryResponseCache();
    statusReports = [];
  });

  FakeHttpAdapter server() => FakeHttpAdapter((o) {
        if (!online) throw offline(o);
        return (200, {'path': o.path, 'n': 1});
      });

  test('serves the last saved GET when the network is down', () async {
    final dio = client(server());
    await dio.get<Map<String, dynamic>>('/notices');

    online = false;
    final cached = await dio.get<Map<String, dynamic>>('/notices');
    expect(cached.data, {'path': '/notices', 'n': 1});
    expect(cached.extra['fromCache'], isTrue);
    expect(statusReports, [true, false]);
  });

  test('still fails offline when nothing was saved, or for writes', () async {
    final dio = client(server());
    await dio.get<void>('/notices');
    online = false;
    await expectLater(dio.get<void>('/polls'), throwsA(isA<DioException>()));
    await expectLater(dio.post<void>('/notices'), throwsA(isA<DioException>()));
  });

  test('keeps each membership separate and saves nothing when signed out', () async {
    final dio = client(server());
    await dio.get<void>('/dues/mine');

    online = false;
    scope = 'membership-2'; // switched role/society
    await expectLater(dio.get<void>('/dues/mine'), throwsA(isA<DioException>()));

    scope = null;
    online = true;
    await dio.get<void>('/home');
    online = false;
    await expectLater(dio.get<void>('/home'), throwsA(isA<DioException>()));
  });

  test('server errors are not treated as offline', () async {
    final dio = client(FakeHttpAdapter((o) => (500, apiError('INTERNAL'))));
    await expectLater(dio.get<void>('/home'), throwsA(isA<DioException>()));
    expect(statusReports, [true]);
  });

  test('file cache round-trips JSON and clears everything', () async {
    final dir = await Directory.systemTemp.createTemp('grids_cache_test');
    addTearDown(() => dir.delete(recursive: true));
    final files = FileResponseCache(() async => dir);

    await files.write('m1', 'http://api.test/v1/notices?limit=3', [
      {'id': 'n1', 'title': 'Lift'},
    ]);
    expect(await files.read('m1', 'http://api.test/v1/notices?limit=3'), [
      {'id': 'n1', 'title': 'Lift'},
    ]);
    expect(await files.read('m2', 'http://api.test/v1/notices?limit=3'), isNull);

    await files.clear();
    expect(await files.read('m1', 'http://api.test/v1/notices?limit=3'), isNull);
  });

  test('back online with an expired token counts as online again', () async {
    // Opened offline from the saved profile: no access token yet.
    String? token;
    final adapter = FakeHttpAdapter((o) {
      if (!online) throw offline(o);
      return o.headers['Authorization'] == 'Bearer fresh' ? (200, {'ok': true}) : (401, apiError('UNAUTHENTICATED'));
    });
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test/v1'))
      ..httpClientAdapter = adapter
      ..interceptors.add(OfflineCacheInterceptor(cache: cache, scope: () => scope, onOnlineChanged: statusReports.add))
      ..interceptors.add(AuthInterceptor(
        retryClient: Dio(BaseOptions(baseUrl: 'http://api.test/v1'))..httpClientAdapter = adapter,
        accessToken: () => token,
        refresh: () async {
          token = 'fresh';
          return true;
        },
        onSessionExpired: () {},
      ));

    online = false;
    await expectLater(dio.get<void>('/home'), throwsA(isA<DioException>()));
    online = true;
    final res = await dio.get<Map<String, dynamic>>('/home');
    expect(res.data, {'ok': true});
    expect(statusReports.last, isTrue);
  });
}
