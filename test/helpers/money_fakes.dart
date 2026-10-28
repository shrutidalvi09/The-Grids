import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:the_grids/core/network/api_exception.dart';
import 'package:the_grids/features/maintenance/data/checkout_launcher.dart';
import 'package:the_grids/features/maintenance/data/money_repository.dart';
import 'package:the_grids/features/maintenance/data/receipt_files.dart';
import 'package:the_grids/features/maintenance/domain/money_models.dart';

final _unused = Dio();
final _now = DateTime.now();

const sampleBreakdown = [
  BreakdownItem(label: 'Sinking Fund', amountPaise: 50000),
  BreakdownItem(label: 'Water Charges', amountPaise: 30000),
  BreakdownItem(label: 'Security', amountPaise: 120000),
  BreakdownItem(label: 'Housekeeping', amountPaise: 50000),
];

String _period(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

Due sampleDue({String id = 'd1', DueType type = DueType.maintenance, bool overdue = false}) => Due(
      id: id,
      type: type,
      period: _period(_now),
      amountPaise: type == DueType.rent ? 1500000 : 250000,
      breakdown: type == DueType.rent ? const [BreakdownItem(label: 'Rent', amountPaise: 1500000)] : sampleBreakdown,
      dueDate: DateTime(_now.year, _now.month, 10),
      overdue: overdue,
      flatLabel: 'Tower-A, 101',
    );

Payment samplePayment({
  String id = 'p1',
  PaymentStatus status = PaymentStatus.succeeded,
  DueType dueType = DueType.maintenance,
  int amountPaise = 250000,
}) =>
    Payment(
      id: id,
      status: status,
      amountPaise: amountPaise,
      gateway: 'SIMULATED',
      dueType: dueType,
      period: _period(_now),
      breakdown: sampleBreakdown,
      payerName: 'Shruti Chetan Dalvi',
      flatLabel: 'Tower-A, 101',
      societyName: 'Sai Icon Co-operative Society',
      method: 'upi',
      receiptNo: status == PaymentStatus.succeeded ? 'MNT/2026/10/0007' : null,
      paidAt: status == PaymentStatus.succeeded ? _now : null,
      transactionId: status == PaymentStatus.succeeded ? 'pay_TEST123' : null,
    );

/// In-memory dues and payments. Paying a due moves it to the history.
class FakeMoneyRepository extends MoneyRepository {
  FakeMoneyRepository() : super(_unused);

  List<Due> dues = [sampleDue()];
  List<Payment> payments = [];
  MaintenanceConfig maintenanceConfig = const MaintenanceConfig(items: sampleBreakdown, totalPaise: 250000, dueDay: 10);
  List<Defaulter> defaulterList = [
    Defaulter(
      flatId: 'flat1',
      flatLabel: 'Tower-B, 204',
      owners: const ['Arjun Mehta'],
      dues: 2,
      amountPaise: 500000,
      oldestDueDate: _now.subtract(const Duration(days: 40)),
    ),
  ];
  List<SocietyBill> billList = [
    SocietyBill(id: 'b1', vendor: 'MSEDCL Electricity', category: 'Utilities', amountPaise: 4520000, dueDate: _now.add(const Duration(days: 5)), paid: false),
  ];

  /// Error thrown by [verify] instead of settling (e.g. network loss).
  Object? verifyError;
  Object? createOrderError;
  final verified = <String>[];
  final reminded = <String>[];
  final savedConfigs = <(List<BreakdownItem>, int)>[];
  final paidBills = <String>[];
  final addedBills = <String>[];

  /// What [payment] returns for an unsettled checkout.
  PaymentStatus pendingLookup = PaymentStatus.pending;

  final _orders = <String, Due>{};

  @override
  Future<List<Due>> myDues() async => List.of(dues);

  @override
  Future<List<Payment>> myPayments({int? limit}) async => limit == null ? List.of(payments) : payments.take(limit).toList();

  @override
  Future<Payment> payment(String id) async {
    final found = payments.where((p) => p.id == id).firstOrNull;
    if (found != null) return found;
    final due = _orders[id];
    if (due == null) throw const ApiException(code: 'NOT_FOUND', message: 'Not found', statusCode: 404);
    if (pendingLookup == PaymentStatus.succeeded) return _settle(id);
    return samplePayment(id: id, status: pendingLookup);
  }

  @override
  Future<Checkout> createOrder(String dueId) async {
    if (createOrderError != null) throw createOrderError!;
    final due = dues.firstWhere((d) => d.id == dueId);
    final paymentId = 'pay-${_orders.length + 1}';
    _orders[paymentId] = due;
    return Checkout(
      paymentId: paymentId,
      isSimulated: true,
      orderId: 'order_$paymentId',
      amountPaise: due.amountPaise,
      name: 'Sai Icon Co-operative Society',
      description: 'Maintenance',
      prefillName: 'Shruti Chetan Dalvi',
      prefillContact: '+919000000001',
    );
  }

  @override
  Future<Payment> verify(String paymentId, CheckoutSucceeded result) async {
    if (verifyError != null) throw verifyError!;
    verified.add(paymentId);
    return _settle(paymentId);
  }

  Payment _settle(String paymentId) {
    final due = _orders[paymentId]!;
    dues = dues.where((d) => d.id != due.id).toList();
    final paid = samplePayment(id: paymentId, dueType: due.type, amountPaise: due.amountPaise);
    payments = [paid, ...payments];
    return paid;
  }

  @override
  Future<MaintenanceConfig> config() async => maintenanceConfig;

  @override
  Future<void> updateConfig(List<BreakdownItem> items, int dueDay) async {
    savedConfigs.add((items, dueDay));
    maintenanceConfig = MaintenanceConfig(
      items: items,
      totalPaise: items.fold(0, (sum, i) => sum + i.amountPaise),
      dueDay: dueDay,
    );
  }

  @override
  Future<MaintenanceSummary> summary() async =>
      const MaintenanceSummary(pendingFlats: 7, pendingAmountPaise: 1750000, collectedThisMonthPaise: 5750000);

  @override
  Future<List<Defaulter>> defaulters() async => List.of(defaulterList);

  @override
  Future<void> remind(String flatId) async {
    reminded.add(flatId);
    defaulterList = [
      for (final d in defaulterList)
        d.flatId == flatId
            ? Defaulter(
                flatId: d.flatId,
                flatLabel: d.flatLabel,
                owners: d.owners,
                dues: d.dues,
                amountPaise: d.amountPaise,
                oldestDueDate: d.oldestDueDate,
                lastRemindedAt: DateTime.now(),
              )
            : d,
    ];
  }

  @override
  Future<List<SocietyBill>> bills({required bool paid}) async => billList.where((b) => b.paid == paid).toList();

  @override
  Future<void> addBill({required String vendor, String? category, required int amountPaise, required DateTime dueDate}) async {
    addedBills.add(vendor);
    billList = [
      ...billList,
      SocietyBill(id: 'b${billList.length + 1}', vendor: vendor, category: category, amountPaise: amountPaise, dueDate: dueDate, paid: false),
    ];
  }

  @override
  Future<void> markBillPaid(String id) async {
    paidBills.add(id);
    billList = [
      for (final b in billList)
        b.id == id
            ? SocietyBill(id: b.id, vendor: b.vendor, category: b.category, amountPaise: b.amountPaise, dueDate: b.dueDate, paid: true, paidAt: DateTime.now())
            : b,
    ];
  }
}

/// Ends every checkout with [result] (as Razorpay would) without UI.
class FakeCheckoutLauncher implements CheckoutLauncher {
  CheckoutResult result = const CheckoutSucceeded(orderId: 'order', gatewayPaymentId: 'pay_TEST123', signature: 'sig');
  final opened = <Checkout>[];

  @override
  Future<CheckoutResult> open(BuildContext context, Checkout checkout) async {
    opened.add(checkout);
    return result;
  }
}

class FakeReceiptFiles implements ReceiptFiles {
  final downloaded = <String>[];
  final shared = <(String, String)>[];
  bool hasViewer = true;

  @override
  Future<bool> download(String paymentId) async {
    downloaded.add(paymentId);
    return hasViewer;
  }

  @override
  Future<void> share(String paymentId, {required String message}) async => shared.add((paymentId, message));
}
