import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/offline_cache.dart';
import '../domain/auth_repository.dart';
import '../presentation/session_controller.dart';
import 'http_auth_repository.dart';
import 'token_store.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore(ref.watch(secureStorageProvider)));

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => HttpAuthRepository(dio: ref.watch(publicDioProvider), tokens: ref.watch(tokenStoreProvider)),
);

/// Client for authenticated endpoints: adds the token, refreshes on 401,
/// signs the user out if the session can't be refreshed, and serves the last
/// saved copy of GET responses when offline. Feature data layers use this.
final authedDioProvider = Provider<Dio>((ref) {
  final options = apiOptions(ref.watch(appConfigProvider));
  final repository = ref.watch(authRepositoryProvider);
  final retryClient = Dio(options);
  final dio = Dio(options)
    // First, so it also sees the 401s the auth interceptor resolves by
    // refreshing (any server reply means we're back online).
    ..interceptors.add(
      OfflineCacheInterceptor(
        cache: ref.watch(responseCacheProvider),
        scope: () => ref.read(sessionKeyProvider),
        onOnlineChanged: (online) => ref.read(onlineStatusProvider.notifier).report(online),
      ),
    )
    ..interceptors.add(
      AuthInterceptor(
        retryClient: retryClient,
        accessToken: () => repository.accessToken,
        refresh: repository.refreshSession,
        onSessionExpired: () => ref.read(sessionControllerProvider.notifier).expire(),
      ),
    );
  ref.onDispose(() {
    dio.close();
    retryClient.close();
  });
  return dio;
});
