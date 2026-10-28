import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/money_models.dart';
import 'money_providers.dart';
import 'widgets/money_widgets.dart';

/// "Maintenance" for admins and owners, "Rent" for tenants.
class MaintenancePage extends ConsumerWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final role = ref.watch(currentSessionProvider)?.role;
    return GridsPage(
      title: role == UserRole.tenant ? l10n.navRent : l10n.navMaintenance,
      body: role == UserRole.admin ? const _AdminView() : _ResidentView(isTenant: role == UserRole.tenant),
    );
  }
}

class _ResidentView extends ConsumerWidget {
  const _ResidentView({required this.isTenant});

  final bool isTenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dues = ref.watch(myDuesProvider);
    final payments = ref.watch(myPaymentsProvider(3));
    // Owners can always see the current charge; tenants' rent items come from their dues/receipts.
    final config = isTenant ? null : ref.watch(maintenanceConfigProvider);

    Future<void> refresh() async {
      ref
        ..invalidate(myDuesProvider)
        ..invalidate(myPaymentsProvider)
        ..invalidate(maintenanceConfigProvider);
      await ref.read(myDuesProvider.future);
    }

    final pending = dues.value ?? const <Due>[];
    final breakdown = pending.isNotEmpty
        ? pending.first.breakdown
        : config?.value?.items ?? payments.value?.firstOrNull?.breakdown ?? const <BreakdownItem>[];

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
        children: [
          SectionHeader(
            title: isTenant ? l10n.rentDueTitle : l10n.maintenanceDueTitle,
            icon: Icons.currency_rupee_rounded,
          ),
          ...dues.when(
            skipLoadingOnRefresh: true,
            loading: () => const [Padding(padding: EdgeInsets.all(AppSpacing.xl), child: Center(child: CircularProgressIndicator()))],
            error: (e, _) => [
              EmptyState(
                icon: Icons.cloud_off_rounded,
                title: l10n.errorGeneric,
                actionLabel: l10n.retry,
                onAction: () => ref.invalidate(myDuesProvider),
              ),
            ],
            data: (list) => list.isEmpty
                ? [
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.verified_rounded, color: GridsColors.of(context).success, size: 32),
                        title: Text(l10n.allPaidUp, style: Theme.of(context).textTheme.titleMedium),
                        subtitle: Text(l10n.allPaidUpBody),
                      ),
                    ),
                  ]
                : [
                    for (final due in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: DueCard(due: due, onPay: () => context.go(AppRoutes.payDue(due.id), extra: due)),
                      ),
                  ],
          ),
          if (breakdown.isNotEmpty) BreakdownCard(items: breakdown),
          AsyncSection(
            title: l10n.paymentHistory,
            icon: Icons.history_rounded,
            value: payments,
            isEmpty: (p) => p.isEmpty,
            emptyText: l10n.noPayments,
            onViewAll: () => context.go(AppRoutes.paymentHistory),
            onRetry: () => ref.invalidate(myPaymentsProvider),
            builder: (list) => Column(
              children: [
                for (final p in list)
                  PaymentRow(payment: p, onTap: () => context.go(AppRoutes.receipt(p.id))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminView extends ConsumerWidget {
  const _AdminView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final summary = ref.watch(maintenanceSummaryProvider);
    final config = ref.watch(maintenanceConfigProvider);
    final bills = ref.watch(societyBillsProvider(false));

    Future<void> refresh() async {
      ref
        ..invalidate(maintenanceSummaryProvider)
        ..invalidate(maintenanceConfigProvider)
        ..invalidate(societyBillsProvider);
      await ref.read(maintenanceSummaryProvider.future);
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
        children: [
          AsyncSection(
            title: l10n.maintenanceDueTitle,
            icon: Icons.currency_rupee_rounded,
            value: summary,
            emptyText: '',
            onRetry: () => ref.invalidate(maintenanceSummaryProvider),
            builder: (s) => InkWell(
              onTap: () => context.go(AppRoutes.defaulters),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.sm, AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.maintenanceDueFlats(s.pendingFlats), style: theme.textTheme.titleMedium),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            l10n.pendingAmount(formatPaise(s.pendingAmountPaise)),
                            style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.secondary),
                          ),
                          Text(
                            l10n.collectedThisMonth(formatPaise(s.collectedThisMonthPaise)),
                            style: TextStyle(color: GridsColors.of(context).slate),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: GridsColors.of(context).slate),
                  ],
                ),
              ),
            ),
          ),
          ...config.when(
            skipLoadingOnRefresh: true,
            loading: () => const <Widget>[],
            error: (_, _) => const <Widget>[],
            data: (c) => [BreakdownCard(items: c.items)],
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: l10n.updateMaintenance,
            icon: Icons.edit_rounded,
            onPressed: () => context.go(AppRoutes.maintenanceConfig),
          ),
          AsyncSection(
            title: l10n.societyBillsTitle,
            icon: Icons.account_balance_wallet_rounded,
            value: bills,
            isEmpty: (b) => b.isEmpty,
            emptyText: l10n.noBills,
            onViewAll: () => context.go(AppRoutes.societyBills),
            onRetry: () => ref.invalidate(societyBillsProvider),
            builder: (list) => Column(
              children: [
                for (final bill in list.take(4))
                  ListTile(
                    title: Text(bill.vendor),
                    subtitle: Text(
                      l10n.dueOn(formatDayMonth(context, bill.dueDate)),
                      // Overdue bills stand out, as on the full bills page.
                      style: bill.dueDate.isBefore(DateUtils.dateOnly(DateTime.now()))
                          ? TextStyle(color: GridsColors.of(context).danger)
                          : null,
                    ),
                    trailing: Text(formatPaise(bill.amountPaise), style: theme.textTheme.titleMedium),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
