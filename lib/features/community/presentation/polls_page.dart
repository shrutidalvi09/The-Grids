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
import 'community_providers.dart';
import 'widgets/poll_card.dart';

class PollsPage extends ConsumerWidget {
  const PollsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isAdmin = ref.watch(currentSessionProvider)?.role == UserRole.admin;
    return GridsPage(
      title: l10n.pollsTitle,
      showMenu: false,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.go(AppRoutes.pollForm),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.newPoll),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(pollsProvider.future),
        child: AsyncValueView(
          value: ref.watch(pollsProvider),
          onRetry: () => ref.invalidate(pollsProvider),
          isEmpty: (list) => list.isEmpty,
          empty: EmptyState(icon: Icons.poll_rounded, title: l10n.noPolls),
          data: (list) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 96),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) => PollCard(key: ValueKey(list[i].id), poll: list[i]),
          ),
        ),
      ),
    );
  }
}
