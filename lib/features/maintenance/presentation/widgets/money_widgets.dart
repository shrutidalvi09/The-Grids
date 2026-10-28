import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/money_models.dart';

/// "October 2026" in the user's language.
String formatPeriod(BuildContext context, DateTime month) =>
    DateFormat.yMMMM(Localizations.localeOf(context).toLanguageTag()).format(month);

String methodLabel(AppLocalizations l10n, String? method) => switch (method) {
      'upi' => l10n.methodUpi,
      'card' => l10n.methodCard,
      'netbanking' => l10n.methodNetbanking,
      'wallet' => l10n.methodWallet,
      null => '—',
      _ => method,
    };

/// Line items and total, like the mockup's "View Breakdown" card.
class BreakdownCard extends StatelessWidget {
  const BreakdownCard({super.key, required this.items, this.title});

  final List<BreakdownItem> items;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final total = items.fold<int>(0, (sum, i) => sum + i.amountPaise);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title ?? l10n.viewBreakdown, icon: Icons.receipt_rounded),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
                    child: Row(
                      children: [
                        Expanded(child: Text(item.label, style: theme.textTheme.bodyLarge)),
                        Text(formatPaise(item.amountPaise), style: theme.textTheme.bodyLarge),
                      ],
                    ),
                  ),
                const Divider(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(child: Text(l10n.totalLabel, style: theme.textTheme.titleMedium)),
                    Text(formatPaise(total), style: theme.textTheme.titleMedium),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One unpaid month with its Pay button.
class DueCard extends StatelessWidget {
  const DueCard({super.key, required this.due, required this.onPay});

  final Due due;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final grids = GridsColors.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: grids.success.withValues(alpha: 0.15),
              child: Icon(Icons.currency_rupee_rounded, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formatPeriod(context, due.periodMonth), style: theme.textTheme.titleMedium),
                  Text(
                    formatPaise(due.amountPaise),
                    style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.secondary),
                  ),
                  const SizedBox(height: 2),
                  if (due.overdue)
                    StatusChip(label: l10n.overdueSince(formatDayMonth(context, due.dueDate)), tone: StatusTone.danger)
                  else
                    Text(l10n.dueOn(formatDayMonth(context, due.dueDate)), style: TextStyle(color: grids.slate)),
                ],
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
              onPressed: onPay,
              child: Text(l10n.payNow),
            ),
          ],
        ),
      ),
    );
  }
}

/// A paid month in the history; tapping opens the receipt.
class PaymentRow extends StatelessWidget {
  const PaymentRow({super.key, required this.payment, required this.onTap});

  final Payment payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final grids = GridsColors.of(context);
    return ListTile(
      onTap: onTap,
      leading: Icon(Icons.receipt_long_rounded, color: grids.success),
      title: Text(formatPaise(payment.amountPaise), style: theme.textTheme.titleMedium),
      subtitle: Text(
        [
          formatPeriod(context, payment.periodMonth),
          if (payment.paidAt != null) l10n.paidOn(formatDayMonth(context, payment.paidAt!)),
        ].join(' · '),
      ),
      trailing: Icon(Icons.download_rounded, semanticLabel: l10n.receiptTitle),
    );
  }
}
