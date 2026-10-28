import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/formatters.dart';

/// Pill-shaped summary of an amount, e.g. "Maintenance Due · ₹2,500 due on 20 Apr".
class AmountCard extends StatelessWidget {
  const AmountCard({
    super.key,
    required this.title,
    required this.amount,
    this.caption,
    this.onTap,
  });

  final String title;
  final num amount;

  /// Shown under the amount, e.g. a due date.
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grids = GridsColors.of(context);
    final formatted = formatInr(amount);
    return Semantics(
      button: onTap != null,
      label: [title, formatted, ?caption].join(', '),
      excludeSemantics: true,
      child: Material(
        color: grids.card,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: grids.success.withValues(alpha: 0.18),
                  child: Icon(Icons.currency_rupee_rounded, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      Text(
                        formatted,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      if (caption != null)
                        Text(caption!, style: theme.textTheme.bodyMedium?.copyWith(color: grids.slate)),
                    ],
                  ),
                ),
                if (onTap != null) const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
