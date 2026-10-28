import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../core/widgets/widgets.dart';
import '../../maintenance/presentation/widgets/money_widgets.dart';
import '../data/profile_repository.dart';
import '../domain/profile_models.dart';
import 'profile_providers.dart';

/// Saves a setting to the server too (so pushes can use it); never blocks the UI.
void _syncToServer(WidgetRef ref, {String? language, String? theme}) {
  unawaited(
    ref.read(profileRepositoryProvider).updateProfile(language: language, theme: theme).then((_) {}, onError: (_) {}),
  );
}

class LanguageSettingsPage extends ConsumerWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeProvider);

    Future<void> choose(String? code) async {
      final language = AppLanguage.fromCode(code);
      await ref.read(localeProvider.notifier).set(language);
      _syncToServer(ref, language: language?.code ?? 'en');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.languageSaved)));
      }
    }

    return GridsPage(
      title: l10n.profileLanguage,
      showMenu: false,
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          RadioGroup<String>(
            groupValue: locale?.languageCode ?? '',
            onChanged: choose,
            child: Column(
              children: [
                RadioListTile<String>(value: '', title: Text(l10n.themeSystem)),
                for (final language in AppLanguage.values)
                  RadioListTile<String>(
                    value: language.code,
                    title: Text(language.nativeName),
                    subtitle: language == AppLanguage.english ? null : Text(language.englishName),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ThemeSettingsPage extends ConsumerWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(themeModeProvider);
    final options = [
      (ThemeMode.system, l10n.themeSystem, Icons.brightness_auto_rounded),
      (ThemeMode.light, l10n.themeLight, Icons.light_mode_rounded),
      (ThemeMode.dark, l10n.themeDark, Icons.dark_mode_rounded),
    ];
    return GridsPage(
      title: l10n.profileTheme,
      showMenu: false,
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          RadioGroup<ThemeMode>(
            groupValue: mode,
            onChanged: (value) async {
              if (value == null) return;
              await ref.read(themeModeProvider.notifier).set(value);
              _syncToServer(ref, theme: value.name);
            },
            child: Column(
              children: [
                for (final (value, label, icon) in options)
                  RadioListTile<ThemeMode>(value: value, title: Text(label), secondary: Icon(icon)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Preferred method for Razorpay Checkout. Saved cards and UPI IDs are kept by
/// Razorpay, never by The Grids.
class PaymentSettingsPage extends ConsumerWidget {
  const PaymentSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final slate = GridsColors.of(context).slate;

    Future<void> choose(PaymentMethodPref? method) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref
            .read(profileRepositoryProvider)
            .savePreferences(paymentMethod: method, clearPaymentMethod: method == null);
        ref.invalidate(preferencesProvider);
        messenger.showSnackBar(SnackBar(content: Text(l10n.paymentMethodSaved)));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
      }
    }

    final options = [
      (PaymentMethodPref.upi, l10n.methodUpiLong, Icons.qr_code_2_rounded),
      (PaymentMethodPref.card, methodLabel(l10n, 'card'), Icons.credit_card_rounded),
      (PaymentMethodPref.netbanking, methodLabel(l10n, 'netbanking'), Icons.account_balance_rounded),
      (null, l10n.noPreference, Icons.apps_rounded),
    ];

    return GridsPage(
      title: l10n.paymentSettingsTitle,
      showMenu: false,
      body: AsyncValueView(
        value: ref.watch(preferencesProvider),
        onRetry: () => ref.invalidate(preferencesProvider),
        data: (prefs) => ListView(
          padding: AppSpacing.pagePadding,
          children: [
            Text(l10n.preferredMethodHint, style: TextStyle(color: slate)),
            const SizedBox(height: AppSpacing.md),
            RadioGroup<String>(
              groupValue: prefs.paymentMethod?.name ?? '',
              onChanged: (v) => choose(PaymentMethodPref.fromApi(v)),
              child: Column(
                children: [
                  for (final (value, label, icon) in options)
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: RadioListTile<String>(value: value?.name ?? '', title: Text(label), secondary: Icon(icon)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_rounded, size: 18, color: slate),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(l10n.savedMethodsNote, style: TextStyle(color: slate))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Toggles per kind of update, then "Save Preferences".
class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return GridsPage(
      title: l10n.notificationPrefsTitle,
      showMenu: false,
      body: AsyncValueView(
        value: ref.watch(preferencesProvider),
        onRetry: () => ref.invalidate(preferencesProvider),
        data: (prefs) => _NotificationForm(initial: prefs.notifications),
      ),
    );
  }
}

class _NotificationForm extends ConsumerStatefulWidget {
  const _NotificationForm({required this.initial});

  final Map<NotificationPref, bool> initial;

  @override
  ConsumerState<_NotificationForm> createState() => _NotificationFormState();
}

class _NotificationFormState extends ConsumerState<_NotificationForm> {
  late final Map<NotificationPref, bool> _values = {...widget.initial};
  bool _saving = false;

  Future<void> _save() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).savePreferences(notifications: _values);
      ref.invalidate(preferencesProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.preferencesSaved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final groups = [
      (l10n.prefGroupPayments, [
        (NotificationPref.paymentReminder, l10n.prefPaymentReminder),
        (NotificationPref.paymentSuccess, l10n.prefPaymentSuccess),
        (NotificationPref.maintenanceDue, l10n.prefMaintenanceDue),
      ]),
      (l10n.prefGroupSociety, [
        (NotificationPref.announcements, l10n.prefAnnouncements),
        (NotificationPref.eventsNotices, l10n.prefEventsNotices),
        (NotificationPref.emergencyAlerts, l10n.prefEmergencyAlerts),
        (NotificationPref.complaintUpdates, l10n.prefComplaintUpdates),
      ]),
      (l10n.prefGroupServices, [
        (NotificationPref.visitorArrival, l10n.prefVisitorArrival),
        (NotificationPref.packageDelivery, l10n.prefPackageDelivery),
        (NotificationPref.staffAttendance, l10n.prefStaffAttendance),
      ]),
      (l10n.prefGroupApp, [(NotificationPref.push, l10n.prefPush)]),
    ];

    return ListView(
      padding: AppSpacing.pagePadding,
      children: [
        Text(l10n.notificationPrefsHint, style: TextStyle(color: GridsColors.of(context).slate)),
        for (final (title, switches) in groups) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs),
            child: Text(title, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
          ),
          for (final (pref, label) in switches)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(label),
              value: _values[pref] ?? true,
              onChanged: (on) => setState(() => _values[pref] = on),
            ),
        ],
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(label: l10n.savePreferences, isLoading: _saving, onPressed: _saving ? null : _save),
      ],
    );
  }
}
