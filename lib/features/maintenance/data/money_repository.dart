import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_call.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/money_models.dart';

List<BreakdownItem> _breakdown(Object? json) => parseList(
      json,
      (j) => BreakdownItem(label: j['label'] as String, amountPaise: j['amountPaise'] as int),
    );

DueType _dueType(Object? value) => value == 'RENT' ? DueType.rent : DueType.maintenance;

Due dueFromJson(Json j) => Due(
      id: j['id'] as String,
      type: _dueType(j['type']),
      period: j['period'] as String,
      amountPaise: j['amountPaise'] as int,
      breakdown: _breakdown(j['breakdown']),
      dueDate: parseTime(j['dueDate']),
      overdue: j['overdue'] as bool,
      flatLabel: j['flatLabel'] as String?,
    );

const _statuses = {
  'CREATED': PaymentStatus.created,
  'PENDING': PaymentStatus.pending,
  'SUCCEEDED': PaymentStatus.succeeded,
  'FAILED': PaymentStatus.failed,
};

Payment paymentFromJson(Json j) {
  final due = j['due'] as Json;
  return Payment(
    id: j['id'] as String,
    status: _statuses[j['status']]!,
    amountPaise: j['amountPaise'] as int,
    method: j['method'] as String?,
    gateway: j['gateway'] as String,
    receiptNo: j['receiptNo'] as String?,
    paidAt: parseTimeOrNull(j['paidAt']),
    transactionId: j['transactionId'] as String?,
    failureReason: j['failureReason'] as String?,
    dueType: _dueType(due['type']),
    period: due['period'] as String,
    breakdown: _breakdown(due['breakdown']),
    payerName: j['payerName'] as String,
    flatLabel: j['flatLabel'] as String?,
    societyName: j['societyName'] as String,
  );
}

Checkout checkoutFromJson(Json j) {
  final prefill = j['prefill'] as Json;
  return Checkout(
    paymentId: j['paymentId'] as String,
    isSimulated: j['gateway'] == 'simulated',
    keyId: j['keyId'] as String?,
    orderId: j['orderId'] as String,
    amountPaise: j['amountPaise'] as int,
    name: j['name'] as String,
    description: j['description'] as String,
    prefillName: prefill['name'] as String,
    prefillContact: prefill['contact'] as String,
    prefillEmail: prefill['email'] as String?,
  );
}

Defaulter defaulterFromJson(Json j) => Defaulter(
      flatId: j['flatId'] as String,
      flatLabel: j['flatLabel'] as String,
      owners: [for (final o in j['owners'] as List<dynamic>) o as String],
      dues: j['dues'] as int,
      amountPaise: j['amountPaise'] as int,
      oldestDueDate: parseTime(j['oldestDueDate']),
      lastRemindedAt: parseTimeOrNull(j['lastRemindedAt']),
    );

SocietyBill billFromJson(Json j) => SocietyBill(
      id: j['id'] as String,
      vendor: j['vendor'] as String,
      category: j['category'] as String?,
      amountPaise: j['amountPaise'] as int,
      dueDate: parseTime(j['dueDate']),
      paid: j['status'] == 'PAID',
      paidAt: parseTimeOrNull(j['paidAt']),
    );

/// Dues, payments, receipts, maintenance settings and society bills.
class MoneyRepository {
  MoneyRepository(this._dio);

  final Dio _dio;

  Future<List<Due>> myDues() => apiCall(() async => parseList((await _dio.get<List<dynamic>>('/dues/mine')).data, dueFromJson));

  Future<List<Payment>> myPayments({int? limit}) => apiCall(() async => parseList(
        (await _dio.get<List<dynamic>>('/payments/mine', queryParameters: {'limit': ?limit})).data,
        paymentFromJson,
      ));

  Future<Payment> payment(String id) => apiCall(() async => paymentFromJson((await _dio.get<Json>('/payments/$id')).data!));

  Future<Checkout> createOrder(String dueId) =>
      apiCall(() async => checkoutFromJson((await _dio.post<Json>('/payments/orders', data: {'dueId': dueId})).data!));

  Future<Payment> verify(String paymentId, CheckoutSucceeded result) => apiCall(() async {
        final response = await _dio.post<Json>('/payments/verify', data: {
          'paymentId': paymentId,
          'orderId': result.orderId,
          'gatewayPaymentId': result.gatewayPaymentId,
          'signature': result.signature,
          'method': ?result.method,
        });
        return paymentFromJson(response.data!);
      });

  /// Dev only: ask the server what the simulated checkout returns.
  Future<CheckoutResult> simulate(String paymentId, {required bool succeed, String method = 'upi'}) => apiCall(() async {
        final response = await _dio.post<Json>(
          '/payments/$paymentId/simulate',
          data: {'outcome': succeed ? 'success' : 'failure'},
        );
        final body = response.data!;
        if (body['failed'] == true) return CheckoutFailed(body['reason'] as String?);
        return CheckoutSucceeded(
          orderId: body['orderId'] as String,
          gatewayPaymentId: body['gatewayPaymentId'] as String,
          signature: body['signature'] as String,
          method: method,
        );
      });

  /// PDF bytes and a suggested file name.
  Future<(Uint8List, String)> receiptPdf(String paymentId) => apiCall(() async {
        final response = await _dio.get<List<int>>(
          '/payments/$paymentId/receipt',
          options: Options(responseType: ResponseType.bytes),
        );
        final disposition = response.headers.value('content-disposition') ?? '';
        final name = RegExp(r'filename="([^"]+)"').firstMatch(disposition)?.group(1) ?? 'receipt.pdf';
        return (Uint8List.fromList(response.data!), name);
      });

  Future<MaintenanceConfig> config() => apiCall(() async {
        final j = (await _dio.get<Json>('/maintenance/config')).data!;
        return MaintenanceConfig(items: _breakdown(j['items']), totalPaise: j['totalPaise'] as int, dueDay: j['dueDay'] as int);
      });

  Future<void> updateConfig(List<BreakdownItem> items, int dueDay) => apiCall(
        () => _dio.put<void>('/maintenance/config', data: {
          'items': [for (final i in items) i.toJson()],
          'dueDay': dueDay,
        }),
      );

  Future<MaintenanceSummary> summary() => apiCall(() async {
        final j = (await _dio.get<Json>('/maintenance/summary')).data!;
        return MaintenanceSummary(
          pendingFlats: j['pendingFlats'] as int,
          pendingAmountPaise: j['pendingAmountPaise'] as int,
          collectedThisMonthPaise: j['collectedThisMonthPaise'] as int,
        );
      });

  Future<List<Defaulter>> defaulters() => apiCall(
        () async => parseList((await _dio.get<List<dynamic>>('/maintenance/defaulters')).data, defaulterFromJson),
      );

  Future<void> remind(String flatId) => apiCall(() => _dio.post<void>('/maintenance/defaulters/$flatId/remind'));

  Future<List<SocietyBill>> bills({required bool paid}) => apiCall(() async => parseList(
        (await _dio.get<List<dynamic>>('/society-bills', queryParameters: {'status': paid ? 'PAID' : 'DUE'})).data,
        billFromJson,
      ));

  Future<void> addBill({required String vendor, String? category, required int amountPaise, required DateTime dueDate}) =>
      apiCall(() => _dio.post<void>('/society-bills', data: {
            'vendor': vendor,
            'category': ?category,
            'amountPaise': amountPaise,
            'dueDate': dueDate.toUtc().toIso8601String(),
          }));

  Future<void> markBillPaid(String id) => apiCall(() => _dio.patch<void>('/society-bills/$id/paid'));
}

final moneyRepositoryProvider = Provider<MoneyRepository>((ref) => MoneyRepository(ref.watch(authedDioProvider)));
