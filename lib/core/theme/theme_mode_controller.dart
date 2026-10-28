import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferences.dart';

/// Light / dark / system, persisted across launches.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = ref.read(sharedPreferencesProvider).getString(PrefKeys.themeMode);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(PrefKeys.themeMode, mode.name);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
