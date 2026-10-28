import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_grids/core/network/api_exception.dart';
import 'package:the_grids/core/router/app_router.dart';
import 'package:the_grids/core/router/routes.dart';
import 'package:the_grids/features/auth/domain/user_role.dart';
import 'package:the_grids/features/maintenance/domain/money_models.dart';

import '../helpers/money_fakes.dart';
import '../helpers/pump_app.dart';

Finder _appBarTitle(String text) => find.descendant(of: find.byType(AppBar), matching: find.text(text));

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  group('Maintenance tab', () {
    testWidgets('owners see the pending due, its breakdown and payment history', (tester) async {
      final money = FakeMoneyRepository()..payments = [samplePayment(id: 'old')];
      final container = await pumpGridsApp(tester, money: money);
      await signInAs(tester, container, UserRole.owner);
      container.read(routerProvider).go(AppRoutes.maintenance);
      await tester.pumpAndSettle();

      expect(_appBarTitle('Maintenance'), findsOneWidget);
      expect(find.text('Maintenance Due'), findsOneWidget);
      expect(find.text('₹2,500'), findsWidgets);
      expect(find.text('Pay Now'), findsOneWidget);
      expect(find.text('Sinking Fund'), findsOneWidget);
      await _scrollTo(tester, find.text('Payment History'));
      expect(find.textContaining('Paid on'), findsOneWidget);
    });

    testWidgets('tenants see their rent', (tester) async {
      final money = FakeMoneyRepository()..dues = [sampleDue(type: DueType.rent, overdue: true)];
      final container = await pumpGridsApp(tester, money: money);
      await signInAs(tester, container, UserRole.tenant);
      container.read(routerProvider).go(AppRoutes.maintenance);
      await tester.pumpAndSettle();

      expect(_appBarTitle('Rent'), findsOneWidget);
      expect(find.text('Rent Due'), findsOneWidget);
      expect(find.text('₹15,000'), findsWidgets);
      expect(find.textContaining('Overdue since'), findsOneWidget);
    });

    testWidgets('admins see collection status, the charge breakdown and society bills', (tester) async {
      final container = await pumpGridsApp(tester);
      await signInAs(tester, container, UserRole.admin);
      container.read(routerProvider).go(AppRoutes.maintenance);
      await tester.pumpAndSettle();

      expect(find.text('7 flats have pending dues'), findsOneWidget);
      expect(find.textContaining('₹17,500'), findsOneWidget);
      expect(find.text('Pay Now'), findsNothing);
      await _scrollTo(tester, find.text('MSEDCL Electricity'));
      expect(find.text('Update Maintenance'), findsOneWidget);
    });
  });

  group('Paying a due', () {
    Future<(FakeMoneyRepository, FakeCheckoutLauncher)> openPay(WidgetTester tester) async {
      final money = FakeMoneyRepository();
      final checkout = FakeCheckoutLauncher();
      final container = await pumpGridsApp(tester, money: money, checkout: checkout);
      await signInAs(tester, container, UserRole.owner);
      container.read(routerProvider).go(AppRoutes.maintenance);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pay Now'));
      await tester.pumpAndSettle();
      expect(find.text('Pay ₹2,500'), findsOneWidget);
      return (money, checkout);
    }

    testWidgets('success is verified by the server and shows the receipt', (tester) async {
      final (money, checkout) = await openPay(tester);
      await tester.tap(find.text('Pay ₹2,500'));
      await tester.pumpAndSettle();

      expect(checkout.opened.single.amountPaise, 250000);
      expect(money.verified, ['pay-1']);
      expect(_appBarTitle('Receipt'), findsOneWidget);
      expect(find.text('MNT/2026/10/0007'), findsOneWidget);
      await _scrollTo(tester, find.text('Download PDF'));

      // Back on the tab, the due is gone and the payment is in the history.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text("You're all paid up"), findsOneWidget);
      expect(find.text('Pay Now'), findsNothing);
    });

    testWidgets('cancelling keeps the due payable', (tester) async {
      final (money, checkout) = await openPay(tester);
      checkout.result = const CheckoutCancelled();
      await tester.tap(find.text('Pay ₹2,500'));
      await tester.pumpAndSettle();

      expect(find.text('Payment cancelled'), findsOneWidget);
      expect(find.text('Pay ₹2,500'), findsOneWidget);
      expect(money.verified, isEmpty);
    });

    testWidgets('a failed payment can be retried', (tester) async {
      final (money, checkout) = await openPay(tester);
      checkout.result = const CheckoutFailed('Bank declined');
      await tester.tap(find.text('Pay ₹2,500'));
      await tester.pumpAndSettle();

      expect(find.text('Payment failed'), findsOneWidget);
      expect(money.verified, isEmpty);

      checkout.result = const CheckoutSucceeded(orderId: 'o', gatewayPaymentId: 'pay_X', signature: 's');
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(_appBarTitle('Receipt'), findsOneWidget);
    });

    testWidgets('a rejected signature is shown as a failure', (tester) async {
      final (money, _) = await openPay(tester);
      money.verifyError = const ApiException(code: 'PAYMENT_VERIFICATION_FAILED', message: 'bad signature');
      await tester.tap(find.text('Pay ₹2,500'));
      await tester.pumpAndSettle();

      expect(find.text('Payment failed'), findsOneWidget);
      expect(find.textContaining("couldn't verify"), findsOneWidget);
    });

    testWidgets('if verification is interrupted, the user can check the status later', (tester) async {
      final (money, _) = await openPay(tester);
      money.verifyError = const ApiException(code: ApiException.network, message: 'offline');
      await tester.tap(find.text('Pay ₹2,500'));
      await tester.pumpAndSettle();

      expect(find.text('Payment pending'), findsOneWidget);
      await tester.tap(find.text('Check status'));
      await tester.pumpAndSettle();
      expect(find.text('Payment pending'), findsOneWidget); // still waiting on the bank

      money.pendingLookup = PaymentStatus.succeeded; // webhook arrived
      await tester.tap(find.text('Check status'));
      await tester.pumpAndSettle();
      expect(_appBarTitle('Receipt'), findsOneWidget);
    });

    testWidgets('a due paid elsewhere is reported and the tab refreshed', (tester) async {
      final (money, checkout) = await openPay(tester);
      money.createOrderError = const ApiException(code: 'DUE_NOT_PENDING', message: 'paid');
      money.dues = [];
      await tester.tap(find.text('Pay ₹2,500'));
      await tester.pumpAndSettle();

      expect(checkout.opened, isEmpty);
      expect(find.text('This due has already been paid.'), findsOneWidget);
      expect(find.text("You're all paid up"), findsOneWidget);
    });
  });

  group('Receipt', () {
    testWidgets('downloads and shares the PDF', (tester) async {
      final money = FakeMoneyRepository()..payments = [samplePayment()];
      final receipts = FakeReceiptFiles()..hasViewer = false;
      final container = await pumpGridsApp(tester, money: money, receipts: receipts);
      await signInAs(tester, container, UserRole.owner);
      container.read(routerProvider).go(AppRoutes.receipt('p1'));
      await tester.pumpAndSettle();

      expect(find.text('Sai Icon Co-operative Society'), findsOneWidget);
      expect(find.text('UPI'), findsOneWidget);
      await _scrollTo(tester, find.text('Download PDF'));
      await tester.tap(find.text('Download PDF'));
      await tester.pumpAndSettle();
      expect(receipts.downloaded, ['p1']);
      expect(find.textContaining('Install a PDF viewer'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5)); // let the snack bar go
      await tester.pumpAndSettle();

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(receipts.shared.single, ('p1', 'Receipt MNT/2026/10/0007 from Sai Icon Co-operative Society'));
    });
  });

  group('Admin money screens', () {
    testWidgets('remind a defaulter once', (tester) async {
      final money = FakeMoneyRepository();
      final container = await pumpGridsApp(tester, money: money);
      await signInAs(tester, container, UserRole.admin);
      container.read(routerProvider).go(AppRoutes.maintenance);
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 flats have pending dues'));
      await tester.pumpAndSettle();

      expect(_appBarTitle('Pending Dues'), findsOneWidget);
      expect(find.text('Tower-B, 204'), findsOneWidget);
      expect(find.text('2 months due'), findsOneWidget);
      await tester.tap(find.text('Remind'));
      await tester.pumpAndSettle();
      expect(money.reminded, ['flat1']);
      expect(find.text('Reminder sent to Tower-B, 204'), findsOneWidget);
      expect(find.text('Reminded'), findsOneWidget);
      expect(find.text('Remind'), findsNothing);
    });

    testWidgets('update the maintenance items with a live total', (tester) async {
      final money = FakeMoneyRepository();
      final container = await pumpGridsApp(tester, money: money);
      await signInAs(tester, container, UserRole.admin);
      container.read(routerProvider).go(AppRoutes.maintenance);
      await tester.pumpAndSettle();
      container.read(routerProvider).go(AppRoutes.maintenanceConfig);
      await tester.pumpAndSettle();

      expect(find.text('₹2,500'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, '500').first, '700');
      await tester.pumpAndSettle();
      expect(find.text('₹2,700'), findsOneWidget);

      await _scrollTo(tester, find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final (items, dueDay) = money.savedConfigs.single;
      expect(items.first, isA<BreakdownItem>().having((i) => i.amountPaise, 'amountPaise', 70000));
      expect(dueDay, 10);
      expect(find.text('Maintenance updated'), findsOneWidget);
    });

    testWidgets('mark a society bill as paid', (tester) async {
      final money = FakeMoneyRepository();
      final container = await pumpGridsApp(tester, money: money);
      await signInAs(tester, container, UserRole.admin);
      container.read(routerProvider).go(AppRoutes.maintenance);
      await tester.pumpAndSettle();
      container.read(routerProvider).go(AppRoutes.societyBills);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Mark as paid'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Mark MSEDCL Electricity bill of ₹45,200 as paid?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Mark as paid'));
      await tester.pumpAndSettle();

      expect(money.paidBills, ['b1']);
      expect(find.text('No bills here'), findsOneWidget);
      await tester.tap(find.text('Paid'));
      await tester.pumpAndSettle();
      expect(find.text('MSEDCL Electricity'), findsOneWidget);
    });
  });
}
