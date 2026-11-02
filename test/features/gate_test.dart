import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_grids/core/router/app_router.dart';
import 'package:the_grids/core/router/routes.dart';
import 'package:the_grids/core/shell/grids_bottom_nav.dart';
import 'package:the_grids/features/auth/domain/user_role.dart';
import 'package:the_grids/features/gate/domain/gate_models.dart';
import 'package:the_grids/features/home/domain/home_models.dart';
import 'package:the_grids/features/tower/domain/tower_models.dart';

import '../helpers/feature_fakes.dart';
import '../helpers/gate_fakes.dart';
import '../helpers/profile_fakes.dart';
import '../helpers/pump_app.dart';

Finder _navLabel(String text) => find.descendant(of: find.byType(GridsBottomNav), matching: find.byTooltip(text));

FakeHomeRepository _guardHome() => FakeHomeRepository()
  ..data = const HomeData(
    upcomingEvents: [],
    gate: GateSummary(awaitingApproval: 1, expected: 2, inside: 3, parcels: 1, staffInside: 2),
  );

void main() {
  group('Guards', () {
    testWidgets('get Gate, Visitors and Profile tabs and check a daily-help code', (tester) async {
      final gate = FakeGateRepository();
      final container = await pumpGridsApp(tester, home: _guardHome(), gate: gate);
      await signInAs(tester, container, UserRole.guard);

      for (final tab in ['Gate', 'Visitors', 'Profile']) {
        expect(_navLabel(tab), findsOneWidget, reason: tab);
      }
      expect(_navLabel('Maintenance'), findsNothing);
      expect(_navLabel('Community'), findsNothing);
      expect(find.byTooltip('Emergency SOS'), findsNothing); // guards respond to alerts
      expect(find.bySemanticsLabel('Waiting for flat: 1'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Pass code'), '24680');
      await tester.tap(find.text('Check code'));
      await tester.pumpAndSettle();
      expect(find.text('Rekha Jadhav'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Mark in'));
      await tester.pumpAndSettle();
      expect(gate.attendanceMarks, ['dh1']);
      expect(find.text('Rekha Jadhav marked in'), findsOneWidget);
    });

    testWidgets('let a guest in with their pass; a wrong code shows an error', (tester) async {
      final gate = FakeGateRepository();
      final tower = FakeTowerRepository();
      final container = await pumpGridsApp(tester, home: _guardHome(), gate: gate, tower: tower);
      await signInAs(tester, container, UserRole.guard);

      await tester.enterText(find.widgetWithText(TextField, 'Pass code'), '111111');
      await tester.tap(find.text('Check code'));
      await tester.pumpAndSettle();
      expect(find.text('No valid pass with this code. It may be used already.'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Pass code'), '482913');
      await tester.tap(find.text('Check code'));
      await tester.pumpAndSettle();
      expect(find.text('Valid pass'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Let in'));
      await tester.pumpAndSettle();
      expect(tower.gateChanges, [('v9', GateStatus.checkedIn)]);
    });

    testWidgets('log a walk-in and ask the flat', (tester) async {
      final tower = FakeTowerRepository();
      final container = await pumpGridsApp(tester, home: _guardHome(), tower: tower, profile: FakeProfileRepository());
      await signInAs(tester, container, UserRole.guard);
      await tester.tap(_navLabel('Visitors'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log Visitor'));
      await tester.pumpAndSettle();
      expect(find.text('Ask flat'), findsOneWidget);
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Flat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tower-A, 103 · vacant').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Swiggy');
      await tester.tap(find.widgetWithText(FilledButton, 'Log Visitor'));
      await tester.pumpAndSettle();

      final logged = tower.addedVisitors.single;
      expect((logged.name, logged.flatId, logged.arrival), ('Swiggy', 'fa3', GateArrival.ask));
      expect(find.text('Asked the flat about Swiggy'), findsOneWidget);
    });

    testWidgets("can't open resident screens by URL", (tester) async {
      final container = await pumpGridsApp(tester, home: _guardHome());
      await signInAs(tester, container, UserRole.guard);
      for (final path in [AppRoutes.maintenance, AppRoutes.community, AppRoutes.dailyHelp, AppRoutes.towerComplaints]) {
        container.read(routerProvider).go(path);
        await tester.pumpAndSettle();
        expect(container.read(routerProvider).state.matchedLocation, AppRoutes.home, reason: path);
      }
    });
  });

  group('Residents', () {
    testWidgets('allow a walk-in waiting at the gate', (tester) async {
      final tower = FakeTowerRepository()
        ..visitorList = [
          const Visitor(id: 'v4', name: 'Swiggy', type: VisitorType.delivery, status: VisitorStatus.pendingApproval),
        ];
      final container = await pumpGridsApp(tester, tower: tower);
      await signInAs(tester, container, UserRole.tenant);
      container.read(routerProvider).go(AppRoutes.towerVisitors);
      await tester.pumpAndSettle();

      expect(find.text('Waiting'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Allow'));
      await tester.pumpAndSettle();
      expect(tower.decisions, [('v4', true)]);
      expect(find.text('Swiggy allowed in'), findsOneWidget);
      expect(find.text('Allow'), findsNothing);
    });

    testWidgets('get a gate pass to share after adding a visitor', (tester) async {
      final tower = FakeTowerRepository();
      final container = await pumpGridsApp(tester, tower: tower);
      await signInAs(tester, container, UserRole.owner);
      container.read(routerProvider).go(AppRoutes.towerVisitors);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Visitor'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Kavya');
      await tester.enterText(find.widgetWithText(TextFormField, 'Vehicle number (optional)'), 'MH04GH2211');
      await tester.tap(find.widgetWithText(FilledButton, 'Add Visitor'));
      await tester.pumpAndSettle();

      expect(tower.addedVisitors.single.vehicleNumber, 'MH04GH2211');
      expect(find.text('Gate pass'), findsOneWidget);
      expect(find.text('482 913'), findsOneWidget);
      expect(find.text('Share pass'), findsOneWidget);
    });

    testWidgets('raise an SOS after confirming', (tester) async {
      final gate = FakeGateRepository();
      final container = await pumpGridsApp(tester, gate: gate);
      await signInAs(tester, container, UserRole.owner);

      await tester.tap(find.byTooltip('Emergency SOS'));
      await tester.pumpAndSettle();
      expect(find.text('Send an emergency alert?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(gate.sosRaised, isEmpty);

      await tester.tap(find.byTooltip('Emergency SOS'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Medical');
      await tester.tap(find.text('Send alert'));
      await tester.pumpAndSettle();
      expect(gate.sosRaised, ['Medical']);
      expect(find.text('Alert sent. Help is on the way.'), findsOneWidget);
    });

    testWidgets('see an active SOS for their flat and mark it handled', (tester) async {
      final gate = FakeGateRepository();
      final home = FakeHomeRepository()
        ..data = HomeData(
          upcomingEvents: const [],
          activeSos: [ActiveSos(id: 'sos1', flatLabel: 'Tower-C, 502', raisedBy: 'Chetan', raisedByPhone: '+919811111111', createdAt: DateTime.now())],
        );
      final container = await pumpGridsApp(tester, gate: gate, home: home);
      await signInAs(tester, container, UserRole.owner);

      expect(find.text('SOS: Tower-C, 502'), findsOneWidget);
      expect(find.text('Call Chetan'), findsOneWidget);
      await tester.tap(find.text('Mark handled'));
      await tester.pumpAndSettle();
      expect(gate.sosResolved, ['sos1']);
    });

    testWidgets('add daily help and see their gate code', (tester) async {
      final gate = FakeGateRepository();
      final container = await pumpGridsApp(tester, gate: gate);
      await signInAs(tester, container, UserRole.owner);
      container.read(routerProvider).go(AppRoutes.dailyHelp);
      await tester.pumpAndSettle();

      expect(find.text('Rekha Jadhav'), findsOneWidget);
      expect(find.textContaining('Code 24680'), findsOneWidget);
      expect(find.text('Inside'), findsOneWidget);
      expect(find.text('Mark in'), findsNothing); // only the gate marks attendance

      await tester.tap(find.text('Add Help'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Sunita');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(gate.addedHelpers.single, ('Sunita', 'Maid', null));
      expect(find.text('Sunita added. Gate code: 13579'), findsOneWidget);

      await tester.tap(find.text('Rekha Jadhav'));
      await tester.pumpAndSettle();
      expect(find.text('Attendance this month'), findsOneWidget);
      expect(find.text('1 day this month'), findsOneWidget);
    });

    testWidgets('register a vehicle', (tester) async {
      final gate = FakeGateRepository();
      final container = await pumpGridsApp(tester, gate: gate);
      await signInAs(tester, container, UserRole.tenant);
      container.read(routerProvider).go(AppRoutes.vehicles);
      await tester.pumpAndSettle();

      expect(find.text('MH 04 AB 1234'), findsOneWidget);
      expect(find.text('Slot C-12'), findsOneWidget);
      await tester.tap(find.text('Add Vehicle'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Vehicle number'), '!!');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid vehicle number'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Vehicle number'), 'mh 02 cd 5678');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(gate.addedVehicles.single.number, 'mh 02 cd 5678');
      expect(gate.addedVehicles.single.type, VehicleType.car);
    });
  });

  testWidgets('admins assign a parking slot', (tester) async {
    final gate = FakeGateRepository();
    final container = await pumpGridsApp(tester, gate: gate);
    await signInAs(tester, container, UserRole.admin);
    container.read(routerProvider).go(AppRoutes.vehicles);
    await tester.pumpAndSettle();

    await tester.tap(find.text('MH 04 AB 1234'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assign parking slot'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'B1-23');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(gate.slots, [('ve1', 'B1-23')]);
  });

  testWidgets('the gate finds who owns a vehicle', (tester) async {
    final gate = FakeGateRepository();
    final container = await pumpGridsApp(tester, gate: gate, home: _guardHome());
    await signInAs(tester, container, UserRole.guard);
    await tester.ensureVisible(find.text('Find a vehicle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find a vehicle'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ab 12');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(gate.searches, ['ab12']);
    expect(find.text('MH 04 AB 1234'), findsOneWidget);
    expect(find.text('Shruti Chetan Dalvi'), findsOneWidget);
  });
}
