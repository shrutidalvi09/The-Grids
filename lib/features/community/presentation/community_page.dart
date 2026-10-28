import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/session_controller.dart';
import 'community_providers.dart';
import 'widgets/community_widgets.dart';
import 'widgets/poll_card.dart';

/// Polls on top, then the society's clubs with their latest announcement.
class CommunityPage extends ConsumerWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isAdmin = ref.watch(currentSessionProvider)?.role == UserRole.admin;
    final polls = ref.watch(pollsProvider);
    final communities = ref.watch(communitiesProvider);

    Future<void> refresh() async {
      ref
        ..invalidate(pollsProvider)
        ..invalidate(communitiesProvider);
      await ref.read(communitiesProvider.future);
    }

    return GridsPage(
      title: l10n.navCommunity,
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
          children: [
            SectionHeader(
              title: l10n.pollsTitle,
              icon: Icons.poll_rounded,
              actionLabel: l10n.viewAll,
              onAction: () => context.go(AppRoutes.communityPolls),
            ),
            ..._section(
              context,
              value: polls,
              onRetry: () => ref.invalidate(pollsProvider),
              // The newest open poll, or the latest result if none is open.
              builder: (list) => list.isEmpty
                  ? [_EmptyCard(text: l10n.noPolls)]
                  : [PollCard(key: ValueKey(list.first.id), poll: list.first)],
            ),
            if (isAdmin)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => context.go(AppRoutes.pollForm),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.newPoll),
                ),
              ),
            if (isAdmin) ...[
              const SizedBox(height: AppSpacing.sm),
              _NewCommunityTile(onTap: () => context.go(AppRoutes.communityForm)),
            ],
            SectionHeader(title: l10n.communitiesTitle, icon: Icons.groups_rounded),
            ..._section(
              context,
              value: communities,
              onRetry: () => ref.invalidate(communitiesProvider),
              builder: (list) => list.isEmpty
                  ? [_EmptyCard(text: l10n.noCommunities)]
                  : [
                      for (final c in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: CommunityCard(community: c, onTap: () => context.go(AppRoutes.communityClub(c.id))),
                        ),
                    ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _section<T>(
    BuildContext context, {
    required AsyncValue<T> value,
    required VoidCallback onRetry,
    required List<Widget> Function(T data) builder,
  }) =>
      value.when(
        skipLoadingOnRefresh: true,
        loading: () => const [
          Padding(padding: EdgeInsets.all(AppSpacing.xl), child: Center(child: CircularProgressIndicator())),
        ],
        error: (e, _) => [
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_off_rounded),
              title: Text(describeError(context.l10n, e)),
              trailing: TextButton(onPressed: onRetry, child: Text(context.l10n.retry)),
            ),
          ),
        ],
        data: builder,
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(text, style: TextStyle(color: GridsColors.of(context).slate)),
        ),
      );
}

/// The orange "New Community" row from the admin mockup.
class _NewCommunityTile extends StatelessWidget {
  const _NewCommunityTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.secondary;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          child: Row(
            children: [
              Icon(Icons.group_add_rounded, size: 36, color: secondary),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  context.l10n.newCommunity,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: secondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
