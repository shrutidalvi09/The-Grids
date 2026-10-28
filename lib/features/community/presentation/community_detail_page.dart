import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';
import 'community_providers.dart';
import 'widgets/community_widgets.dart';

enum _ClubAction { edit, delete }

/// One club: what it's about, who's in it, and its announcements.
class CommunityDetailPage extends ConsumerWidget {
  const CommunityDetailPage({super.key, required this.communityId});

  final String communityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isAdmin = ref.watch(currentSessionProvider)?.role == UserRole.admin;
    final detail = ref.watch(communityProvider(communityId));
    final name = detail.value?.community.name;

    Future<void> deleteClub(Community club) async {
      final messenger = ScaffoldMessenger.of(context);
      final router = GoRouter.of(context);
      final ok = await confirmAction(
        context,
        title: l10n.deleteCommunity,
        message: l10n.deleteCommunityConfirm(club.name),
        confirmLabel: l10n.delete,
        destructive: true,
      );
      if (!ok) return;
      try {
        await ref.read(communityRepositoryProvider).deleteCommunity(club.id);
        ref.invalidate(communitiesProvider);
        messenger.showSnackBar(SnackBar(content: Text(l10n.communityDeleted)));
        router.go(AppRoutes.community);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
      }
    }

    return GridsPage(
      title: name ?? l10n.navCommunity,
      showMenu: false,
      actions: [
        if (isAdmin && detail.hasValue)
          PopupMenuButton<_ClubAction>(
            tooltip: l10n.communityActions,
            onSelected: (action) => switch (action) {
              _ClubAction.edit => context.go(AppRoutes.editCommunity(communityId)),
              _ClubAction.delete => deleteClub(detail.requireValue.community),
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: _ClubAction.edit, child: Text(l10n.editCommunity)),
              PopupMenuItem(value: _ClubAction.delete, child: Text(l10n.deleteCommunity)),
            ],
          ),
      ],
      floatingActionButton: isAdmin && detail.hasValue
          ? FloatingActionButton.extended(
              onPressed: () => context.go(AppRoutes.announcementForm(communityId)),
              icon: const Icon(Icons.campaign_rounded),
              label: Text(l10n.addAnnouncement),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(communityProvider(communityId).future),
        child: AsyncValueView(
          value: detail,
          onRetry: () => ref.invalidate(communityProvider(communityId)),
          data: (d) => _DetailView(detail: d, isAdmin: isAdmin),
        ),
      ),
    );
  }
}

class _DetailView extends ConsumerStatefulWidget {
  const _DetailView({required this.detail, required this.isAdmin});

  final CommunityDetail detail;
  final bool isAdmin;

  @override
  ConsumerState<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends ConsumerState<_DetailView> {
  bool _busy = false;

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _toggleMembership() async {
    final l10n = context.l10n;
    final club = widget.detail.community;
    if (club.isMember) {
      final ok = await confirmAction(context, title: l10n.leaveConfirm(club.name), confirmLabel: l10n.leave);
      if (!ok) return;
    }
    setState(() => _busy = true);
    final repo = ref.read(communityRepositoryProvider);
    try {
      club.isMember ? await repo.leave(club.id) : await repo.join(club.id);
      ref
        ..invalidate(communityProvider(club.id))
        ..invalidate(communitiesProvider);
      if (mounted) _snack(club.isMember ? l10n.leftClub(club.name) : l10n.joinedClub(club.name));
    } catch (e) {
      if (mounted) _snack(describeError(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAnnouncement(Announcement a) async {
    final l10n = context.l10n;
    final ok = await confirmAction(
      context,
      title: l10n.deleteAnnouncementConfirm,
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(communityRepositoryProvider).deleteAnnouncement(a.id);
      ref
        ..invalidate(communityProvider(a.communityId))
        ..invalidate(communitiesProvider);
      if (mounted) _snack(l10n.announcementDeleted);
    } catch (e) {
      if (mounted) _snack(describeError(l10n, e));
    }
  }

  void _showMembers() {
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true, // above the bottom nav bar
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) => ListView(
          controller: controller,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: Text(l10n.membersTitle, style: Theme.of(sheet).textTheme.titleLarge),
            ),
            for (final m in widget.detail.members)
              ListTile(
                leading: PersonAvatar(name: m.name),
                title: Text(m.name),
                subtitle: m.flatLabel == null ? null : Text(m.flatLabel!),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final grids = GridsColors.of(context);
    final club = widget.detail.community;
    final announcements = widget.detail.announcements;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 96),
      children: [
        Row(
          children: [
            CommunityPhoto(community: club, size: 80),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(club.name, style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary)),
                  InkWell(
                    onTap: widget.detail.members.isEmpty ? null : _showMembers,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_alt_rounded, size: 18, color: grids.slate),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            l10n.membersCount(club.memberCount),
                            style: TextStyle(color: grids.slate, decoration: TextDecoration.underline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (club.description != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(club.description!, style: theme.textTheme.bodyLarge),
        ],
        const SizedBox(height: AppSpacing.lg),
        club.isMember
            ? OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(AppSpacing.minTapTarget)),
                onPressed: _busy ? null : _toggleMembership,
                icon: const Icon(Icons.logout_rounded),
                label: Text(l10n.leave),
              )
            : PrimaryButton(
                label: l10n.join,
                icon: Icons.group_add_rounded,
                isLoading: _busy,
                onPressed: _busy ? null : _toggleMembership,
              ),
        SectionHeader(title: l10n.announcementsTitle, icon: Icons.campaign_rounded),
        if (announcements.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(l10n.noAnnouncements, style: TextStyle(color: grids.slate)),
            ),
          ),
        for (final a in announcements)
          _AnnouncementCard(
            announcement: a,
            onEdit: widget.isAdmin ? () => context.go(AppRoutes.announcementForm(a.communityId), extra: a) : null,
            onDelete: widget.isAdmin ? () => _deleteAnnouncement(a) : null,
          ),
      ],
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.announcement, this.onEdit, this.onDelete});

  final Announcement announcement;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final slate = GridsColors.of(context).slate;
    final a = announcement;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            Text(a.body, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.sm),
            AnnouncementEventInfo(announcement: a),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.postedByOn(a.authorName, formatDate(context, a.createdAt)),
                    style: theme.textTheme.bodySmall?.copyWith(color: slate),
                  ),
                ),
                if (onDelete != null)
                  IconButton(tooltip: l10n.delete, onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded)),
                if (onEdit != null)
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, AppSpacing.minTapTarget)),
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded, size: 18), label: Text(l10n.edit)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
