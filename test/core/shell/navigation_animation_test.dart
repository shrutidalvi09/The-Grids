import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_grids/core/shell/animated_branch_container.dart';
import 'package:the_grids/core/shell/grids_bottom_nav.dart';
import 'package:the_grids/features/auth/domain/user_role.dart';

import '../../helpers/pump_app.dart';

Finder _appBarTitle(String text) => find.descendant(of: find.byType(AppBar), matching: find.text(text));

/// The orange pill's left edge in the bottom nav.
double _pillLeft(WidgetTester tester) => tester
    .getTopLeft(find.descendant(of: find.byType(GridsBottomNav), matching: find.byType(DecoratedBox)).first)
    .dx;

void main() {
  testWidgets('switching tabs slides the pill and cross-fades the pages', (tester) async {
    final container = await pumpGridsApp(tester);
    await signInAs(tester, container, UserRole.owner);
    final homeLeft = _pillLeft(tester);

    await tester.tap(find.bySemanticsLabel('Community'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    // Mid-switch: both pages are on screen and the pill is between the tabs.
    expect(_appBarTitle('Home'), findsOneWidget);
    expect(_appBarTitle('Community'), findsOneWidget);
    final midLeft = _pillLeft(tester);
    expect(midLeft, greaterThan(homeLeft));

    await tester.pumpAndSettle();
    expect(_pillLeft(tester), greaterThan(midLeft));
    // Done: the old tab is offstage (and out of the semantics tree), but kept.
    expect(_appBarTitle('Home'), findsNothing);
    expect(_appBarTitle('Community'), findsOneWidget);
    expect(find.byType(AnimatedBranchContainer), findsOneWidget);
  });

  testWidgets('tabs keep their state across switches', (tester) async {
    final container = await pumpGridsApp(tester);
    await signInAs(tester, container, UserRole.owner);

    await tester.tap(find.bySemanticsLabel('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Services'));
    await tester.pumpAndSettle();
    expect(_appBarTitle('Services'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Profile'));
    await tester.pumpAndSettle();
    expect(_appBarTitle('Services'), findsOneWidget); // still on the pushed page
  });

  testWidgets('with reduced motion the switch is immediate', (tester) async {
    final container = await pumpGridsApp(tester);
    await signInAs(tester, container, UserRole.owner);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Tower'));
    await tester.pump();
    await tester.pump();
    expect(_appBarTitle('Home'), findsNothing);
    expect(_appBarTitle('Tower'), findsOneWidget);
  });

  testWidgets('tab icons sit vertically centred on the pill', (tester) async {
    final container = await pumpGridsApp(tester);
    await signInAs(tester, container, UserRole.owner);
    final pill = find.descendant(of: find.byType(GridsBottomNav), matching: find.byType(DecoratedBox)).first;
    final pillCentre = tester.getCenter(pill).dy;
    for (final icon in [Icons.home_rounded, Icons.apartment_rounded, Icons.person_rounded]) {
      final iconFinder = find.descendant(of: find.byType(GridsBottomNav), matching: find.byIcon(icon));
      expect(tester.getCenter(iconFinder).dy, closeTo(pillCentre, 1), reason: '$icon');
    }
  });
}
