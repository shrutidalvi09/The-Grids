import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(
        brightness: Brightness.light,
        grids: GridsColors.light,
        scheme: ColorScheme.fromSeed(
          seedColor: AppColors.green,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.green,
          onPrimary: AppColors.white,
          secondary: AppColors.orange,
          onSecondary: AppColors.white,
          surface: AppColors.white,
          onSurface: AppColors.ink,
          surfaceContainerHighest: AppColors.cardLight,
          outlineVariant: AppColors.dividerLight,
          error: AppColors.danger,
        ),
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        grids: GridsColors.dark,
        scheme: ColorScheme.fromSeed(
          seedColor: AppColors.green,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.greenLight,
          onPrimary: AppColors.ink,
          secondary: AppColors.orangeLight,
          onSecondary: AppColors.ink,
          surface: AppColors.surfaceDark,
          onSurface: const Color(0xFFE8ECEE),
          surfaceContainerHighest: AppColors.cardDark,
          outlineVariant: AppColors.dividerDark,
          error: const Color(0xFFEF5350),
        ),
      );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required GridsColors grids,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );
    final text = base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      extensions: [grids],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        titleTextStyle: text.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontSize: 24,
        ),
      ),
      cardTheme: CardThemeData(
        color: grids.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.card),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.secondary,
          foregroundColor: scheme.onSecondary,
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
          textStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppSpacing.minTapTarget, AppSpacing.minTapTarget),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.secondary,
          minimumSize: const Size(AppSpacing.minTapTarget, AppSpacing.minTapTarget),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: grids.card,
        border: const OutlineInputBorder(
          borderRadius: AppRadii.card,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.card,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        // Selectable chips get a fill so they read as buttons; disabled ones
        // (e.g. booked slots) stay flat.
        color: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primaryContainer;
          if (states.contains(WidgetState.disabled)) return Colors.transparent;
          return grids.card;
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        minVerticalPadding: AppSpacing.md,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }
}
