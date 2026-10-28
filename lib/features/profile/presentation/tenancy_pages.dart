import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/phone_call.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../maintenance/domain/money_models.dart';
import '../../maintenance/presentation/widgets/money_widgets.dart';
import '../data/profile_repository.dart';
import '../domain/profile_models.dart';
import 'profile_providers.dart';

/// Owner: the flat's tenant and lease, or a prompt to add one.
class TenantInfoPage extends ConsumerWidget {
  const TenantInfoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    Future<void> end(Tenancy t) async {
      final messenger = ScaffoldMessenger.of(context);
      final ok = await confirmAction(
        context,
        title: l10n.endTenancyConfirmTitle(t.tenant.name),
        message: l10n.endTenancyConfirmBody,
        confirmLabel: l10n.endTenancy,
        destructive: true,
      );
      if (!ok) return;
      try {
        await ref.read(profileRepositoryProvider).endTenancy(t.id);
        ref.invalidate(tenancyProvider);
        messenger.showSnackBar(SnackBar(content: Text(l10n.tenancyEnded)));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
      }
    }

    return GridsPage(
      title: l10n.tenantInfoTitle,
      showMenu: false,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(tenancyProvider.future),
        child: AsyncValueView(
          value: ref.watch(tenancyProvider),
          onRetry: () => ref.invalidate(tenancyProvider),
          data: (tenancy) => tenancy == null
              ? EmptyState(
                  icon: Icons.key_rounded,
                  title: l10n.noTenant,
                  message: l10n.noTenantHint,
                  actionLabel: l10n.addTenant,
                  onAction: () => context.go(AppRoutes.tenantForm),
                )
              : ListView(
                  padding: AppSpacing.pagePadding,
                  children: [
                    _ContactCard(
                      title: l10n.tenantLabel,
                      contact: tenancy.tenant,
                      status: switch (tenancy.tenantStatus) {
                        TenantStatus.invited => (l10n.tenantInvited, StatusTone.warning),
                        TenantStatus.active => (l10n.tenantActive, StatusTone.success),
                        TenantStatus.removed => (l10n.tenantRemoved, StatusTone.neutral),
                      },
                    ),
                    _LeaseCard(tenancy: tenancy),
                    BreakdownCard(items: tenancy.rentBreakdown, title: l10n.rentBreakdownTitle),
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      label: l10n.editRentTerms,
                      icon: Icons.edit_rounded,
                      onPressed: () => context.go(AppRoutes.tenantForm, extra: tenancy),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(AppSpacing.minTapTarget),
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: () => end(tenancy),
                      child: Text(l10n.endTenancy),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Tenant: their owner's contact and lease ("Role: Tenant" — no Tenant Info).
class LeaseInfoPage extends ConsumerWidget {
  const LeaseInfoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return GridsPage(
      title: l10n.leaseInfoTitle,
      showMenu: false,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(tenancyProvider.future),
        child: AsyncValueView(
          value: ref.watch(tenancyProvider),
          onRetry: () => ref.invalidate(tenancyProvider),
          data: (tenancy) => tenancy == null
              ? EmptyState(icon: Icons.real_estate_agent_rounded, title: l10n.noLease, message: l10n.noLeaseHint)
              : ListView(
                  padding: AppSpacing.pagePadding,
                  children: [
                    _ContactCard(title: l10n.ownerLabel, contact: tenancy.owner),
                    _LeaseCard(tenancy: tenancy),
                    BreakdownCard(items: tenancy.rentBreakdown, title: l10n.rentBreakdownTitle),
                    const SizedBox(height: AppSpacing.md),
                    Text(l10n.payRentHint, style: TextStyle(color: GridsColors.of(context).slate)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.title, required this.contact, this.status});

  final String title;
  final Contact contact;
  final (String, StatusTone)? status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final slate = GridsColors.of(context).slate;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
        leading: PersonAvatar(name: contact.name),
        title: Text(contact.name, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$title · ${formatPhone(contact.phone)}', style: TextStyle(color: slate)),
            if (status != null) ...[
              const SizedBox(height: AppSpacing.xs),
              StatusChip(label: status!.$1, tone: status!.$2),
            ],
          ],
        ),
        trailing: IconButton.filledTonal(
          tooltip: l10n.callPerson(contact.name),
          onPressed: () => callPhone(context, contact.phone),
          icon: const Icon(Icons.call_rounded),
        ),
      ),
    );
  }
}

class _LeaseCard extends StatelessWidget {
  const _LeaseCard({required this.tenancy});

  final Tenancy tenancy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final slate = GridsColors.of(context).slate;
    final t = tenancy;
    final rows = [
      if (t.flatLabel != null) (l10n.flatLabelField, t.flatLabel!),
      (l10n.monthlyRentLabel, formatPaise(t.monthlyRentPaise)),
      (l10n.depositLabel, formatPaise(t.depositPaise)),
      (l10n.rentDueDayLabel, l10n.dueDayOfMonth(t.rentDueDay)),
      (l10n.leaseStartLabel, formatDate(context, t.startDate)),
      (l10n.leaseEndLabel, t.endDate == null ? l10n.leaseOpenEnded : formatDate(context, t.endDate!)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l10n.leaseDetailsTitle, icon: Icons.description_rounded),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                for (final (label, value) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
                    child: MergeSemantics(
                      child: Row(
                        children: [
                          Expanded(child: Text(label, style: TextStyle(color: slate))),
                          Text(value, style: theme.textTheme.bodyLarge),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Owner: add a tenant (by mobile number; they sign in with OTP) or edit the
/// rent terms of [tenancy]. No Aadhaar and no passwords.
class TenantFormPage extends ConsumerStatefulWidget {
  const TenantFormPage({super.key, this.tenancy});

  final Tenancy? tenancy;

  @override
  ConsumerState<TenantFormPage> createState() => _TenantFormPageState();
}

class _RentItem {
  _RentItem([BreakdownItem? item])
      : label = TextEditingController(text: item?.label),
        amount = TextEditingController(text: item == null ? '' : '${item.amountPaise ~/ 100}');

  final TextEditingController label;
  final TextEditingController amount;

  int get paise => ((double.tryParse(amount.text.replaceAll(',', '').trim()) ?? 0) * 100).round();

  void dispose() {
    label.dispose();
    amount.dispose();
  }
}

class _TenantFormPageState extends ConsumerState<TenantFormPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  late final _deposit = TextEditingController(
    text: widget.tenancy == null ? '' : '${widget.tenancy!.depositPaise ~/ 100}',
  );
  late final List<_RentItem> _items = widget.tenancy == null
      ? [_RentItem()]
      : [for (final i in widget.tenancy!.rentBreakdown) _RentItem(i)];
  late int _dueDay = widget.tenancy?.rentDueDay ?? 5;
  late DateTime _start = widget.tenancy?.startDate ?? DateUtils.dateOnly(DateTime.now());
  late DateTime? _end = widget.tenancy?.endDate;
  bool _saving = false;
  String? _error;

  bool get _adding => widget.tenancy == null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _deposit.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  int get _total => _items.fold(0, (sum, i) => sum + i.paise);

  Future<void> _pickDate(bool start) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : (_end ?? _start.add(const Duration(days: 330))),
      firstDate: start ? today.subtract(const Duration(days: 365 * 3)) : _start.add(const Duration(days: 1)),
      lastDate: today.add(const Duration(days: 365 * 5)),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        if (_end != null && !_end!.isAfter(picked)) _end = null;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final input = TenancyInput(
      rentBreakdown: [for (final i in _items) BreakdownItem(label: i.label.text.trim(), amountPaise: i.paise)],
      depositPaise: ((double.tryParse(_deposit.text.replaceAll(',', '').trim()) ?? 0) * 100).round(),
      rentDueDay: _dueDay,
      startDate: _start,
      endDate: _end,
      tenantName: _adding ? _name.text.trim() : null,
      tenantPhone: _adding ? Validators.normalizeIndianMobile(_phone.text) : null,
    );
    final repo = ref.read(profileRepositoryProvider);
    try {
      if (_adding) {
        await repo.addTenant(input);
      } else {
        await repo.updateTenancy(widget.tenancy!.id, input);
      }
      ref.invalidate(tenancyProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_adding ? l10n.tenantAdded : l10n.rentTermsSaved)));
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
    final validators = Validators(l10n);
    final slate = GridsColors.of(context).slate;
    final money = [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))];

    return GridsPage(
      title: _adding ? l10n.addTenant : l10n.editRentTerms,
      showMenu: false,
      showNotifications: false,
      body: Form(
        key: _form,
        onChanged: () => setState(() {}),
        child: ListView(
          padding: AppSpacing.pagePadding,
          children: [
            if (_adding) ...[
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: l10n.tenantNameField),
                textCapitalization: TextCapitalization.words,
                maxLength: 80,
                validator: (v) => validators.required(v) ?? (v!.trim().length < 2 ? l10n.validationTooShort : null),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _phone,
                decoration: InputDecoration(
                  labelText: l10n.mobileNumberLabel,
                  prefixText: '+91 ',
                  helperText: l10n.tenantInviteHint,
                  helperMaxLines: 3,
                ),
                keyboardType: TextInputType.phone,
                validator: validators.indianMobile,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text(l10n.rentBreakdownTitle, style: theme.textTheme.titleMedium),
            Text(l10n.rentBreakdownHint, style: TextStyle(color: slate)),
            const SizedBox(height: AppSpacing.sm),
            for (final (index, item) in _items.indexed)
              Padding(
                key: ObjectKey(item),
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: item.label,
                        decoration: InputDecoration(labelText: l10n.itemLabel, hintText: l10n.rentItemHint),
                        textCapitalization: TextCapitalization.words,
                        maxLength: 40,
                        validator: (v) => validators.required(v) ?? (v!.trim().length < 2 ? l10n.validationTooShort : null),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: item.amount,
                        decoration: InputDecoration(labelText: l10n.itemAmount, prefixText: '₹ '),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: money,
                        validator: (v) => validators.amount(v) ?? (item.paise < 100 ? l10n.validationAmount : null),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.removeItem,
                      onPressed: _items.length > 1 ? () => setState(() => _items.removeAt(index).dispose()) : null,
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                  ],
                ),
              ),
            if (_items.length < 10)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _items.add(_RentItem())),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.addItem),
                ),
              ),
            Row(
              children: [
                Expanded(child: Text(l10n.monthlyRentLabel, style: theme.textTheme.titleMedium)),
                Text(formatPaise(_total), style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.secondary)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _deposit,
              decoration: InputDecoration(labelText: l10n.depositLabel, prefixText: '₹ '),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: money,
              validator: validators.amount,
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<int>(
              initialValue: _dueDay,
              decoration: InputDecoration(labelText: l10n.rentDueDayLabel),
              items: [for (var d = 1; d <= 28; d++) DropdownMenuItem(value: d, child: Text(l10n.dueDayOfMonth(d)))],
              onChanged: (v) => setState(() => _dueDay = v!),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: ListTile(
                      title: Text(l10n.leaseStartLabel),
                      subtitle: Text(formatDate(context, _start)),
                      onTap: () => _pickDate(true),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Card(
                    child: ListTile(
                      title: Text(l10n.leaseEndLabel),
                      subtitle: Text(_end == null ? l10n.leaseOpenEnded : formatDate(context, _end!)),
                      onTap: () => _pickDate(false),
                      trailing: _end == null
                          ? null
                          : IconButton(
                              tooltip: l10n.clearDate,
                              onPressed: () => setState(() => _end = null),
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(label: _adding ? l10n.addTenant : l10n.save, isLoading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
