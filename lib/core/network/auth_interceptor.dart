import 'package:dio/dio.dart';

/// Attaches the access token and, when the API answers 401, refreshes the
/// session once and replays the request. Errors are queued while a refresh is
/// in flight, so concurrent 401s trigger a single refresh.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.retryClient,
    required this.accessToken,
    required this.refresh,
    required this.onSessionExpired,
  });

  /// Plain client (without this interceptor) used to replay requests. Replaying
  /// through the intercepted client would deadlock if the replay also failed,
  /// because its error would queue behind the handler awaiting it.
  final Dio retryClient;
  final String? Function() accessToken;

  /// Refreshes the session; returns false if the server ended it (user must
  /// sign in again). Throws on network errors, which leave the session intact.
  final Future<bool> Function() refresh;
  final void Function() onSessionExpired;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = accessToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) return handler.next(err);
    final options = err.requestOptions;

    // A queued request may find the token already refreshed by an earlier one.
    final current = accessToken();
    final alreadyRefreshed = current != null && options.headers['Authorization'] != 'Bearer $current';

    if (!alreadyRefreshed) {
      final bool refreshed;
      try {
        refreshed = await refresh();
      } catch (_) {
        return handler.next(err); // offline: keep the session, surface the error
      }
      if (!refreshed) {
        onSessionExpired();
        return handler.next(err);
      }
    }

    try {
      options.headers['Authorization'] = 'Bearer ${accessToken()}';
      handler.resolve(await retryClient.fetch<dynamic>(options));
    } on DioException catch (retryError) {
      if (retryError.response?.statusCode == 401) onSessionExpired();
      handler.next(retryError);
    }
  }
}
