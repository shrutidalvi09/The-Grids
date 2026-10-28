import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:the_grids/core/router/app_router.dart';
import 'package:the_grids/core/router/routes.dart';
import 'package:the_grids/features/auth/domain/user_role.dart';
import 'package:the_grids/features/auth/presentation/session_controller.dart';
import 'package:the_grids/features/profile/domain/profile_models.dart';

import '../helpers/fakes.dart';
import '../helpers/profile_fakes.dart';
import '../helpers/pump_app.dart';

Finder _appBarTitle(String text) => find.descendant(of: find.byType(AppBar), matching: find.text(text));

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  Future<(FakeProfileRepository, dynamic)> open(
    WidgetTester tester,
    UserRole role,
    String route, {
    FakeProfileRepository? profile,
    FakeAuthRepository? auth,
    FakeNotificationsRepository? notifications,
  }) async {
    final repo = profile ?? FakeProfileRepository();
    final container = await pumpGridsApp(tester, profile: repo, auth: auth, notifications: notifications);
    await signInAs(tester, container, role);
    repo.session = container.read(currentSessionProvider);
    container.read(routerProvider).go(route);
    await tester.pumpAndSettle();
    return (repo, container);
  }

  group('Profile menu', () {
    testWidgets('owners get household, payments and Tenant Info', (tester) async {
      await open(tester, UserRole.owner, AppRoutes.profile);
      expect(find.text('Role: Owner', findRichText: true), findsOneWidget);
      for (final item in ['Household Members', 'Services', 'Payment Settings', 'Notification Preferences']) {
        expect(find.text(item), findsOneWidget, reason: item);
      }
      await _scrollTo(tester, find.text('Tenant Info'));
      expect(find.text('Owner & Lease'), findsNothing);
    });

    testWidgets('admins have no flat-only items', (tester) async {
      await open(tester, UserRole.admin, AppRoutes.profile);
      expect(find.text('Role: Admin', findRichText: true), findsOneWidget);
      expect(find.text('Household Members'), findsNothing);
      expect(find.text('Payment Settings'), findsNothing);
      await _scrollTo(tester, find.text('Theme'));
      expect(find.text('Tenant Info'), findsNothing);
    });
  });

  testWidgets('editing the profile updates the card', (tester) async {
    final (repo, _) = await open(tester, UserRole.owner, AppRoutes.profile);
    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email (optional)'), 'not-an-email');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Shruti Dalvi');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email (optional)'), 'shruti@example.com');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.profileUpdates.single, containsPair('email', 'shruti@example.com'));
    expect(find.text('Shruti Dalvi'), findsOneWidget);
    expect(find.text('Email: shruti@example.com', findRichText: true), findsOneWidget);
  });

  testWidgets('notification preferences save with "Save Preferences"', (tester) async {
    final (repo, _) = await open(tester, UserRole.tenant, AppRoutes.notificationSettings);
    expect(_appBarTitle('Notification Preferences'), findsOneWidget);
    await tester.tap(find.text('Announcements & polls'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Save Preferences'));
    await tester.tap(find.text('Save Preferences'));
    await tester.pumpAndSettle();

    expect(repo.savedPrefs.single.wants(NotificationPref.announcements), isFalse);
    expect(repo.savedPrefs.single.wants(NotificationPref.paymentReminder), isTrue);
    expect(find.text('Preferences saved successfully'), findsOneWidget);
  });

  testWidgets('payment settings store a preferred method only', (tester) async {
    final (repo, _) = await open(tester, UserRole.owner, AppRoutes.paymentSettings);
    expect(find.textContaining('kept securely by Razorpay'), findsOneWidget);
    await tester.tap(find.text('Debit / Credit card'));
    await tester.pumpAndSettle();
    expect(repo.prefs.paymentMethod, PaymentMethodPref.card);
    expect(find.text('Payment preference saved'), findsOneWidget);
  });

  testWidgets('household members can be added', (tester) async {
    final (repo, _) = await open(tester, UserRole.owner, AppRoutes.household);
    expect(find.text('Chetan Dalvi'), findsOneWidget);
    expect(find.byTooltip('Call Chetan Dalvi'), findsOneWidget);

    await tester.tap(find.text('Add Member'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Pragati Dalvi');
    await tester.enterText(find.widgetWithText(TextFormField, 'Relation'), 'Mother');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mobile number (optional)'), '12345');
    await tester.tap(find.widgetWithText(FilledButton, 'Add Member'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Mobile number (optional)'), '');
    await tester.tap(find.widgetWithText(FilledButton, 'Add Member'));
    await tester.pumpAndSettle();
    expect(repo.members.last.name, 'Pragati Dalvi');
    expect(find.text('Member added'), findsOneWidget);
  });

  testWidgets('services are grouped by category with call buttons', (tester) async {
    await open(tester, UserRole.tenant, AppRoutes.services);
    expect(find.bySemanticsLabel('Maid, 2 contacts'), findsOneWidget);
    expect(find.text('Plumber'), findsOneWidget);
    expect(find.text('Add Service'), findsNothing);

    await tester.tap(find.text('Maid'));
    await tester.pumpAndSettle();
    expect(_appBarTitle('Maid'), findsOneWidget);
    expect(find.text('Akshara More'), findsOneWidget);
    expect(find.text('Raju Plumbing Works'), findsNothing);
    expect(find.byTooltip('Call Akshara More'), findsOneWidget);
  });

  group('Tenant info', () {
    testWidgets('owners add a tenant by mobile and can end the tenancy', (tester) async {
      final (repo, _) = await open(tester, UserRole.owner, AppRoutes.tenantInfo);
      expect(find.text('No tenant yet'), findsOneWidget);
      expect(find.textContaining('Aadhaar'), findsOneWidget); // "no passwords or Aadhaar needed"
      await tester.tap(find.text('Add Tenant'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Password'), findsNothing);

      await tester.enterText(find.widgetWithText(TextFormField, "Tenant's name"), 'Shreyas Kulkarni');
      await tester.enterText(find.widgetWithText(TextFormField, 'Mobile number'), '91000 00001');
      await tester.enterText(find.widgetWithText(TextFormField, 'Item'), 'Rent');
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '14000');
      await tester.tap(find.text('Add item'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Item').last, 'Parking');
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount').last, '1000');
      await tester.pumpAndSettle();
      expect(find.text('₹15,000'), findsOneWidget); // live monthly rent
      await _scrollTo(tester, find.widgetWithText(TextFormField, 'Security deposit'));
      await tester.enterText(find.widgetWithText(TextFormField, 'Security deposit'), '60000');
      await _scrollTo(tester, find.widgetWithText(FilledButton, 'Add Tenant'));
      await tester.tap(find.widgetWithText(FilledButton, 'Add Tenant'));
      await tester.pumpAndSettle();

      final input = repo.addedTenancies.single;
      expect(input.tenantPhone, '+919100000001');
      expect(input.monthlyRentPaise, 1500000);
      expect(input.depositPaise, 6000000);
      expect(find.text("Hasn't signed in yet"), findsOneWidget);
      await tester.pump(const Duration(seconds: 5)); // let the snack bar go
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('End tenancy'));
      await tester.tap(find.text('End tenancy'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'End tenancy'));
      await tester.pumpAndSettle();
      expect(repo.endedTenancies, ['t1']);
      expect(find.text('No tenant yet'), findsOneWidget);
    });

    testWidgets("tenants see their owner's contact and lease", (tester) async {
      final repo = FakeProfileRepository()..currentTenancy = sampleTenancy();
      await open(tester, UserRole.tenant, AppRoutes.leaseInfo, profile: repo);
      expect(_appBarTitle('Owner & Lease'), findsOneWidget);
      expect(find.text('Shruti Chetan Dalvi'), findsOneWidget);
      expect(find.byTooltip('Call Shruti Chetan Dalvi'), findsOneWidget);
      expect(find.text('₹15,000'), findsWidgets);
    });
  });

  group('Account', () {
    testWidgets("the society's last admin can't delete their account", (tester) async {
      final repo = FakeProfileRepository()..deleteError = lastAdminError;
      await open(tester, UserRole.admin, AppRoutes.account, profile: repo);
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete my account'));
      await tester.pumpAndSettle();
      expect(find.textContaining('only admin of this society'), findsOneWidget);
    });

    testWidgets('deleting the account signs out', (tester) async {
      final auth = FakeAuthRepository();
      final (repo, _) = await open(tester, UserRole.tenant, AppRoutes.account, auth: auth);
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();
      expect(find.textContaining('This can'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete my account'));
      await tester.pumpAndSettle();
      expect(repo.deleted, isTrue);
      expect(auth.signedOut, isTrue);
      expect(find.text('Select your society'), findsOneWidget);
    });
  });

  testWidgets('notifications show unread state and open the related screen', (tester) async {
    final notifications = FakeNotificationsRepository();
    await open(tester, UserRole.owner, AppRoutes.home, notifications: notifications);
    expect(find.byTooltip('1 unread notification'), findsOneWidget);

    await tester.tap(find.byTooltip('1 unread notification'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('Unread')), findsOneWidget);
    expect(find.byTooltip('Mark all as read'), findsOneWidget);

    await tester.tap(find.text('New poll'));
    await tester.pumpAndSettle();
    expect(notifications.readIds, ['n1']);
    expect(_appBarTitle('Polls'), findsOneWidget);
  });

  testWidgets('Help lists FAQs and the society office', (tester) async {
    await open(tester, UserRole.tenant, AppRoutes.help);
    expect(find.text('Frequently asked questions'), findsOneWidget);
    await tester.tap(find.text('How do I pay maintenance or rent?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('UPI (Google Pay, PhonePe)'), findsOneWidget);
    await _scrollTo(tester, find.byTooltip('Call Shruti Chetan Dalvi'));
  });

  testWidgets('About states the privacy promises', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'The Grids',
      packageName: 'com.thegrids.the_grids',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await open(tester, UserRole.tenant, AppRoutes.about);
    expect(find.text('Version 0.1.0 (1)'), findsOneWidget);
    expect(find.text('We never ask for your Aadhaar number.'), findsOneWidget);
    expect(find.textContaining('no passwords'), findsOneWidget);
  });
}
