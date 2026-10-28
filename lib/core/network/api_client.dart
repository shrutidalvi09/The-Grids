import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

BaseOptions apiOptions(AppConfig config) => BaseOptions(
      baseUrl: '${config.apiBaseUrl}/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    );

/// Unauthenticated client, for sign-in endpoints and token refresh.
final publicDioProvider = Provider<Dio>((ref) {
  final dio = Dio(apiOptions(ref.watch(appConfigProvider)));
  ref.onDispose(dio.close);
  return dio;
});
