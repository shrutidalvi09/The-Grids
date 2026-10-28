import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/primary_button.dart';
import '../domain/money_models.dart';
import 'money_repository.dart';

/// Opens the payment sheet for a [Checkout] and reports how it ended.
abstract interface class CheckoutLauncher {
  Future<CheckoutResult> open(BuildContext context, Checkout checkout);
}

/// Razorpay Checkout: UPI (Google Pay, PhonePe…), cards, net banking, wallets.
/// Card details are entered in Razorpay's own UI and never reach the app.
class RazorpayCheckoutLauncher implements CheckoutLauncher {
  @override
  Future<CheckoutResult> open(BuildContext context, Checkout checkout) {
    final completer = Completer<CheckoutResult>();
    final razorpay = Razorpay();
    void finish(CheckoutResult result) {
      if (!completer.isCompleted) completer.complete(result);
      razorpay.clear();
    }

    razorpay
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
        if (r.paymentId == null || r.orderId == null || r.signature == null) {
          finish(const CheckoutPending()); // let the webhook settle it
        } else {
          finish(CheckoutSucceeded(orderId: r.orderId!, gatewayPaymentId: r.paymentId!, signature: r.signature!));
        }
      })
      ..on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
        finish(r.code == Razorpay.PAYMENT_CANCELLED ? const CheckoutCancelled() : CheckoutFailed(r.message));
      })
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse _) => finish(const CheckoutPending()));

    razorpay.open({
      'key': checkout.keyId,
      'order_id': checkout.orderId,
      'amount': checkout.amountPaise,
      'currency': 'INR',
      'name': checkout.name,
      'description': checkout.description,
      'prefill': {
        'name': checkout.prefillName,
        'contact': checkout.prefillContact,
        'email': ?checkout.prefillEmail,
        // Profile → Payment Settings: open on the payer's preferred method.
        'method': ?checkout.prefillMethod,
      },
      'theme': {'color': '#2E7D32'},
      'retry': {'enabled': true, 'max_count': 3},
    });
    return completer.future;
  }
}

/// Development stand-in when the backend has no Razorpay keys: a sheet that
/// lets you pick an outcome. The server signs the "payment" exactly as
/// Razorpay would, so verification and receipts run for real.
class SimulatedCheckoutLauncher implements CheckoutLauncher {
  SimulatedCheckoutLauncher(this._repository);

  final MoneyRepository _repository;

  @override
  Future<CheckoutResult> open(BuildContext context, Checkout checkout) async {
    final choice = await showModalBottomSheet<(bool, String)>(
      useRootNavigator: true, // above the bottom nav bar
      context: context,
      useSafeArea: true,
      builder: (sheet) => _SimulatedSheet(checkout: checkout),
    );
    if (choice == null) return const CheckoutCancelled();
    final (succeed, method) = choice;
    try {
      return await _repository.simulate(checkout.paymentId, succeed: succeed, method: method);
    } on ApiException catch (e) {
      return CheckoutFailed(e.message);
    }
  }
}

class _SimulatedSheet extends StatefulWidget {
  const _SimulatedSheet({required this.checkout});

  final Checkout checkout;

  @override
  State<_SimulatedSheet> createState() => _SimulatedSheetState();
}

class _SimulatedSheetState extends State<_SimulatedSheet> {
  String _method = 'upi';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.developer_mode_rounded),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(l10n.simulatedCheckoutTitle, style: theme.textTheme.titleLarge)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.simulatedCheckoutBody),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '${widget.checkout.description} · ${formatPaise(widget.checkout.amountPaise)}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'upi', label: Text(l10n.methodUpi)),
              ButtonSegment(value: 'card', label: Text(l10n.methodCardShort)),
              ButtonSegment(value: 'netbanking', label: Text(l10n.methodNetbankingShort)),
            ],
            selected: {_method},
            onSelectionChanged: (s) => setState(() => _method = s.single),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: l10n.simulateSuccess,
            onPressed: () => Navigator.of(context).pop((true, _method)),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop((false, _method)),
            child: Text(l10n.simulateFailure),
          ),
        ],
      ),
    );
  }
}

/// Picks the launcher for a checkout; refuses simulated payments outside dev.
class CheckoutLaunchers implements CheckoutLauncher {
  CheckoutLaunchers({required this.razorpay, required this.simulated, required this.allowSimulated});

  final CheckoutLauncher razorpay;
  final CheckoutLauncher simulated;
  final bool allowSimulated;

  @override
  Future<CheckoutResult> open(BuildContext context, Checkout checkout) {
    if (!checkout.isSimulated) return razorpay.open(context, checkout);
    if (!allowSimulated) return Future.value(const CheckoutFailed('Payments are not configured'));
    return simulated.open(context, checkout);
  }
}

final checkoutLauncherProvider = Provider<CheckoutLauncher>(
  (ref) => CheckoutLaunchers(
    razorpay: RazorpayCheckoutLauncher(),
    simulated: SimulatedCheckoutLauncher(ref.watch(moneyRepositoryProvider)),
    allowSimulated: ref.watch(appConfigProvider).isDev,
  ),
);
