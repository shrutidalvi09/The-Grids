import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Rounded grey row used for most list content (notices, bills, neighbours…).
class ListTileCard extends StatelessWidget {
  const ListTileCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        minTileHeight: AppSpacing.minTapTarget + AppSpacing.sm,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        leading: leading,
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: trailing,
      ),
    );
  }
}
