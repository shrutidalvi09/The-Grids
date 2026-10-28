import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Last successful GET responses, so screens still show data offline.
abstract interface class ResponseCache {
  Future<Object?> read(String scope, String key);
  Future<void> write(String scope, String key, Object? data);

  /// Removes everything (sign-out: the next person on this phone sees nothing).
  Future<void> clear();
}

/// JSON files in the app's private support directory, one folder per
/// membership so switching society or role never mixes data.
class FileResponseCache implements ResponseCache {
  FileResponseCache([Future<Directory> Function()? root]) : _root = root ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _root;

  Future<File> _file(String scope, String key) async {
    final base = await _root();
    return File('${base.path}${Platform.pathSeparator}api_cache${Platform.pathSeparator}'
        '${_hash(scope)}${Platform.pathSeparator}${_hash(key)}.json');
  }

  @override
  Future<Object?> read(String scope, String key) async {
    try {
      final file = await _file(scope, key);
      if (!await file.exists()) return null;
      return jsonDecode(await file.readAsString());
    } catch (_) {
      return null; // a corrupt entry is just a cache miss
    }
  }

  @override
  Future<void> write(String scope, String key, Object? data) async {
    try {
      final file = await _file(scope, key);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {
      // Caching is best effort; never fail the request because of it.
    }
  }

  @override
  Future<void> clear() async {
    try {
      final dir = Directory('${(await _root()).path}${Platform.pathSeparator}api_cache');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Never block sign-out; entries are also scoped per membership.
    }
  }

  /// FNV-1a (64-bit): short, filesystem-safe names for long URLs.
  static String _hash(String input) {
    var hash = 0xcbf29ce484222325;
    for (final unit in utf8.encode(input)) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toUnsigned(64).toRadixString(16);
  }
}

class MemoryResponseCache implements ResponseCache {
  final _entries = <String, Object?>{};

  @override
  Future<Object?> read(String scope, String key) async => _entries['$scope|$key'];

  @override
  Future<void> write(String scope, String key, Object? data) async => _entries['$scope|$key'] = data;

  @override
  Future<void> clear() async => _entries.clear();
}

/// Saves JSON GET responses and, when the network is unreachable, answers the
/// same GET from the cache (marked with `extra['fromCache'] = true`).
class OfflineCacheInterceptor extends Interceptor {
  OfflineCacheInterceptor({required this.cache, required this.scope, required this.onOnlineChanged});

  final ResponseCache cache;

  /// The current membership, or null when signed out (nothing is cached).
  final String? Function() scope;
  final void Function(bool online) onOnlineChanged;

  static String _key(RequestOptions o) => o.uri.toString();

  static bool _cacheable(RequestOptions o) => o.method == 'GET' && o.responseType == ResponseType.json;

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    onOnlineChanged(true);
    final s = scope();
    if (s != null && _cacheable(response.requestOptions) && response.statusCode == 200) {
      cache.write(s, _key(response.requestOptions), response.data);
    }
    handler.next(response);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final unreachable = err.response == null &&
        const {
          DioExceptionType.connectionError,
          DioExceptionType.connectionTimeout,
          DioExceptionType.receiveTimeout,
          DioExceptionType.sendTimeout,
        }.contains(err.type);
    if (!unreachable) {
      if (err.response != null) onOnlineChanged(true);
      return handler.next(err);
    }
    onOnlineChanged(false);
    final s = scope();
    if (s == null || !_cacheable(err.requestOptions)) return handler.next(err);
    final cached = await cache.read(s, _key(err.requestOptions));
    if (cached == null) return handler.next(err);
    handler.resolve(
      Response<dynamic>(
        requestOptions: err.requestOptions,
        data: cached,
        statusCode: 200,
        extra: {'fromCache': true},
      ),
    );
  }
}

final responseCacheProvider = Provider<ResponseCache>((ref) => FileResponseCache());

/// False after a request couldn't reach the server (until one succeeds).
class OnlineStatus extends Notifier<bool> {
  @override
  bool build() => true;

  void report(bool online) {
    if (state != online) state = online;
  }
}

final onlineStatusProvider = NotifierProvider<OnlineStatus, bool>(OnlineStatus.new);
