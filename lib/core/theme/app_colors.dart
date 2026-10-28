import 'package:flutter/material.dart';

/// Brand palette taken from the design mockups.
abstract final class AppColors {
  // Brand
  static const green = Color(0xFF2E7D32);
  static const greenLight = Color(0xFF66BB6A);
  static const greenDark = Color(0xFF1B5E20);
  static const orange = Color(0xFFF57C00);
  static const orangeLight = Color(0xFFFFB74D);

  // Neutrals
  static const slate = Color(0xFF455A64);
  static const ink = Color(0xFF1B1F23);
  static const white = Color(0xFFFFFFFF);
  static const cardLight = Color(0xFFEEF1F2);
  static const dividerLight = Color(0xFFD5DBDE);

  static const surfaceDark = Color(0xFF121416);
  static const cardDark = Color(0xFF1F2427);
  static const dividerDark = Color(0xFF3A4246);

  // Status
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFF57C00);
  static const danger = Color(0xFFD32F2F);
  static const info = Color(0xFF1E88E5);

  // Logo
  static const logoWindow = Color(0xFFFF7043);
  static const logoHeart = Color(0xFFC62828);
}

/// Colours that Material's [ColorScheme] has no slot for.
@immutable
class GridsColors extends ThemeExtension<GridsColors> {
  const GridsColors({
    required this.card,
    required this.slate,
    required this.navBar,
    required this.navActive,
    required this.navInactive,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.logoWalls,
  });

  final Color card;
  final Color slate;
  final Color navBar;
  final Color navActive;
  final Color navInactive;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color logoWalls;

  static const light = GridsColors(
    card: AppColors.cardLight,
    slate: AppColors.slate,
    navBar: AppColors.green,
    navActive: AppColors.orange,
    navInactive: AppColors.white,
    success: AppColors.success,
    warning: AppColors.warning,
    danger: AppColors.danger,
    info: AppColors.info,
    logoWalls: AppColors.slate,
  );

  static const dark = GridsColors(
    card: AppColors.cardDark,
    slate: Color(0xFF90A4AE),
    navBar: AppColors.greenDark,
    navActive: AppColors.orangeLight,
    navInactive: Color(0xFFE0E0E0),
    success: AppColors.greenLight,
    warning: AppColors.orangeLight,
    danger: Color(0xFFEF5350),
    info: Color(0xFF64B5F6),
    logoWalls: Color(0xFFB0BEC5),
  );

  static GridsColors of(BuildContext context) =>
      Theme.of(context).extension<GridsColors>()!;

  @override
  GridsColors copyWith({
    Color? card,
    Color? slate,
    Color? navBar,
    Color? navActive,
    Color? navInactive,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? logoWalls,
  }) {
    return GridsColors(
      card: card ?? this.card,
      slate: slate ?? this.slate,
      navBar: navBar ?? this.navBar,
      navActive: navActive ?? this.navActive,
      navInactive: navInactive ?? this.navInactive,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      logoWalls: logoWalls ?? this.logoWalls,
    );
  }

  @override
  GridsColors lerp(GridsColors? other, double t) {
    if (other == null) return this;
    return GridsColors(
      card: Color.lerp(card, other.card, t)!,
      slate: Color.lerp(slate, other.slate, t)!,
      navBar: Color.lerp(navBar, other.navBar, t)!,
      navActive: Color.lerp(navActive, other.navActive, t)!,
      navInactive: Color.lerp(navInactive, other.navInactive, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      logoWalls: Color.lerp(logoWalls, other.logoWalls, t)!,
    );
  }
}
