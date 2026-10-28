import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_grids/core/router/app_router.dart';
import 'package:the_grids/core/router/routes.dart';
import 'package:the_grids/core/storage/preferences.dart';
import 'package:the_grids/features/auth/domain/user_role.dart';

import 'helpers/pump_app.dart';

/// Material accessibility guidelines on the main screens: 48dp tap targets,
/// every tappable thing has a label, and text meets contrast ratios.
void main() {
  final screens = <(UserRole, String)>[
    (UserRole.owner, AppRoutes.home),
    (UserRole.admin, AppRoutes.home),
    (UserRole.owner, AppRoutes.tower),
    (UserRole.admin, AppRoutes.tower),
    (UserRole.owner, AppRoutes.maintenance),
    (UserRole.admin, AppRoutes.maintenance),
    (UserRole.tenant, AppRoutes.maintenance),
    (UserRole.owner, AppRoutes.community),
    (UserRole.admin, AppRoutes.community),
    (UserRole.owner, AppRoutes.profile),
    (UserRole.owner, AppRoutes.notifications),
    (UserRole.owner, AppRoutes.towerFacilities),
    (UserRole.owner, AppRoutes.notificationSettings),
    (UserRole.owner, AppRoutes.household),
    (UserRole.tenant, AppRoutes.services),
    (UserRole.owner, AppRoutes.help),
  ];

  for (final (role, route) in screens) {
    for (final brightness in Brightness.values) {
      testWidgets('$route as ${role.name} (${brightness.name}) meets accessibility guidelines', (tester) async {
        final handle = tester.ensureSemantics();
        final container = await pumpGridsApp(
          tester,
          prefs: {PrefKeys.themeMode: brightness == Brightness.dark ? 'dark' : 'light'},
        );
        await signInAs(tester, container, role);
        container.read(routerProvider).go(route);
        await tester.pumpAndSettle();

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  }

  testWidgets('sign-in screens meet accessibility guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpGridsApp(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
