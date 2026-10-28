import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferences.dart';
import 'app_language.dart';

/// The chosen app language. `null` means "follow the device language".
class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() {
    final code = ref.read(sharedPreferencesProvider).getString(PrefKeys.languageCode);
    return AppLanguage.fromCode(code)?.locale;
  }

  Future<void> set(AppLanguage? language) async {
    state = language?.locale;
    final prefs = ref.read(sharedPreferencesProvider);
    if (language == null) {
      await prefs.remove(PrefKeys.languageCode);
    } else {
      await prefs.setString(PrefKeys.languageCode, language.code);
    }
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale?>(LocaleController.new);
