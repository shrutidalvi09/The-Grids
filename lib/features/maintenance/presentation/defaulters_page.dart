import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../data/money_repository.dart';
import '../domain/money_models.dart';
import 'money_providers.dart';

/// Admin: flats with unpaid maintenance, oldest first, with a reminder button.
class DefaultersPage extends ConsumerWidget {
  const DefaultersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return GridsPage(
      title: l10n.defaultersTitle,
      showMenu: false,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(defaultersProvider.future),
        child: AsyncValueView(
          value: ref.watch(defaultersProvider),
          onRetry: () => ref.invalidate(defaultersProvider),
          isEmpty: (list) => list.isEmpty,
          empty: EmptyState(icon: Icons.verified_rounded, title: l10n.noDefaulters),
          data: (list) => ListView.builder(
            padding: AppSpacing.pagePadding,
            itemCount: list.length,
            itemBuilder: (context, i) => _DefaulterCard(defaulter: list[i]),
          ),
        ),
      ),
    );
  }
}

class _DefaulterCard extends ConsumerStatefulWidget {
  const _DefaulterCard({required this.defaulter});

  final Defaulter defaulter;

  @override
  ConsumerState<_DefaulterCard> createState() => _DefaulterCardState();
}

class _DefaulterCardState extends ConsumerState<_DefaulterCard> {
  bool _sending = false;

  Future<void> _remind() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await ref.read(moneyRepositoryProvider).remind(widget.defaulter.flatId);
      messenger.showSnackBar(SnackBar(content: Text(l10n.reminderSent(widget.defaulter.flatLabel))));
      ref.invalidate(defaultersProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final grids = GridsColors.of(context);
    final d = widget.defaulter;
    final reminded = d.remindedRecently(DateTime.now());
    final overdueDays = DateTime.now().difference(d.oldestDueDate).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.flatLabel, style: theme.textTheme.titleMedium),
                  if (d.owners.isNotEmpty) Text(d.owners.join(', '), style: TextStyle(color: grids.slate)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    formatPaise(d.amountPaise),
                    style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.secondary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      StatusChip(label: l10n.duesCount(d.dues), tone: StatusTone.neutral),
                      if (overdueDays > 0) StatusChip(label: l10n.overdueDays(overdueDays), tone: StatusTone.danger),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            reminded
                ? Chip(avatar: const Icon(Icons.check_rounded, size: 18), label: Text(l10n.remindedToday))
                : OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, AppSpacing.minTapTarget)),
                    onPressed: _sending ? null : _remind,
                    icon: _sending
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.notifications_active_rounded),
                    label: Text(l10n.remind),
                  ),
          ],
        ),
      ),
    );
  }
}
