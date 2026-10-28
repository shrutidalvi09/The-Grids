import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/session.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../l10n/l10n.dart';
import '../network/api_exception.dart';
import '../router/routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/grids_logo.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(currentSessionProvider);
    final theme = Theme.of(context);

    void open(String route) {
      Navigator.of(context).pop();
      context.push(route);
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Row(
                children: [
                  const GridsLogo(width: 64),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.appTitle, style: theme.textTheme.titleLarge),
                        if (session != null)
                          Text(
                            '${session.firstName} · ${session.role.label(l10n)}',
                            style: theme.textTheme.bodyMedium?.copyWith(color: GridsColors.of(context).slate),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (session != null)
              ListTile(
                leading: const Icon(Icons.swap_horiz_rounded),
                title: Text(session.societyName),
                subtitle: Text(l10n.drawerSwitchSociety),
                onTap: session.memberships.length > 1
                    ? () {
                        Navigator.of(context).pop();
                        showMembershipSwitcher(context, ref, session);
                      }
                    : null,
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.event_rounded),
              title: Text(l10n.drawerEvents),
              onTap: () => open(AppRoutes.events),
            ),
            ListTile(
              leading: const Icon(Icons.sports_tennis_rounded),
              title: Text(l10n.drawerFacilityBookings),
              onTap: () => open(AppRoutes.facilityBookings),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline_rounded),
              title: Text(l10n.drawerHelp),
              onTap: () => open(AppRoutes.help),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(l10n.drawerAbout),
              onTap: () => open(AppRoutes.about),
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
              title: Text(l10n.drawerLogout, style: TextStyle(color: theme.colorScheme.error)),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(sessionControllerProvider.notifier).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Lists the user's memberships (societies × roles); picking one switches the
/// session to it.
Future<void> showMembershipSwitcher(BuildContext context, WidgetRef ref, AppSession session) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  // Read now: the caller (the drawer) is closed and disposed while the sheet
  // is open, and its ref can't be used after that.
  final sessions = ref.read(sessionControllerProvider.notifier);
  final picked = await showModalBottomSheet<MembershipSummary>(
    useRootNavigator: true, // above the bottom nav bar
    context: context,
    useSafeArea: true,
    builder: (sheetContext) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.sm),
          child: Text(l10n.switchRoleTitle, style: Theme.of(sheetContext).textTheme.titleLarge),
        ),
        for (final m in session.memberships)
          ListTile(
            leading: Icon(
              m.id == session.membership.id ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
            ),
            title: Text('${m.role.label(l10n)} · ${m.societyName}'),
            subtitle: m.flatLabel == null ? null : Text(m.flatLabel!),
            trailing: m.id == session.membership.id ? Text(l10n.currentLabel) : null,
            onTap: () => Navigator.of(sheetContext).pop(m),
          ),
      ],
    ),
  );
  if (picked == null || picked.id == session.membership.id) return;
  try {
    await sessions.switchTo(picked.id);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
  }
}
