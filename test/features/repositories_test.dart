import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_grids/core/network/api_exception.dart';
import 'package:the_grids/features/community/data/community_repository.dart';
import 'package:the_grids/features/maintenance/data/money_repository.dart';
import 'package:the_grids/features/maintenance/domain/money_models.dart';
import 'package:the_grids/features/notifications/data/notifications_repository.dart';
import 'package:the_grids/features/profile/data/profile_repository.dart';
import 'package:the_grids/features/profile/domain/profile_models.dart';

import '../helpers/fakes.dart';

/// Repositories against canned API responses: request shape and parsing.
void main() {
  late FakeHttpAdapter adapter;
  Dio dio((int, Object?) Function(RequestOptions o) handler) {
    adapter = FakeHttpAdapter(handler);
    return Dio(BaseOptions(baseUrl: 'http://api.test/v1'))..httpClientAdapter = adapter;
  }

  group('MoneyRepository', () {
    test('parses dues with their breakdown in paise', () async {
      final repo = MoneyRepository(dio((_) => (200, [
            {
              'id': 'd1',
              'type': 'RENT',
              'period': '2026-10',
              'amountPaise': 1500000,
              'breakdown': [
                {'label': 'Rent', 'amountPaise': 1400000},
                {'label': 'Parking', 'amountPaise': 100000},
              ],
              'dueDate': '2026-10-05T04:30:00.000Z',
              'overdue': true,
              'flatLabel': 'Tower-A, 101',
            },
          ])));
      final [due] = await repo.myDues();
      expect(due.type, DueType.rent);
      expect(due.periodMonth, DateTime(2026, 10));
      expect(due.breakdown.map((i) => i.amountPaise).reduce((a, b) => a + b), due.amountPaise);
      expect(due.overdue, isTrue);
    });

    test('creates an order for a due and reads the checkout, including the preferred method', () async {
      final repo = MoneyRepository(dio((o) => (201, {
            'paymentId': 'p1',
            'gateway': 'RAZORPAY',
            'keyId': 'rzp_test_abc',
            'orderId': 'order_1',
            'amountPaise': 250000,
            'currency': 'INR',
            'name': 'Sai Icon Co-operative Society',
            'description': 'Maintenance – October 2026',
            'prefill': {'name': 'Shruti', 'contact': '+919000000001', 'email': null, 'method': 'upi'},
          })));
      final checkout = await repo.createOrder('d1');
      expect(adapter.requests.single.data, {'dueId': 'd1'}); // the amount comes from the server only
      expect(checkout.isSimulated, isFalse);
      expect(checkout.prefillMethod, 'upi');
    });

    test('sends the gateway signature for verification', () async {
      final repo = MoneyRepository(dio((o) => (201, {
            'id': 'p1',
            'status': 'SUCCEEDED',
            'amountPaise': 250000,
            'method': 'upi',
            'gateway': 'RAZORPAY',
            'receiptNo': 'MNT/2026/10/0001',
            'paidAt': '2026-10-28T06:00:00.000Z',
            'transactionId': 'pay_1',
            'failureReason': null,
            'due': {'id': 'd1', 'type': 'MAINTENANCE', 'period': '2026-10', 'breakdown': []},
            'payerName': 'Shruti',
            'flatLabel': 'Tower-C, 502',
            'societyName': 'Sai Icon',
          })));
      final payment = await repo.verify(
        'p1',
        const CheckoutSucceeded(orderId: 'order_1', gatewayPaymentId: 'pay_1', signature: 'sig'),
      );
      expect(adapter.requests.single.data, {'paymentId': 'p1', 'orderId': 'order_1', 'gatewayPaymentId': 'pay_1', 'signature': 'sig'});
      expect(payment.status, PaymentStatus.succeeded);
      expect(payment.receiptNo, 'MNT/2026/10/0001');
    });

    test('turns API errors into ApiException codes', () async {
      final repo = MoneyRepository(dio((_) => (409, apiError('DUE_NOT_PENDING'))));
      expect(() => repo.createOrder('d1'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'DUE_NOT_PENDING')));
    });
  });

  test('CommunityRepository hides counts the server hides', () async {
    final repo = CommunityRepository(dio((_) => (200, [
          {
            'id': 'poll1',
            'question': 'Which activity for Sunday?',
            'closesAt': null,
            'isOpen': true,
            'createdAt': '2026-10-28T06:00:00.000Z',
            'totalVotes': 21,
            'myOptionId': null,
            'resultsVisible': false,
            'options': [
              {'id': 'o1', 'label': 'Movie Night', 'votes': null},
              {'id': 'o2', 'label': 'Karaoke', 'votes': null},
            ],
          },
        ])));
    final [poll] = await repo.polls();
    expect(poll.hasVoted, isFalse);
    expect(poll.options.every((o) => o.votes == null), isTrue);
    expect(poll.totalVotes, 21);
  });

  group('ProfileRepository', () {
    test('fills missing notification switches as on', () async {
      final repo = ProfileRepository(dio((_) => (200, {
            'notifications': {'announcements': false},
            'paymentMethod': 'netbanking',
          })));
      final prefs = await repo.preferences();
      expect(prefs.wants(NotificationPref.announcements), isFalse);
      expect(prefs.wants(NotificationPref.push), isTrue);
      expect(prefs.paymentMethod, PaymentMethodPref.netbanking);
    });

    test('adds a tenant with rent as the sum of the breakdown, no ID numbers', () async {
      final repo = ProfileRepository(dio((o) => (201, {
            'tenancy': {
              'id': 't1',
              'flatLabel': 'Tower-C, 502',
              'monthlyRentPaise': 1500000,
              'depositPaise': 6000000,
              'rentDueDay': 5,
              'rentBreakdown': [
                {'label': 'Rent', 'amountPaise': 1400000},
                {'label': 'Parking', 'amountPaise': 100000},
              ],
              'startDate': '2026-10-27T18:30:00.000Z',
              'endDate': null,
              'tenant': {'name': 'Shreyas', 'phone': '+919100000001', 'status': 'INVITED'},
              'owner': {'name': 'Shruti', 'phone': '+919000000001'},
            },
          })));
      final input = TenancyInput(
        rentBreakdown: const [
          BreakdownItem(label: 'Rent', amountPaise: 1400000),
          BreakdownItem(label: 'Parking', amountPaise: 100000),
        ],
        depositPaise: 6000000,
        rentDueDay: 5,
        startDate: DateTime(2026, 10, 28),
        tenantName: 'Shreyas',
        tenantPhone: '+919100000001',
      );
      final tenancy = await repo.addTenant(input);
      final body = adapter.requests.single.data as Map<String, Object?>;
      expect(body.keys, isNot(contains('aadhaar')));
      expect(body.keys, isNot(contains('password')));
      expect(input.monthlyRentPaise, 1500000);
      expect(tenancy.tenantStatus, TenantStatus.invited);
      expect(tenancy.endDate, isNull);
    });

    test('a missing tenancy is null, not an error', () async {
      final repo = ProfileRepository(dio((_) => (200, {'tenancy': null})));
      expect(await repo.tenancy(), isNull);
    });
  });

  test('NotificationsRepository parses read state and string data', () async {
    final repo = NotificationsRepository(dio((_) => (200, [
          {
            'id': 'n1',
            'type': 'payment',
            'title': 'Payment received',
            'body': '₹2,500 for maintenance.',
            'data': {'paymentId': 'p1'},
            'read': false,
            'createdAt': '2026-10-28T06:00:00.000Z',
          },
        ])));
    final [n] = await repo.list();
    expect(n.read, isFalse);
    expect(n.data, {'paymentId': 'p1'});
    expect(n.markedRead().read, isTrue);
  });
}
