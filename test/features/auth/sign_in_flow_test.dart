import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_grids/core/config/app_config.dart';
import 'package:the_grids/core/network/api_exception.dart';
import 'package:the_grids/features/auth/domain/session.dart';
import 'package:the_grids/features/auth/domain/user_role.dart';
import 'package:the_grids/features/auth/presentation/session_controller.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

Finder _appBarTitle(String text) => find.descendant(of: find.byType(AppBar), matching: find.text(text));

/// Society → role → phone, leaving the test on the OTP screen.
Future<void> _goToOtp(WidgetTester tester, {String phone = '9000000001', String role = 'Member (Owner) Login'}) async {
  await tester.tap(find.text('Sai Icon Co-operative Society'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(role));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField), phone);
  await tester.tap(find.text('Send Code'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('society → role → phone → OTP signs in and opens Home', (tester) async {
    final auth = FakeAuthRepository();
    await pumpGridsApp(tester, auth: auth);

    // Step 1: search and pick a society.
    expect(find.text('Select your society'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'nothing like this');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('No society found'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'sai');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sai Icon Co-operative Society'));
    await tester.pumpAndSettle();

    // Step 2: role buttons, with the chosen society shown.
    expect(find.text('Sai Icon Co-operative Society'), findsOneWidget);
    expect(find.text('Admin Login'), findsOneWidget);
    expect(find.text('Tenant Login'), findsOneWidget);
    await tester.tap(find.text('Member (Owner) Login'));
    await tester.pumpAndSettle();

    // Step 3: phone number with validation.
    expect(find.text('MEMBER (OWNER) LOGIN'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '12345');
    await tester.tap(find.text('Send Code'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);
    expect(auth.otpRequests, 0);

    await tester.enterText(find.byType(TextFormField), '9000000001');
    await tester.tap(find.text('Send Code'));
    await tester.pumpAndSettle();

    // Step 4: code entry. Production builds never show the dev code.
    expect(find.text('Enter the 6-digit code sent to +91 90000 00001'), findsOneWidget);
    expect(find.textContaining('Dev build'), findsNothing);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();

    expect(_appBarTitle('Home'), findsOneWidget);
  });

  testWidgets('an unregistered number shows "Not registered" and stays on the phone step', (tester) async {
    await pumpGridsApp(tester);
    await _goToOtp(tester, phone: '9876543210');

    expect(find.text('Not registered – contact your society admin'), findsOneWidget);
    expect(find.text('Send Code'), findsOneWidget);
  });

  testWidgets('a wrong code shows attempts left and clears the boxes', (tester) async {
    await pumpGridsApp(tester);
    await _goToOtp(tester);

    await tester.enterText(find.byType(TextField), '000000');
    await tester.pumpAndSettle();
    expect(find.text('Incorrect code. 4 attempts left.'), findsOneWidget);
    expect(find.text('0'), findsNothing); // boxes cleared

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();
    expect(_appBarTitle('Home'), findsOneWidget);
  });

  testWidgets('resend unlocks after 30 seconds and sends a new code', (tester) async {
    final auth = FakeAuthRepository();
    await pumpGridsApp(tester, auth: auth);
    await _goToOtp(tester);

    expect(find.text('Resend in 30s'), findsOneWidget);
    expect(find.text('Resend code'), findsNothing);
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Resend in 20s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Resend code'));
    await tester.pumpAndSettle();
    expect(auth.otpRequests, 2);
    expect(find.text('Resend in 30s'), findsOneWidget);
  });

  testWidgets('dev builds show the echoed code with a one-tap "Use code"', (tester) async {
    final auth = FakeAuthRepository()..devCode = '123456';
    await pumpGridsApp(tester, auth: auth, flavor: Flavor.dev);
    await _goToOtp(tester);

    expect(find.text('Dev build: your code is 123456'), findsOneWidget);
    await tester.tap(find.text('Use code'));
    await tester.pumpAndSettle();
    expect(_appBarTitle('Home'), findsOneWidget);
  });

  group('session restore at launch', () {
    testWidgets('a saved session opens straight into Home', (tester) async {
      await pumpGridsApp(tester, auth: FakeAuthRepository(savedSession: fakeSession(UserRole.tenant)));
      expect(find.bySemanticsLabel('Rent'), findsOneWidget);
      expect(_appBarTitle('Home'), findsOneWidget);
    });

    testWidgets('offline: splash offers a retry and keeps the session', (tester) async {
      final auth = FakeAuthRepository()
        ..restoreError = const ApiException(code: ApiException.network, message: 'offline');
      await pumpGridsApp(tester, auth: auth);

      expect(find.text("Can't reach the server. Check your internet connection."), findsOneWidget);

      auth
        ..restoreError = null
        ..savedSession = fakeSession(UserRole.owner);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(_appBarTitle('Home'), findsOneWidget);
    });
  });

  testWidgets('when the server ends the session the user sees why', (tester) async {
    final container = await pumpGridsApp(tester);
    await signInAs(tester, container, UserRole.owner);

    container.read(sessionControllerProvider.notifier).expire();
    await tester.pumpAndSettle();
    expect(find.text('Your session has expired. Please sign in again.'), findsOneWidget);
  });

  testWidgets('the drawer switches between the user\'s memberships', (tester) async {
    final both = [membership(UserRole.admin), membership(UserRole.owner)];
    final session = fakeSession(UserRole.admin, memberships: both);
    final auth = FakeAuthRepository(savedSession: session);
    final container = await pumpGridsApp(tester, auth: auth);

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Switch society'));
    await tester.pumpAndSettle();

    expect(find.text('Switch society or role'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
    await tester.tap(find.text('Owner · Sai Icon Co-operative Society'));
    await tester.pumpAndSettle();

    expect(auth.switchedTo, ['m-owner']);
    final state = container.read(sessionControllerProvider) as SignedIn;
    expect(state.session.role, UserRole.owner);
  });
}
