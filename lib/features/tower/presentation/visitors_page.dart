import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/session_controller.dart';
import 'tower_providers.dart';
import 'widgets/tower_tiles.dart';

class VisitorsPage extends ConsumerWidget {
  const VisitorsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isAdmin = ref.watch(currentSessionProvider)?.role == UserRole.admin;
    return GridsPage(
      title: l10n.visitorsTitle,
      showMenu: false,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(visitorsProvider(null).future),
        child: AsyncValueView(
          value: ref.watch(visitorsProvider(null)),
          onRetry: () => ref.invalidate(visitorsProvider(null)),
          isEmpty: (v) => v.isEmpty,
          empty: EmptyState(icon: Icons.badge_rounded, title: l10n.noVisitors),
          data: (visitors) => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: visitors.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => Card(child: VisitorTile(visitor: visitors[i], showFlat: isAdmin)),
          ),
        ),
      ),
    );
  }
}
