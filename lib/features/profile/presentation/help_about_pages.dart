import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/phone_call.dart';
import '../../../core/widgets/widgets.dart';
import 'profile_providers.dart';

/// Common questions and the society office's numbers.
class HelpPage extends ConsumerWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final society = ref.watch(societyInfoProvider);
    final faqs = [
      (l10n.faqLoginQ, l10n.faqLoginA),
      (l10n.faqPayQ, l10n.faqPayA),
      (l10n.faqReceiptQ, l10n.faqReceiptA),
      (l10n.faqTenantQ, l10n.faqTenantA),
      (l10n.faqNotificationsQ, l10n.faqNotificationsA),
      (l10n.faqLanguageQ, l10n.faqLanguageA),
    ];
    return GridsPage(
      title: l10n.drawerHelp,
      showMenu: false,
      body: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          SectionHeader(title: l10n.faqTitle, icon: Icons.quiz_rounded),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (q, a) in faqs)
                  ExpansionTile(
                    title: Text(q),
                    childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(a)],
                  ),
              ],
            ),
          ),
          SectionHeader(title: l10n.societyOfficeTitle, icon: Icons.support_agent_rounded),
          AsyncValueView(
            value: society,
            onRetry: () => ref.invalidate(societyInfoProvider),
            data: (s) => Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text(s.name, style: Theme.of(context).textTheme.titleMedium),
                    subtitle: s.address == null && s.city == null
                        ? null
                        : Text([?s.address, ?s.city].join(', ')),
                  ),
                  for (final c in s.office)
                    ListTile(
                      leading: PersonAvatar(name: c.name),
                      title: Text(c.name),
                      subtitle: Text('${l10n.roleAdmin} · ${formatPhone(c.phone)}'),
                      trailing: IconButton.filledTonal(
                        tooltip: l10n.callPerson(c.name),
                        onPressed: () => callPhone(context, c.phone),
                        icon: const Icon(Icons.call_rounded),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final _packageInfoProvider = FutureProvider<PackageInfo>((ref) => PackageInfo.fromPlatform());

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final slate = GridsColors.of(context).slate;
    final info = ref.watch(_packageInfoProvider).value;
    final promises = [
      (Icons.phonelink_lock_rounded, l10n.aboutOtpOnly),
      (Icons.badge_outlined, l10n.aboutNoAadhaar),
      (Icons.credit_card_off_rounded, l10n.aboutNoCards),
      (Icons.lock_person_rounded, l10n.aboutPrivacy),
    ];
    return GridsPage(
      title: l10n.drawerAbout,
      showMenu: false,
      body: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          const SizedBox(height: AppSpacing.lg),
          const Center(child: GridsLogo(width: 120)),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.appTitle, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
          Text(l10n.appTagline, textAlign: TextAlign.center, style: TextStyle(color: slate)),
          if (info != null)
            Text(
              l10n.versionLabel('${info.version} (${info.buildNumber})'),
              textAlign: TextAlign.center,
              style: TextStyle(color: slate),
            ),
          const SizedBox(height: AppSpacing.xl),
          Card(
            child: Column(
              children: [
                for (final (icon, text) in promises)
                  ListTile(leading: Icon(icon, color: theme.colorScheme.primary), title: Text(text)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(AppSpacing.minTapTarget)),
            onPressed: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
              applicationVersion: info?.version,
              applicationIcon: const GridsLogo(width: 56),
            ),
            child: Text(l10n.openSourceLicences),
          ),
        ],
      ),
    );
  }
}
