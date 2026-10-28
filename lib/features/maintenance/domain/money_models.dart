import 'package:flutter/foundation.dart';

@immutable
class BreakdownItem {
  const BreakdownItem({required this.label, required this.amountPaise});

  final String label;
  final int amountPaise;

  Map<String, Object> toJson() => {'label': label, 'amountPaise': amountPaise};
}

enum DueType { maintenance, rent }

@immutable
class Due {
  const Due({
    required this.id,
    required this.type,
    required this.period,
    required this.amountPaise,
    required this.breakdown,
    required this.dueDate,
    required this.overdue,
    this.flatLabel,
  });

  final String id;
  final DueType type;

  /// "2026-10"
  final String period;
  final int amountPaise;
  final List<BreakdownItem> breakdown;
  final DateTime dueDate;
  final bool overdue;
  final String? flatLabel;

  DateTime get periodMonth => DateTime(int.parse(period.substring(0, 4)), int.parse(period.substring(5, 7)));
}

enum PaymentStatus { created, pending, succeeded, failed }

@immutable
class Payment {
  const Payment({
    required this.id,
    required this.status,
    required this.amountPaise,
    required this.gateway,
    required this.dueType,
    required this.period,
    required this.breakdown,
    required this.payerName,
    required this.societyName,
    this.method,
    this.receiptNo,
    this.paidAt,
    this.transactionId,
    this.failureReason,
    this.flatLabel,
  });

  final String id;
  final PaymentStatus status;
  final int amountPaise;
  final String? method;
  final String gateway;
  final String? receiptNo;
  final DateTime? paidAt;
  final String? transactionId;
  final String? failureReason;
  final DueType dueType;
  final String period;
  final List<BreakdownItem> breakdown;
  final String payerName;
  final String? flatLabel;
  final String societyName;

  DateTime get periodMonth => DateTime(int.parse(period.substring(0, 4)), int.parse(period.substring(5, 7)));
}

/// What the server hands the app to open the payment sheet.
@immutable
class Checkout {
  const Checkout({
    required this.paymentId,
    required this.isSimulated,
    required this.orderId,
    required this.amountPaise,
    required this.name,
    required this.description,
    required this.prefillName,
    required this.prefillContact,
    this.keyId,
    this.prefillEmail,
    this.prefillMethod,
  });

  final String paymentId;

  /// Dev builds without Razorpay keys use a simulated checkout.
  final bool isSimulated;

  /// Razorpay key id (null for the simulator).
  final String? keyId;
  final String orderId;
  final int amountPaise;
  final String name;
  final String description;
  final String prefillName;
  final String prefillContact;
  final String? prefillEmail;

  /// upi | card | netbanking, from the payer's Payment Settings.
  final String? prefillMethod;
}

/// How the payment sheet ended.
sealed class CheckoutResult {
  const CheckoutResult();
}

final class CheckoutSucceeded extends CheckoutResult {
  const CheckoutSucceeded({required this.orderId, required this.gatewayPaymentId, required this.signature, this.method});
  final String orderId;
  final String gatewayPaymentId;
  final String signature;

  /// Only known up front for the simulator; Razorpay's is looked up server-side.
  final String? method;
}

final class CheckoutCancelled extends CheckoutResult {
  const CheckoutCancelled();
}

final class CheckoutFailed extends CheckoutResult {
  const CheckoutFailed(this.message);
  final String? message;
}

/// Paid through an external wallet app; the server confirms via webhook.
final class CheckoutPending extends CheckoutResult {
  const CheckoutPending();
}

@immutable
class MaintenanceConfig {
  const MaintenanceConfig({required this.items, required this.totalPaise, required this.dueDay});

  final List<BreakdownItem> items;
  final int totalPaise;
  final int dueDay;
}

@immutable
class MaintenanceSummary {
  const MaintenanceSummary({
    required this.pendingFlats,
    required this.pendingAmountPaise,
    required this.collectedThisMonthPaise,
  });

  final int pendingFlats;
  final int pendingAmountPaise;
  final int collectedThisMonthPaise;
}

@immutable
class Defaulter {
  const Defaulter({
    required this.flatId,
    required this.flatLabel,
    required this.owners,
    required this.dues,
    required this.amountPaise,
    required this.oldestDueDate,
    this.lastRemindedAt,
  });

  final String flatId;
  final String flatLabel;
  final List<String> owners;
  final int dues;
  final int amountPaise;
  final DateTime oldestDueDate;
  final DateTime? lastRemindedAt;

  bool remindedRecently(DateTime now) => lastRemindedAt != null && now.difference(lastRemindedAt!) < const Duration(hours: 24);
}

@immutable
class SocietyBill {
  const SocietyBill({
    required this.id,
    required this.vendor,
    required this.amountPaise,
    required this.dueDate,
    required this.paid,
    this.category,
    this.paidAt,
  });

  final String id;
  final String vendor;
  final String? category;
  final int amountPaise;
  final DateTime dueDate;
  final bool paid;
  final DateTime? paidAt;
}
