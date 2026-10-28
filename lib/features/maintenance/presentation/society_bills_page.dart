import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../data/money_repository.dart';
import '../domain/money_models.dart';
import 'money_providers.dart';

/// Admin: the society's own bills (electricity, security agency, lift AMC…).
class SocietyBillsPage extends ConsumerStatefulWidget {
  const SocietyBillsPage({super.key});

  @override
  ConsumerState<SocietyBillsPage> createState() => _SocietyBillsPageState();
}

class _SocietyBillsPageState extends ConsumerState<SocietyBillsPage> {
  bool _paid = false;

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _markPaid(SocietyBill bill) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.markPaid),
        content: Text(l10n.markPaidConfirm(bill.vendor, formatPaise(bill.amountPaise))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.markPaid)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(moneyRepositoryProvider).markBillPaid(bill.id);
      ref.invalidate(societyBillsProvider);
      if (mounted) _snack(l10n.billMarkedPaid);
    } catch (e) {
      if (mounted) _snack(describeError(l10n, e));
    }
  }

  Future<void> _addBill() async {
    final l10n = context.l10n;
    final validators = Validators(l10n);
    final vendor = TextEditingController();
    final category = TextEditingController();
    final amount = TextEditingController();
    final now = DateTime.now();
    var dueDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 7));

    final added = await BottomSheetForm.show(
      context,
      title: l10n.addBill,
      submitLabel: l10n.addBill,
      fields: [
        TextFormField(
          controller: vendor,
          decoration: InputDecoration(labelText: l10n.vendorLabel),
          textCapitalization: TextCapitalization.words,
          maxLength: 80,
          validator: validators.required,
        ),
        TextFormField(
          controller: category,
          decoration: InputDecoration(labelText: l10n.fieldCategory),
          textCapitalization: TextCapitalization.words,
          maxLength: 40,
        ),
        TextFormField(
          controller: amount,
          decoration: InputDecoration(labelText: l10n.amountLabel, prefixText: '₹ '),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: validators.amount,
        ),
        const SizedBox(height: AppSpacing.md),
        _DateField(
          label: l10n.dueDateLabel,
          initial: dueDate,
          first: now.subtract(const Duration(days: 365)),
          last: now.add(const Duration(days: 365)),
          onChanged: (d) => dueDate = d,
        ),
      ],
      onSubmit: () => ref.read(moneyRepositoryProvider).addBill(
            vendor: vendor.text.trim(),
            category: category.text.trim().isEmpty ? null : category.text.trim(),
            amountPaise: (double.parse(amount.text.replaceAll(',', '').trim()) * 100).round(),
            dueDate: dueDate,
          ),
    );
    vendor.dispose();
    category.dispose();
    amount.dispose();
    if (added == true) {
      ref.invalidate(societyBillsProvider);
      if (mounted) {
        setState(() => _paid = false);
        _snack(l10n.billAdded);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final grids = GridsColors.of(context);
    final bills = ref.watch(societyBillsProvider(_paid));

    return GridsPage(
      title: l10n.societyBillsTitle,
      showMenu: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBill,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.addBill),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(l10n.billsDue)),
                  ButtonSegment(value: true, label: Text(l10n.billsPaid)),
                ],
                selected: {_paid},
                onSelectionChanged: (s) => setState(() => _paid = s.single),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(societyBillsProvider(_paid).future),
              child: AsyncValueView(
                value: bills,
                onRetry: () => ref.invalidate(societyBillsProvider(_paid)),
                isEmpty: (list) => list.isEmpty,
                empty: EmptyState(icon: Icons.account_balance_wallet_rounded, title: l10n.noBills),
                data: (list) => ListView.builder(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 96),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final bill = list[i];
                    // Due today is not overdue yet.
                    final overdue = !bill.paid && bill.dueDate.isBefore(DateUtils.dateOnly(DateTime.now()));
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
                        title: Text(bill.vendor, style: theme.textTheme.titleMedium),
                        subtitle: Text(
                          [
                            ?bill.category,
                            bill.paid && bill.paidAt != null
                                ? l10n.paidOn(formatDayMonth(context, bill.paidAt!))
                                : l10n.dueOn(formatDayMonth(context, bill.dueDate)),
                          ].join(' · '),
                          style: TextStyle(color: overdue ? grids.danger : null),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(formatPaise(bill.amountPaise), style: theme.textTheme.titleMedium),
                            if (!bill.paid)
                              IconButton(
                                tooltip: l10n.markPaid,
                                onPressed: () => _markPaid(bill),
                                icon: Icon(Icons.task_alt_rounded, color: theme.colorScheme.primary),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatefulWidget {
  const _DateField({
    required this.label,
    required this.initial,
    required this.first,
    required this.last,
    required this.onChanged,
  });

  final String label;
  final DateTime initial;
  final DateTime first;
  final DateTime last;
  final ValueChanged<DateTime> onChanged;

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  late DateTime _value = widget.initial;

  Future<void> _pick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _value,
      firstDate: widget.first,
      lastDate: widget.last,
    );
    if (picked == null) return;
    setState(() => _value = picked);
    widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _pick,
      borderRadius: AppRadii.card,
      child: InputDecorator(
        decoration: InputDecoration(labelText: widget.label, suffixIcon: const Icon(Icons.event_rounded)),
        child: Text(formatDate(context, _value)),
      ),
    );
  }
}
