import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/session_controller.dart';
import 'facility_providers.dart';
import 'widgets/facility_tile.dart';

class FacilitiesPage extends ConsumerWidget {
  const FacilitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isAdmin = ref.watch(currentSessionProvider)?.role == UserRole.admin;
    return GridsPage(
      title: l10n.facilitiesTitle,
      showMenu: false,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.go(AppRoutes.facilityForm),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.addFacility),
            )
          : FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.facilityBookings),
              icon: const Icon(Icons.event_note_rounded),
              label: Text(l10n.drawerFacilityBookings),
            ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(facilitiesProvider.future),
        child: AsyncValueView(
          value: ref.watch(facilitiesProvider),
          onRetry: () => ref.invalidate(facilitiesProvider),
          isEmpty: (f) => f.isEmpty,
          empty: EmptyState(icon: Icons.sports_tennis_rounded, title: l10n.noFacilities),
          data: (facilities) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
            itemCount: facilities.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => Card(
              clipBehavior: Clip.antiAlias,
              child: FacilityTile(facility: facilities[i], isAdmin: isAdmin),
            ),
          ),
        ),
      ),
    );
  }
}
