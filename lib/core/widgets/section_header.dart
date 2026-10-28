import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Green section title with optional icon and trailing action ("View all").
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 24),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(color: color),
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
