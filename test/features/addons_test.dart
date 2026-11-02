import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_grids/core/router/app_router.dart';
import 'package:the_grids/core/router/routes.dart';
import 'package:the_grids/features/auth/domain/user_role.dart';
import 'package:the_grids/features/tower/domain/tower_models.dart';

import '../helpers/feature_fakes.dart';
import '../helpers/profile_fakes.dart';
import '../helpers/pump_app.dart';

Finder _appBarTitle(String text) => find.descendant(of: find.byType(AppBar), matching: find.text(text));

void main() {
  group('Visitors', () {
    testWidgets('residents pre-approve a visitor for their flat', (tester) async {
      final tower = FakeTowerRepository();
      final container = await pumpGridsApp(tester, tower: tower);
      await signInAs(tester, container, UserRole.owner);
      container.read(routerProvider).go(AppRoutes.towerVisitors);
      await tester.pumpAndSettle();

      expect(find.textContaining('Expected'), findsWidgets); // Kabir, pre-approved for tonight
      await tester.tap(find.text('Add Visitor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delivery'));
      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Flipkart');
      await tester.enterText(find.widgetWithText(TextFormField, 'Purpose (optional)'), 'Parcel');
      expect(find.widgetWithText(DropdownButtonFormField<String>, 'Flat'), findsNothing); // own flat only
      await tester.tap(find.widgetWithText(FilledButton, 'Add Visitor'));
      await tester.pumpAndSettle();

      final added = tower.addedVisitors.single;
      expect(added.name, 'Flipkart');
      expect(added.type, VisitorType.delivery);
      expect(added.flatId, isNull);
      expect(find.text('Visitor added. The gate will let them in.'), findsOneWidget);
    });

    testWidgets('residents cancel an expected visitor; admins check people in', (tester) async {
      final tower = FakeTowerRepository();
      final container = await pumpGridsApp(tester, tower: tower);
      await signInAs(tester, container, UserRole.tenant);
      container.read(routerProvider).go(AppRoutes.towerVisitors);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kabir'));
      await tester.pumpAndSettle();
      expect(find.text('Check in'), findsNothing); // only the gate can
      await tester.tap(find.text('Cancel visitor'));
      await tester.pumpAndSettle();
      expect(tower.cancelledVisitors, ['v3']);

      await signInAs(tester, container, UserRole.admin);
      container.read(routerProvider).go(AppRoutes.towerVisitors);
      await tester.pumpAndSettle();
      expect(find.text('Log Visitor'), findsOneWidget);
      await tester.tap(find.text('Amazon (Parcel)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check in'));
      await tester.pumpAndSettle();
      expect(tower.gateChanges, [('v2', GateStatus.checkedIn)]);
    });
  });

  testWidgets('admins add an event; residents only see events', (tester) async {
    final tower = FakeTowerRepository();
    final container = await pumpGridsApp(tester, tower: tower);
    await signInAs(tester, container, UserRole.owner);
    container.read(routerProvider).go(AppRoutes.events);
    await tester.pumpAndSettle();
    expect(find.text('Add Event'), findsNothing);
    expect(find.byTooltip('Event options'), findsNothing);

    await signInAs(tester, container, UserRole.admin);
    container.read(routerProvider).go(AppRoutes.events);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Event'));
    await tester.pumpAndSettle();
    expect(_appBarTitle('Add Event'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Diwali Mela');
    await tester.enterText(find.widgetWithText(TextFormField, 'Venue'), 'Clubhouse Lawn');
    await tester.scrollUntilVisible(find.text('Save'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final event = tower.createdEvents.single;
    expect(event.title, 'Diwali Mela');
    expect(event.startsAt.isAfter(DateTime.now()), isTrue);
    expect(_appBarTitle('Events'), findsOneWidget);
  });

  group('Manage residents', () {
    testWidgets('admins invite a resident to a flat', (tester) async {
      final profile = FakeProfileRepository();
      final container = await pumpGridsApp(tester, profile: profile);
      await signInAs(tester, container, UserRole.admin);
      container.read(routerProvider).go(AppRoutes.profile);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage Residents'));
      await tester.pumpAndSettle();

      expect(find.text('Nikhil Joshi'), findsOneWidget);
      expect(find.text('Invited'), findsOneWidget);
      await tester.tap(find.text('Invite'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tenant'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Flat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tower-A, 103 · vacant').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Neha Shah');
      await tester.enterText(find.widgetWithText(TextFormField, 'Mobile number'), '98111 22222');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(profile.invites.single, ('Neha Shah', '+919811122222', UserRole.tenant, 'fa3'));
      expect(find.text('Neha Shah can now sign in'), findsOneWidget);
    });

    testWidgets('admins remove a member after confirming', (tester) async {
      final profile = FakeProfileRepository();
      final container = await pumpGridsApp(tester, profile: profile);
      await signInAs(tester, container, UserRole.admin);
      container.read(routerProvider).go(AppRoutes.residents);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Member options').at(1)); // Riya
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove access'));
      await tester.pumpAndSettle();
      expect(find.textContaining('signed out'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(profile.removedMembers, ['m2']);
      expect(find.text('Riya Mehta'), findsNothing);
    });
  });

  testWidgets('residents rate a service provider', (tester) async {
    final profile = FakeProfileRepository();
    final container = await pumpGridsApp(tester, profile: profile);
    await signInAs(tester, container, UserRole.tenant);
    container.read(routerProvider).go(AppRoutes.serviceCategory('Maid'));
    await tester.pumpAndSettle();

    // Akshara (4.5, rated by others) comes first; Pooja hasn't been rated yet.
    await tester.tap(find.text('Rate').at(1));
    await tester.pumpAndSettle();
    expect(find.text('Submit rating'), findsOneWidget);
    await tester.tap(find.byTooltip('4 stars'));
    await tester.pump();
    await tester.tap(find.text('Submit rating'));
    await tester.pumpAndSettle();

    expect(profile.ratings, [('s2', 4)]);
    expect(find.text('Thanks for rating!'), findsOneWidget);
    expect(find.text('You gave 4 stars'), findsOneWidget);
  });
}
