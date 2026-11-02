import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/session_controller.dart';
import '../../home/presentation/home_providers.dart';
import '../data/tower_repository.dart';
import '../domain/tower_models.dart';
import 'tower_providers.dart';
import 'widgets/tower_tiles.dart';

enum _EventAction { edit, delete }

class EventsPage extends ConsumerWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isAdmin = ref.watch(currentSessionProvider)?.role == UserRole.admin;

    Future<void> delete(SocietyEvent e) async {
      final messenger = ScaffoldMessenger.of(context);
      final ok = await confirmAction(context, title: l10n.deleteEventConfirm(e.title), confirmLabel: l10n.delete, destructive: true);
      if (!ok) return;
      try {
        await ref.read(towerRepositoryProvider).deleteEvent(e.id);
        ref
          ..invalidate(eventsProvider)
          ..invalidate(homeProvider);
        messenger.showSnackBar(SnackBar(content: Text(l10n.eventDeleted)));
      } catch (err) {
        messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, err))));
      }
    }

    return GridsPage(
      title: l10n.drawerEvents,
      showMenu: false,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.eventForm),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.addEvent),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(eventsProvider.future),
        child: AsyncValueView(
          value: ref.watch(eventsProvider),
          onRetry: () => ref.invalidate(eventsProvider),
          isEmpty: (e) => e.isEmpty,
          empty: EmptyState(icon: Icons.event_rounded, title: l10n.noUpcomingEvents),
          data: (events) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (_, i) {
              final event = events[i];
              if (!isAdmin) return EventCard(event: event);
              return Stack(
                children: [
                  EventCard(event: event),
                  Positioned(
                    top: AppSpacing.xs,
                    right: AppSpacing.xs,
                    child: PopupMenuButton<_EventAction>(
                      tooltip: l10n.eventActions,
                      iconColor: Colors.white,
                      onSelected: (a) => a == _EventAction.edit ? context.push(AppRoutes.eventForm, extra: event) : delete(event),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: _EventAction.edit, child: Text(l10n.edit)),
                        PopupMenuItem(value: _EventAction.delete, child: Text(l10n.delete)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
