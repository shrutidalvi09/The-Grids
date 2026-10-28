import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import 'tower_providers.dart';
import 'widgets/tower_tiles.dart';

class EventsPage extends ConsumerWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return GridsPage(
      title: l10n.drawerEvents,
      showMenu: false,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(eventsProvider.future),
        child: AsyncValueView(
          value: ref.watch(eventsProvider),
          onRetry: () => ref.invalidate(eventsProvider),
          isEmpty: (e) => e.isEmpty,
          empty: EmptyState(icon: Icons.event_rounded, title: l10n.noUpcomingEvents),
          data: (events) => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (_, i) => EventCard(event: events[i]),
          ),
        ),
      ),
    );
  }
}
