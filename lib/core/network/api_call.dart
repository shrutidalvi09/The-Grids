import 'package:dio/dio.dart';

import 'api_exception.dart';

typedef Json = Map<String, dynamic>;

/// Runs a request and turns Dio errors into [ApiException]s.
Future<T> apiCall<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
}

/// Parses an ISO-8601 timestamp from the API into local time.
DateTime parseTime(Object? value) => DateTime.parse(value as String).toLocal();

DateTime? parseTimeOrNull(Object? value) => value == null ? null : parseTime(value);

List<T> parseList<T>(Object? data, T Function(Json json) parse) =>
    [for (final item in data as List<dynamic>) parse(item as Json)];
