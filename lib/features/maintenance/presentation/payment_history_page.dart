import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import 'money_providers.dart';
import 'widgets/money_widgets.dart';

class PaymentHistoryPage extends ConsumerWidget {
  const PaymentHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return GridsPage(
      title: l10n.paymentHistory,
      showMenu: false,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myPaymentsProvider(null).future),
        child: AsyncValueView(
          value: ref.watch(myPaymentsProvider(null)),
          onRetry: () => ref.invalidate(myPaymentsProvider(null)),
          isEmpty: (list) => list.isEmpty,
          empty: EmptyState(icon: Icons.receipt_long_rounded, title: l10n.noPayments),
          data: (list) => ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, i) => PaymentRow(
              payment: list[i],
              onTap: () => context.push(AppRoutes.receipt(list[i].id)),
            ),
          ),
        ),
      ),
    );
  }
}
