import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/user_role.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../l10n/l10n.dart';
import 'app_drawer.dart';
import 'grids_bottom_nav.dart';
import 'nav_destinations.dart';
import 'shell_scaffold_key.dart';

/// Signed-in frame: drawer + bottom nav around the five tab branches.
/// Each tab page renders its own app bar via `GridsPage`.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentSessionProvider)?.role ?? UserRole.owner;
    return Scaffold(
      key: ref.watch(shellScaffoldKeyProvider),
      drawer: const AppDrawer(),
      body: navigationShell,
      bottomNavigationBar: GridsBottomNav(
        destinations: navDestinations(context.l10n, role),
        selectedIndex: navigationShell.currentIndex,
        // Re-tapping the current tab returns it to its first page.
        onSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
