import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_grids/core/router/app_router.dart';
import 'package:the_grids/core/router/routes.dart';
import 'package:the_grids/features/auth/domain/user_role.dart';
import 'package:the_grids/features/home/domain/home_models.dart';
import 'package:the_grids/features/tower/domain/tower_models.dart';

import '../helpers/feature_fakes.dart';
import '../helpers/pump_app.dart';

Finder _appBarTitle(String text) => find.descendant(of: find.byType(AppBar), matching: find.text(text));

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  group('Home', () {
    testWidgets('admins see the alert, society statistics and recent complaints', (tester) async {
      final container = await pumpGridsApp(tester);
      await signInAs(tester, container, UserRole.admin);

      expect(find.textContaining('Good '), findsOneWidget);
      expect(find.text('30°C'), findsOneWidget);
      expect(find.text('Water supply interruption'), findsOneWidget);
      for (final (label, value) in [('Towers', '3'), ('Apartments', '30'), ('Owners', '20'), ('Tenants', '4'), ('Dues', '10')]) {
        expect(find.bySemanticsLabel('$label: $value'), findsOneWidget, reason: label);
      }
      await _scrollTo(tester, find.text('Lift stuck between floors'));
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Your Daily Checklist'), findsNothing);
    });

    testWidgets("owners see today's checklist and their facility bookings", (tester) async {
      final container = await pumpGridsApp(tester);
      await signInAs(tester, container, UserRole.owner);

      expect(find.text('Statistics'), findsNothing);
      await _scrollTo(tester, find.textContaining('Rekha (Maid) checked in at'));
      expect(find.text('Parcel from Amazon is waiting at security'), findsOneWidget);
      expect(find.textContaining('Maintenance of ₹2,500 was due on'), findsOneWidget);

      await _scrollTo(tester, find.textContaining('Badminton Court – booked today'));
      // The closed pool isn't offered as "available now"; the open court is.
      expect(find.text('Swimming Pool'), findsNothing);
    });

    testWidgets("tenants' bill reminder is about rent", (tester) async {
      final home = FakeHomeRepository()
        ..data = HomeData(
          upcomingEvents: const [],
          checklist: [BillDue(isRent: true, amountPaise: 1500000, dueDate: DateTime.now().add(const Duration(days: 3)), overdue: false)],
        );
      final container = await pumpGridsApp(tester, home: home);
      await signInAs(tester, container, UserRole.tenant);

      await _scrollTo(tester, find.textContaining('Rent of ₹15,000 is due on'));
      expect(find.text('No upcoming events'), findsOneWidget);
    });
  });

  group('Tower', () {
    testWidgets('residents see their log, notices, neighbours, facilities and complaints', (tester) async {
      final container = await pumpGridsApp(tester);
      await signInAs(tester, container, UserRole.owner);
      await tester.tap(find.bySemanticsLabel('Tower'));
      await tester.pumpAndSettle();

      expect(_appBarTitle('Tower'), findsOneWidget);
      expect(find.text('Rekha (Maid)'), findsOneWidget);
      expect(find.text('At gate'), findsOneWidget);
      expect(find.text('Lift maintenance'), findsOneWidget);
      expect(find.text('Add Notice'), findsNothing);
      await _scrollTo(tester, find.text('Riya Mehta'));
      await _scrollTo(tester, find.text('Badminton Court'));
      expect(find.widgetWithText(FilledButton, 'Book'), findsWidgets);
      await _scrollTo(tester, find.text('Post Complaint'));
      expect(find.text('My Complaints'), findsOneWidget);
    });

    testWidgets('admins get management actions and no neighbours section', (tester) async {
      final container = await pumpGridsApp(tester);
      await signInAs(tester, container, UserRole.admin);
      await tester.tap(find.bySemanticsLabel('Tower'));
      await tester.pumpAndSettle();

      expect(find.text('Add Notice'), findsOneWidget);
      expect(find.text('Neighbours Directory'), findsNothing);
      await _scrollTo(tester, find.text('Add Facility'));
      expect(find.byTooltip('Edit Facility'), findsWidgets);
      await _scrollTo(tester, find.text('Complaints'));
      expect(find.text('Post Complaint'), findsNothing);
    });

    testWidgets('booking: pick a day and a free slot, then confirm', (tester) async {
      final facilities = FakeFacilitiesRepository();
      final container = await pumpGridsApp(tester, facilities: facilities);
      await signInAs(tester, container, UserRole.owner);
      container.read(routerProvider).go(AppRoutes.bookFacility('f1'));
      await tester.pumpAndSettle();

      expect(_appBarTitle('Badminton Court'), findsOneWidget);
      await tester.tap(find.text('Tomorrow'));
      await tester.pumpAndSettle();

      Finder slotChip(String time) => find.ancestor(of: find.textContaining(time), matching: find.byType(ChoiceChip));
      // 07:00 tomorrow is taken in the fake, so its chip is disabled.
      expect(tester.widget<ChoiceChip>(slotChip('7:00')).onSelected, isNull);

      await tester.tap(slotChip('6:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Book 6:00'));
      await tester.pumpAndSettle();

      expect(facilities.booked.single.$1, 'f1');
      expect(facilities.booked.single.$2.hour, 6);
      expect(find.textContaining('Badminton Court booked for'), findsOneWidget);
    });

    testWidgets('residents post a complaint with validation', (tester) async {
      final tower = FakeTowerRepository();
      final container = await pumpGridsApp(tester, tower: tower);
      await signInAs(tester, container, UserRole.tenant);
      container.read(routerProvider).go(AppRoutes.postComplaint);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Post Complaint'));
      await tester.pumpAndSettle();
      expect(find.text('This field is required'), findsNWidgets(2));

      await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Leaking tap');
      await tester.enterText(find.widgetWithText(TextFormField, 'Description'), 'The kitchen tap leaks all night.');
      await tester.tap(find.widgetWithText(FilledButton, 'Post Complaint'));
      await tester.pumpAndSettle();

      expect(tower.postedComplaints.single.title, 'Leaking tap');
      expect(find.text('Complaint posted'), findsOneWidget);
    });

    testWidgets('admins add a notice', (tester) async {
      final tower = FakeTowerRepository();
      final container = await pumpGridsApp(tester, tower: tower);
      await signInAs(tester, container, UserRole.admin);
      await tester.tap(find.bySemanticsLabel('Tower'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Notice'));
      await tester.pumpAndSettle();

      expect(_appBarTitle('Add Notice'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Water tank cleaning');
      await tester.enterText(find.widgetWithText(TextFormField, 'Description'), 'Store water the night before.');
      await tester.tap(find.text('Show as an alert on Home'));
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(tower.createdNotices.single.title, 'Water tank cleaning');
      expect(tower.createdNotices.single.isAlert, isTrue);
      expect(_appBarTitle('Tower'), findsOneWidget); // back on the tab
    });

    testWidgets('admins change a complaint status from the detail sheet', (tester) async {
      final tower = FakeTowerRepository();
      final container = await pumpGridsApp(tester, tower: tower);
      await signInAs(tester, container, UserRole.admin);
      container.read(routerProvider).go(AppRoutes.towerComplaints);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lift stuck between floors'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(SegmentedButton<ComplaintStatus>), matching: find.text('Resolved')));
      await tester.pumpAndSettle();

      expect(tower.statusChanges.single, ('c1', ComplaintStatus.resolved));
      expect(find.text('Status changed to Resolved'), findsOneWidget);
    });

    testWidgets('residents cannot open admin forms by URL', (tester) async {
      final container = await pumpGridsApp(tester);
      await signInAs(tester, container, UserRole.owner);
      final router = container.read(routerProvider);
      router.go(AppRoutes.noticeForm);
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, AppRoutes.home);
      expect(_appBarTitle('Add Notice'), findsNothing);
    });
  });
}
