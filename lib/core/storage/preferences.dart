import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loaded once in `bootstrap()` so settings can be read synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

abstract final class PrefKeys {
  static const themeMode = 'settings.themeMode';
  static const languageCode = 'settings.languageCode';
}
