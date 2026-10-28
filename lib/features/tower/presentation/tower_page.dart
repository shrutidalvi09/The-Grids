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
import '../../facilities/presentation/facility_providers.dart';
import '../../facilities/presentation/widgets/facility_tile.dart';
import 'notices_page.dart';
import 'tower_providers.dart';
import 'widgets/tower_tiles.dart';

const _preview = 3;
const _complaintsPreview = (status: null, limit: _preview);

class TowerPage extends ConsumerWidget {
  const TowerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isAdmin = ref.watch(currentSessionProvider)?.role == UserRole.admin;

    final visitors = ref.watch(visitorsProvider(_preview));
    final notices = ref.watch(noticesProvider(_preview));
    final facilities = ref.watch(facilitiesProvider);
    final complaints = ref.watch(complaintsProvider(_complaintsPreview));
    final neighbours = isAdmin ? null : ref.watch(neighboursProvider);

    Future<void> refresh() async {
      ref
        ..invalidate(visitorsProvider)
        ..invalidate(noticesProvider)
        ..invalidate(facilitiesProvider)
        ..invalidate(complaintsProvider)
        ..invalidate(neighboursProvider);
      await ref.read(facilitiesProvider.future);
    }

    return GridsPage(
      title: l10n.navTower,
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
          children: [
            AsyncSection(
              title: l10n.visitorsTitle,
              icon: Icons.badge_rounded,
              value: visitors,
              isEmpty: (v) => v.isEmpty,
              emptyText: l10n.noVisitors,
              onViewAll: () => context.go(AppRoutes.towerVisitors),
              onRetry: () => ref.invalidate(visitorsProvider),
              builder: (list) => Column(
                children: [for (final v in list) VisitorTile(visitor: v, showFlat: isAdmin)],
              ),
            ),
            AsyncSection(
              title: l10n.noticesTitle,
              icon: Icons.campaign_rounded,
              value: notices,
              isEmpty: (n) => n.isEmpty,
              emptyText: l10n.noNotices,
              onViewAll: () => context.go(AppRoutes.towerNotices),
              onRetry: () => ref.invalidate(noticesProvider),
              action: isAdmin
                  ? TextButton.icon(
                      onPressed: () => context.go(AppRoutes.noticeForm),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l10n.addNotice),
                    )
                  : null,
              builder: (list) => Column(
                children: [
                  for (final n in list) NoticeTile(notice: n, onTap: () => showNoticeDetails(context, ref, n)),
                ],
              ),
            ),
            if (neighbours != null)
              AsyncSection(
                title: l10n.neighboursTitle,
                icon: Icons.diversity_3_rounded,
                value: neighbours,
                isEmpty: (t) => t.isEmpty,
                emptyText: l10n.noNeighbours,
                onViewAll: () => context.go(AppRoutes.towerNeighbours),
                onRetry: () => ref.invalidate(neighboursProvider),
                builder: (towers) => Column(
                  children: [
                    for (final (tower, flat) in [
                      for (final t in towers)
                        for (final f in t.flats) (t.towerName, f),
                    ].take(_preview))
                      NeighbourTile(towerName: tower, flat: flat),
                  ],
                ),
              ),
            AsyncSection(
              title: l10n.facilitiesTitle,
              icon: Icons.sports_tennis_rounded,
              value: facilities,
              isEmpty: (f) => f.isEmpty,
              emptyText: l10n.noFacilities,
              onViewAll: () => context.go(AppRoutes.towerFacilities),
              onRetry: () => ref.invalidate(facilitiesProvider),
              action: isAdmin
                  ? TextButton.icon(
                      onPressed: () => context.go(AppRoutes.facilityForm),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l10n.addFacility),
                    )
                  : null,
              builder: (list) => Column(
                children: [for (final f in list.take(4)) FacilityTile(facility: f, isAdmin: isAdmin)],
              ),
            ),
            AsyncSection(
              title: isAdmin ? l10n.complaintsTitle : l10n.myComplaintsTitle,
              icon: Icons.assignment_late_rounded,
              value: complaints,
              isEmpty: (c) => c.isEmpty,
              emptyText: l10n.noComplaints,
              onViewAll: () => context.go(AppRoutes.towerComplaints),
              onRetry: () => ref.invalidate(complaintsProvider),
              action: isAdmin
                  ? null
                  : TextButton.icon(
                      onPressed: () => context.go(AppRoutes.postComplaint),
                      icon: const Icon(Icons.add_comment_rounded),
                      label: Text(l10n.postComplaint),
                    ),
              builder: (list) => Column(
                children: [
                  for (final c in list)
                    ComplaintTile(
                      complaint: c,
                      showFlat: isAdmin,
                      onTap: () => context.go(AppRoutes.towerComplaints),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
