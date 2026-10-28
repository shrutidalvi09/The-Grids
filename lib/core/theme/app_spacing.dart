import 'package:flutter/widgets.dart';

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Horizontal page gutter used by every screen.
  static const pagePadding = EdgeInsets.symmetric(horizontal: lg, vertical: lg);

  /// Material minimum tap target.
  static const minTapTarget = 48.0;
}

abstract final class AppRadii {
  static const sm = Radius.circular(8);
  static const md = Radius.circular(12);
  static const lg = Radius.circular(20);
  static const pill = Radius.circular(999);

  static const card = BorderRadius.all(md);
  static const sheet = BorderRadius.vertical(top: lg);
}
