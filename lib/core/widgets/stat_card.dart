import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Orange tile with a label and a big number (admin statistics).
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      // Its own node, so screen readers announce each tile separately.
      container: true,
      button: onTap != null,
      label: '$label: $value',
      excludeSemantics: true,
      child: Material(
        color: scheme.secondary,
        borderRadius: const BorderRadius.all(AppRadii.lg),
        elevation: 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(AppRadii.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96, minWidth: 96),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      color: scheme.onSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    value,
                    style: textTheme.headlineSmall?.copyWith(color: scheme.onSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
