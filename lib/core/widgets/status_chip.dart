import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum StatusTone { success, warning, danger, info, neutral }

/// Small coloured pill: "Open", "Resolved", "Checked in", "Full"…
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.tone});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final grids = GridsColors.of(context);
    final color = switch (tone) {
      StatusTone.success => grids.success,
      StatusTone.warning => grids.warning,
      StatusTone.danger => grids.danger,
      StatusTone.info => grids.info,
      StatusTone.neutral => grids.slate,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: const BorderRadius.all(AppRadii.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
