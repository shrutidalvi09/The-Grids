import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/user_role.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../l10n/l10n.dart';
import '../network/offline_cache.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
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
    final online = ref.watch(onlineStatusProvider);
    return Scaffold(
      key: ref.watch(shellScaffoldKeyProvider),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Expanded(child: navigationShell),
          // Above the bottom nav, so it doesn't push the pages' app bars around.
          if (!online) const OfflineBanner(),
        ],
      ),
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

/// Shown while the server can't be reached; screens show their last saved data.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Material(
        color: GridsColors.of(context).slate,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(context.l10n.offlineBanner, style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
