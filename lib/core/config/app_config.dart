import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum Flavor { dev, prod }

/// Build-time configuration chosen by the entrypoint (`main_dev.dart` /
/// `main_prod.dart`).
class AppConfig {
  const AppConfig({required this.flavor});

  final Flavor flavor;

  bool get isDev => flavor == Flavor.dev;

  /// Override with `--dart-define=API_BASE_URL=http://192.168.1.10:3000`,
  /// e.g. when running on a physical phone on the same Wi-Fi.
  static const _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// Root of the backend (without `/v1`). In dev this is the host machine as
  /// seen from the Android emulator.
  String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    return switch (flavor) {
      Flavor.dev => 'http://10.0.2.2:3000',
      Flavor.prod => 'https://api.thegrids.app',
    };
  }

  // Firebase (push notifications). Pass with --dart-define-from-file=firebase.json;
  // without them the app still works, with in-app notifications only.
  static const _firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _firebaseSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  FirebaseOptions? get firebaseOptions {
    if ([_firebaseApiKey, _firebaseAppId, _firebaseSenderId, _firebaseProjectId].any((v) => v.isEmpty)) return null;
    return const FirebaseOptions(
      apiKey: _firebaseApiKey,
      appId: _firebaseAppId,
      messagingSenderId: _firebaseSenderId,
      projectId: _firebaseProjectId,
    );
  }
}

/// Overridden in `bootstrap()`; reading it without an override is a bug.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider must be overridden'),
);
