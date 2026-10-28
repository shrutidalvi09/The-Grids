import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/notifications_repository.dart';
import 'notification_routes.dart';
import 'unread_count_provider.dart';

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) {
  ref.watch(sessionKeyProvider);
  return ref.watch(notificationsRepositoryProvider).list(limit: 50);
});

IconData notificationIcon(String type) => switch (type) {
      'due' || 'due_reminder' => Icons.currency_rupee_rounded,
      'payment' => Icons.receipt_long_rounded,
      'notice' => Icons.campaign_rounded,
      'alert' => Icons.warning_amber_rounded,
      'poll' => Icons.poll_rounded,
      'announcement' => Icons.groups_rounded,
      'complaint' => Icons.assignment_turned_in_rounded,
      'visitor' => Icons.badge_rounded,
      'parcel' => Icons.inventory_2_rounded,
      'tenancy' => Icons.key_rounded,
      _ => Icons.notifications_rounded,
    };

/// Dues, notices, polls and visitor alerts, newest first, with read/unread state.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final list = ref.watch(notificationsProvider);
    final hasUnread = list.value?.any((n) => !n.read) ?? false;

    Future<void> markAll() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref.read(notificationsRepositoryProvider).markAllRead();
        ref.read(unreadNotificationCountProvider.notifier).set(0);
        ref.invalidate(notificationsProvider);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
      }
    }

    return GridsPage(
      title: l10n.notificationsTitle,
      showMenu: false,
      showNotifications: false,
      actions: [
        if (hasUnread)
          IconButton(tooltip: l10n.markAllRead, onPressed: markAll, icon: const Icon(Icons.done_all_rounded)),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          await ref.read(unreadNotificationCountProvider.notifier).refresh();
          await ref.read(notificationsProvider.future);
        },
        child: AsyncValueView(
          value: list,
          onRetry: () => ref.invalidate(notificationsProvider),
          isEmpty: (items) => items.isEmpty,
          empty: EmptyState(icon: Icons.notifications_none_rounded, title: l10n.emptyNotifications),
          data: (items) => ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, i) => _NotificationTile(notification: items[i]),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final grids = GridsColors.of(context);
    final n = notification;
    final now = DateTime.now();
    final when = isSameDay(n.createdAt, now) ? formatTime(context, n.createdAt) : formatDayMonth(context, n.createdAt);

    Future<void> open() async {
      final role = ref.read(currentSessionProvider)?.role;
      if (!n.read) {
        final count = ref.read(unreadNotificationCountProvider);
        ref.read(unreadNotificationCountProvider.notifier).set(count - 1);
        try {
          await ref.read(notificationsRepositoryProvider).markRead(n.id);
        } catch (_) {
          // Shown as read again on the next refresh if this failed.
        }
        ref.invalidate(notificationsProvider);
      }
      final route = role == null ? null : routeForNotification(n.type, n.data, role);
      if (route != null && context.mounted) context.push(route);
    }

    return Semantics(
      label: n.read ? null : l10n.unreadLabel,
      child: ListTile(
        onTap: open,
        tileColor: n.read ? null : theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        leading: CircleAvatar(
          backgroundColor: (n.type == 'alert' ? grids.danger : theme.colorScheme.primary).withValues(alpha: 0.15),
          child: Icon(notificationIcon(n.type), color: n.type == 'alert' ? grids.danger : theme.colorScheme.primary),
        ),
        title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w400 : FontWeight.w700)),
        subtitle: Text(n.body, maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(when, style: theme.textTheme.bodySmall?.copyWith(color: grids.slate)),
            if (!n.read) ...[
              const SizedBox(height: AppSpacing.xs),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: theme.colorScheme.secondary, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
