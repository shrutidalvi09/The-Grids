import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/session.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/session_controller.dart';

/// Profile card (with the person's real role) and the settings menu.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(currentSessionProvider);
    if (session == null) return const SizedBox.shrink();
    final role = session.role;
    final resident = role != UserRole.admin;

    final items = <(IconData, String, String)>[
      if (resident) (Icons.volunteer_activism_rounded, l10n.householdTitle, AppRoutes.household),
      (Icons.cleaning_services_rounded, l10n.servicesTitle, AppRoutes.services),
      if (resident) (Icons.payments_rounded, l10n.paymentSettingsTitle, AppRoutes.paymentSettings),
      (Icons.language_rounded, l10n.profileLanguage, AppRoutes.languageSettings),
      (Icons.notifications_active_rounded, l10n.notificationPrefsTitle, AppRoutes.notificationSettings),
      (Icons.manage_accounts_rounded, l10n.accountOptionsTitle, AppRoutes.account),
      (Icons.contrast_rounded, l10n.profileTheme, AppRoutes.themeSettings),
      if (role == UserRole.owner) (Icons.key_rounded, l10n.tenantInfoTitle, AppRoutes.tenantInfo),
      if (role == UserRole.tenant) (Icons.real_estate_agent_rounded, l10n.leaseInfoTitle, AppRoutes.leaseInfo),
    ];

    return GridsPage(
      title: l10n.navProfile,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
        children: [
          _ProfileCard(session: session),
          const SizedBox(height: AppSpacing.lg),
          for (final (icon, label, route) in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTileCard(
                leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
                title: label,
                onTap: () => context.go(route),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final slate = GridsColors.of(context).slate;
    Widget line(String label, String value) => Text.rich(
          TextSpan(
            text: '$label: ',
            style: TextStyle(color: slate),
            children: [TextSpan(text: value, style: TextStyle(color: theme.colorScheme.onSurface))],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                PersonAvatar(name: session.displayName, photoPath: session.photoPath, radius: 40),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, AppSpacing.minTapTarget)),
                  onPressed: () => context.go(AppRoutes.editProfile),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: Text(l10n.editProfile),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(session.displayName, style: theme.textTheme.titleMedium),
                  if (session.flatLabel != null) line(l10n.flatLabelField, session.flatLabel!),
                  line(l10n.roleField, session.role.label(l10n)),
                  line(l10n.phoneField, formatPhone(session.phone)),
                  if (session.email != null) line(l10n.emailField, session.email!),
                  Text(session.societyName, style: theme.textTheme.bodySmall?.copyWith(color: slate)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
