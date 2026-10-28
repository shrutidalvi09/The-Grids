import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/notifications/presentation/unread_count_provider.dart';
import '../l10n/l10n.dart';
import '../router/routes.dart';
import 'shell_scaffold_key.dart';

/// Standard page frame: app bar with menu (or back), the page's own title,
/// and the notification bell.
///
/// Tab pages use `showMenu: true` (the default) to open the shell drawer.
/// Pages pushed over the shell pass `showMenu: false` to get a back button.
class GridsPage extends StatelessWidget {
  const GridsPage({
    super.key,
    required this.title,
    required this.body,
    this.showMenu = true,
    this.showNotifications = true,
    this.floatingActionButton,
    this.actions = const [],
  });

  final String title;
  final Widget body;
  final bool showMenu;
  final bool showNotifications;
  final Widget? floatingActionButton;

  /// Extra app-bar buttons (e.g. an admin's edit menu), before the bell.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GridsAppBar(
        title: title,
        showMenu: showMenu,
        showNotifications: showNotifications,
        actions: actions,
      ),
      body: SafeArea(top: false, bottom: false, child: body),
      floatingActionButton: floatingActionButton,
    );
  }
}

class GridsAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const GridsAppBar({
    super.key,
    required this.title,
    this.showMenu = true,
    this.showNotifications = true,
    this.actions = const [],
  });

  final String title;
  final bool showMenu;
  final bool showNotifications;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      toolbarHeight: kToolbarHeight + 8,
      title: Text(title),
      automaticallyImplyLeading: !showMenu,
      leading: showMenu
          ? IconButton(
              icon: const Icon(Icons.menu_rounded),
              tooltip: context.l10n.openMenuTooltip,
              onPressed: () => ref.read(shellScaffoldKeyProvider).currentState?.openDrawer(),
            )
          : null,
      actions: [
        ...actions,
        if (showNotifications) const NotificationBell(),
        const SizedBox(width: 4),
      ],
    );
  }
}

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadNotificationCountProvider);
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: context.l10n.unreadNotifications(count),
      onPressed: () => context.push(AppRoutes.notifications),
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: scheme.secondaryContainer,
        textColor: scheme.onSecondaryContainer,
        // The number pops when it changes (e.g. after reading a notification).
        label: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Text(count > 9 ? '9+' : '$count', key: ValueKey(count)),
        ),
        child: const Icon(Icons.notifications_rounded),
      ),
    );
  }
}
