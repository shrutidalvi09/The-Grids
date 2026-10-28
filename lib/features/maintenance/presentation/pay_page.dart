import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../home/presentation/home_providers.dart';
import '../data/checkout_launcher.dart';
import '../data/money_repository.dart';
import '../domain/money_models.dart';
import 'money_providers.dart';
import 'widgets/money_widgets.dart';

/// Pays one due: server creates the order → Razorpay Checkout → server
/// verifies the signature → receipt. The app never sees card details.
class PayPage extends ConsumerWidget {
  const PayPage({super.key, required this.dueId, this.due});

  final String dueId;

  /// Passed from the Maintenance tab; looked up again if the page is opened directly.
  final Due? due;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final known = due;
    return GridsPage(
      title: l10n.payNow,
      showMenu: false,
      showNotifications: false,
      body: known != null
          ? _PayView(due: known)
          : AsyncValueView(
              value: ref.watch(myDuesProvider),
              onRetry: () => ref.invalidate(myDuesProvider),
              data: (dues) {
                final match = dues.where((d) => d.id == dueId).firstOrNull;
                return match != null
                    ? _PayView(due: match)
                    : EmptyState(
                        icon: Icons.verified_rounded,
                        title: l10n.allPaidUp,
                        message: l10n.errorDueAlreadyPaid,
                        actionLabel: l10n.navMaintenance,
                        onAction: () => context.go(AppRoutes.maintenance),
                      );
              },
            ),
    );
  }
}

enum _Phase { ready, working, verifying, failed, pending }

class _PayView extends ConsumerStatefulWidget {
  const _PayView({required this.due});

  final Due due;

  @override
  ConsumerState<_PayView> createState() => _PayViewState();
}

class _PayViewState extends ConsumerState<_PayView> {
  _Phase _phase = _Phase.ready;
  String? _error;
  String? _paymentId;

  void _set(_Phase phase, {String? error}) {
    if (!mounted) return;
    setState(() {
      _phase = phase;
      _error = error;
    });
  }

  Future<void> _pay() async {
    final l10n = context.l10n;
    final repo = ref.read(moneyRepositoryProvider);
    final launcher = ref.read(checkoutLauncherProvider);
    _set(_Phase.working);

    final Checkout checkout;
    try {
      checkout = await repo.createOrder(widget.due.id);
    } on ApiException catch (e) {
      if (e.code == 'DUE_NOT_PENDING') return _alreadyPaid();
      return _set(_Phase.failed, error: describeError(l10n, e));
    }
    _paymentId = checkout.paymentId;
    if (!mounted) return;

    final result = await launcher.open(context, checkout);
    switch (result) {
      case CheckoutCancelled():
        _set(_Phase.ready);
        if (mounted) _snack(l10n.paymentCancelled);
      case CheckoutFailed():
        _set(_Phase.failed, error: l10n.paymentFailedBody);
      case CheckoutPending():
        _set(_Phase.pending);
      case final CheckoutSucceeded success:
        _set(_Phase.verifying);
        try {
          final payment = await repo.verify(checkout.paymentId, success);
          _done(payment.id);
        } on ApiException catch (e) {
          // A bad signature is a real failure; anything else (network) may
          // still settle through the webhook, so let the user check again.
          if (e.code == 'PAYMENT_VERIFICATION_FAILED') {
            _set(_Phase.failed, error: l10n.errorPaymentVerification);
          } else {
            _set(_Phase.pending);
          }
        }
    }
  }

  Future<void> _checkStatus() async {
    final l10n = context.l10n;
    final id = _paymentId;
    if (id == null) return;
    _set(_Phase.verifying);
    try {
      final payment = await ref.read(moneyRepositoryProvider).payment(id);
      switch (payment.status) {
        case PaymentStatus.succeeded:
          _done(payment.id);
        case PaymentStatus.failed:
          _set(_Phase.failed, error: l10n.paymentFailedBody);
        case PaymentStatus.created || PaymentStatus.pending:
          _set(_Phase.pending);
          if (mounted) _snack(l10n.paymentPendingBody);
      }
    } catch (e) {
      _set(_Phase.pending);
      if (mounted) _snack(describeError(l10n, e));
    }
  }

  void _done(String paymentId) {
    invalidateAfterPayment(ref);
    ref.invalidate(homeProvider);
    // The receipt page itself says "Payment Successful".
    if (mounted) context.pushReplacement(AppRoutes.receipt(paymentId));
  }

  void _alreadyPaid() {
    invalidateAfterPayment(ref);
    if (!mounted) return;
    _snack(context.l10n.errorDueAlreadyPaid);
    context.go(AppRoutes.maintenance);
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final grids = GridsColors.of(context);
    final due = widget.due;
    final busy = _phase == _Phase.working || _phase == _Phase.verifying;

    return PopScope(
      // Don't walk away mid-verification; the result would be lost on screen.
      canPop: _phase != _Phase.verifying,
      child: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          AmountCard(
            title: due.type == DueType.rent ? l10n.rentDueTitle : l10n.maintenanceDueTitle,
            amount: due.amountPaise / 100,
            caption: [
              formatPeriod(context, due.periodMonth),
              ?due.flatLabel,
              due.overdue
                  ? l10n.overdueSince(formatDayMonth(context, due.dueDate))
                  : l10n.dueOn(formatDayMonth(context, due.dueDate)),
            ].join(' · '),
          ),
          if (due.breakdown.isNotEmpty) BreakdownCard(items: due.breakdown),
          const SizedBox(height: AppSpacing.lg),
          if (_phase == _Phase.failed)
            _StatusCard(
              icon: Icons.error_outline_rounded,
              color: grids.danger,
              title: l10n.paymentFailedTitle,
              body: _error ?? l10n.paymentFailedBody,
            ),
          if (_phase == _Phase.pending)
            _StatusCard(
              icon: Icons.hourglass_top_rounded,
              color: grids.warning,
              title: l10n.paymentPendingTitle,
              body: l10n.paymentPendingBody,
              action: OutlinedButton(onPressed: _checkStatus, child: Text(l10n.checkStatus)),
            ),
          if (_phase == _Phase.verifying)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(l10n.confirmingPayment, style: theme.textTheme.bodyLarge)),
                ],
              ),
            ),
          if (_phase != _Phase.pending)
            PrimaryButton(
              label: _phase == _Phase.failed ? l10n.tryAgain : l10n.payAmount(formatPaise(due.amountPaise)),
              icon: Icons.lock_rounded,
              isLoading: busy,
              onPressed: busy ? null : _pay,
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_rounded, size: 18, color: grids.slate),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(l10n.securePaymentNote, style: TextStyle(color: grids.slate))),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.icon, required this.color, required this.title, required this.body, this.action});

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Semantics(
          liveRegion: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium?.copyWith(color: color)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(body),
                    if (action != null) ...[const SizedBox(height: AppSpacing.sm), action!],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
