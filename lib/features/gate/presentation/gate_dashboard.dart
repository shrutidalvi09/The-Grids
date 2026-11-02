import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../home/domain/home_models.dart';
import '../../tower/presentation/visitors_page.dart';
import 'pass_check.dart';

/// The guard's Home: check a pass, what's waiting at the gate, and shortcuts.
class GateDashboard extends ConsumerWidget {
  const GateDashboard({super.key, required this.summary});

  final GateSummary? summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PassCodeCard(),
        const SizedBox(height: AppSpacing.lg),
        if (s != null) ...[
          SectionHeader(title: l10n.atTheGate, icon: Icons.shield_rounded),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.9,
            children: [
              StatCard(label: l10n.gateAwaitingApproval, value: '${s.awaitingApproval}', onTap: () => context.go(AppRoutes.tower)),
              StatCard(label: l10n.gateExpected, value: '${s.expected}', onTap: () => context.go(AppRoutes.tower)),
              StatCard(label: l10n.gateInside, value: '${s.inside}', onTap: () => context.go(AppRoutes.tower)),
              StatCard(label: l10n.gateParcels, value: '${s.parcels}', onTap: () => context.go(AppRoutes.tower)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        SectionHeader(title: l10n.quickActions, icon: Icons.bolt_rounded),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_rounded),
                title: Text(l10n.newVisitor),
                subtitle: Text(l10n.newVisitorHint),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showVisitorForm(context, ref, isGate: true),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cleaning_services_rounded),
                title: Text(l10n.dailyHelpTitle),
                subtitle: s == null ? null : Text(l10n.staffInsideCount(s.staffInside)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(AppRoutes.gateStaff),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.directions_car_rounded),
                title: Text(l10n.findVehicleTitle),
                subtitle: Text(l10n.findVehicleHint),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(AppRoutes.gateVehicles),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
