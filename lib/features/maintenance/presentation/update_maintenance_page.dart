import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

/// Admin: the monthly maintenance line items and due day.
class UpdateMaintenancePage extends ConsumerWidget {
  const UpdateMaintenancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridsPage(
      title: context.l10n.updateMaintenance,
      showMenu: false,
      showNotifications: false,
      body: AsyncValueView(
        value: ref.watch(maintenanceConfigProvider),
        onRetry: () => ref.invalidate(maintenanceConfigProvider),
        data: (config) => _ConfigForm(config: config),
      ),
    );
  }
}

class _ItemControllers {
  _ItemControllers(BreakdownItem? item)
      : label = TextEditingController(text: item?.label),
        amount = TextEditingController(text: item == null ? '' : _rupees(item.amountPaise));

  final TextEditingController label;
  final TextEditingController amount;

  static String _rupees(int paise) =>
      paise % 100 == 0 ? '${paise ~/ 100}' : (paise / 100).toStringAsFixed(2);

  int get paise {
    final parsed = double.tryParse(amount.text.replaceAll(',', '').trim());
    return parsed == null ? 0 : (parsed * 100).round();
  }

  void dispose() {
    label.dispose();
    amount.dispose();
  }
}

class _ConfigForm extends ConsumerStatefulWidget {
  const _ConfigForm({required this.config});

  final MaintenanceConfig config;

  static const maxItems = 15;

  @override
  ConsumerState<_ConfigForm> createState() => _ConfigFormState();
}

class _ConfigFormState extends ConsumerState<_ConfigForm> {
  final _form = GlobalKey<FormState>();
  late final _items = [
    for (final item in widget.config.items) _ItemControllers(item),
    if (widget.config.items.isEmpty) _ItemControllers(null),
  ];
  late int _dueDay = widget.config.dueDay.clamp(1, 28);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  int get _total => _items.fold(0, (sum, i) => sum + i.paise);

  void _add() => setState(() => _items.add(_ItemControllers(null)));

  void _remove(int index) => setState(() => _items.removeAt(index).dispose());

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(moneyRepositoryProvider).updateConfig(
        [for (final i in _items) BreakdownItem(label: i.label.text.trim(), amountPaise: i.paise)],
        _dueDay,
      );
      ref
        ..invalidate(maintenanceConfigProvider)
        ..invalidate(maintenanceSummaryProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.maintenanceSaved)));
      context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = describeError(l10n, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final grids = GridsColors.of(context);
    final validators = Validators(l10n);

    return Form(
      key: _form,
      onChanged: () => setState(() {}), // live total
      child: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          Text(l10n.maintenanceItemsHint, style: TextStyle(color: grids.slate)),
          const SizedBox(height: AppSpacing.lg),
          for (final (index, item) in _items.indexed)
            Padding(
              key: ObjectKey(item),
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: item.label,
                      decoration: InputDecoration(labelText: l10n.itemLabel),
                      textCapitalization: TextCapitalization.words,
                      maxLength: 40,
                      validator: validators.required,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: item.amount,
                      decoration: InputDecoration(labelText: l10n.itemAmount, prefixText: '₹ '),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                      // ₹1 – ₹1,00,000 per line, as the server allows.
                      validator: (v) =>
                          validators.amount(v) ?? (item.paise < 100 || item.paise > 10000000 ? l10n.validationAmount : null),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.removeItem,
                    onPressed: _items.length > 1 ? () => _remove(index) : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                ],
              ),
            ),
          if (_items.length < _ConfigForm.maxItems)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(onPressed: _add, icon: const Icon(Icons.add_rounded), label: Text(l10n.addItem)),
            ),
          const Divider(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(child: Text(l10n.totalLabel, style: theme.textTheme.titleMedium)),
              Text(formatPaise(_total), style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.secondary)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<int>(
            initialValue: _dueDay,
            decoration: InputDecoration(labelText: l10n.dueDayLabel),
            items: [
              for (var d = 1; d <= 28; d++) DropdownMenuItem(value: d, child: Text(l10n.dueDayOfMonth(d))),
            ],
            onChanged: (value) => setState(() => _dueDay = value!),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.maintenanceAppliesNextMonth, style: TextStyle(color: grids.slate)),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(label: l10n.save, isLoading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
