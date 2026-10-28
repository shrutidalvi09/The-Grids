import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_grids/core/storage/preferences.dart';
import 'package:the_grids/features/auth/domain/user_role.dart';
import 'package:the_grids/features/notifications/presentation/unread_count_provider.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

/// The page title lives in the AppBar; tab labels live in the bottom nav.
Finder _appBarTitle(String text) => find.descendant(of: find.byType(AppBar), matching: find.text(text));

void main() {
  testWidgets('signed-out users land on society selection', (tester) async {
    await pumpGridsApp(tester);
    expect(find.text('Select your society'), findsOneWidget);
  });

  testWidgets('every tab shows its own title (owner)', (tester) async {
    final container = await pumpGridsApp(tester);
    await signInAs(tester, container, UserRole.owner);

    expect(_appBarTitle('Home'), findsOneWidget);
    for (final title in ['Tower', 'Maintenance', 'Community', 'Profile', 'Home']) {
      await tester.tap(find.bySemanticsLabel(title));
      await tester.pumpAndSettle();
      expect(_appBarTitle(title), findsOneWidget, reason: title);
    }
  });

  testWidgets('tenants get a Rent tab instead of Maintenance', (tester) async {
    final container = await pumpGridsApp(tester);
    await signInAs(tester, container, UserRole.tenant);

    expect(find.bySemanticsLabel('Maintenance'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Rent'));
    await tester.pumpAndSettle();
    expect(_appBarTitle('Rent'), findsOneWidget);
  });

  testWidgets('profile shows the correct role and phone', (tester) async {
    final container = await pumpGridsApp(tester);
    await signInAs(tester, container, UserRole.tenant);

    await tester.tap(find.bySemanticsLabel('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Role: Tenant'), findsOneWidget);
    expect(find.text('Role: Owner'), findsNothing);
    expect(find.text('+919000000001'), findsOneWidget);
  });

  testWidgets('hamburger opens the drawer; logout signs out and returns to sign-in', (tester) async {
    final auth = FakeAuthRepository();
    final container = await pumpGridsApp(tester, auth: auth);
    await signInAs(tester, container, UserRole.admin);

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    expect(find.text('Facility Bookings'), findsOneWidget);

    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    expect(auth.signedOut, isTrue);
    expect(find.text('Select your society'), findsOneWidget);
  });

  testWidgets('bell shows an unread badge and opens Notifications', (tester) async {
    final container = await pumpGridsApp(
      tester,
      overrides: [unreadNotificationCountProvider.overrideWithValue(3)],
    );
    await signInAs(tester, container, UserRole.owner);

    expect(find.byTooltip('3 unread notifications'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byTooltip('3 unread notifications'));
    await tester.pumpAndSettle();
    expect(_appBarTitle('Notifications'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('choosing Hindi relabels the shell and is remembered', (tester) async {
    final container = await pumpGridsApp(tester);
    await signInAs(tester, container, UserRole.tenant);

    await tester.tap(find.bySemanticsLabel('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('हिन्दी'), 200);
    await tester.tap(find.text('हिन्दी'));
    await tester.pumpAndSettle();

    expect(_appBarTitle('प्रोफ़ाइल'), findsOneWidget);
    expect(find.bySemanticsLabel('किराया'), findsOneWidget);
    expect(container.read(sharedPreferencesProvider).getString(PrefKeys.languageCode), 'hi');
  });

  testWidgets('choosing Dark switches the theme and is remembered', (tester) async {
    final container = await pumpGridsApp(tester);
    await signInAs(tester, container, UserRole.owner);

    await tester.tap(find.bySemanticsLabel('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold).last);
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(container.read(sharedPreferencesProvider).getString(PrefKeys.themeMode), 'dark');
  });

  testWidgets('saved theme and language are restored on launch', (tester) async {
    final container = await pumpGridsApp(
      tester,
      prefs: {PrefKeys.themeMode: 'dark', PrefKeys.languageCode: 'ta'},
    );
    await signInAs(tester, container, UserRole.owner);

    expect(_appBarTitle('முகப்பு'), findsOneWidget);
    final context = tester.element(find.byType(Scaffold).last);
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  testWidgets('nav items meet the 48dp minimum tap target', (tester) async {
    final container = await pumpGridsApp(tester);
    await signInAs(tester, container, UserRole.owner);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });
}
