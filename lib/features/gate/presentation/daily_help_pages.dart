import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/phone_call.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/session_controller.dart';
import '../../home/presentation/home_providers.dart';
import '../data/gate_repository.dart';
import '../domain/gate_models.dart';
import 'gate_labels.dart';
import 'gate_providers.dart';

/// Residents: the maid, cook or driver who work for the flat, with their gate
/// code and this month's attendance. The gate: everyone, with Mark in / out.
class DailyHelpPage extends ConsumerStatefulWidget {
  const DailyHelpPage({super.key});

  @override
  ConsumerState<DailyHelpPage> createState() => _DailyHelpPageState();
}

class _DailyHelpPageState extends ConsumerState<DailyHelpPage> {
  String _query = '';

  Future<void> _mark(DailyHelp h) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(gateRepositoryProvider).markAttendance(h.id);
      ref
        ..invalidate(dailyHelpProvider)
        ..invalidate(homeProvider);
      messenger.showSnackBar(SnackBar(content: Text(h.inside ? l10n.staffMarkedOut(h.name) : l10n.staffMarkedIn(h.name))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final role = ref.watch(currentSessionProvider)?.role;
    final gate = role?.isGate ?? false;
    final resident = role?.isResident ?? false;
    return GridsPage(
      title: l10n.dailyHelpTitle,
      showMenu: false,
      floatingActionButton: resident
          ? FloatingActionButton.extended(
              onPressed: () => _showAddHelp(context, ref),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(l10n.addDailyHelp),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(dailyHelpProvider.future),
        child: AsyncValueView(
          value: ref.watch(dailyHelpProvider),
          onRetry: () => ref.invalidate(dailyHelpProvider),
          isEmpty: (list) => list.isEmpty,
          empty: EmptyState(
            icon: Icons.cleaning_services_rounded,
            title: l10n.noDailyHelp,
            message: resident ? l10n.dailyHelpHint : null,
          ),
          data: (all) {
            final q = _query.trim().toLowerCase();
            final helpers = q.isEmpty
                ? all
                : all.where((h) => h.name.toLowerCase().contains(q) || h.flatLabels.any((f) => f.toLowerCase().contains(q))).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
              children: [
                if (gate) ...[
                  TextField(
                    decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l10n.searchStaffHint),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (helpers.isEmpty)
                  Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: Center(child: Text(l10n.noMatches))),
                for (final h in helpers) ...[
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                      leading: PersonAvatar(name: h.name),
                      title: Text(h.name),
                      subtitle: Text(
                        [
                          helpKindLabel(l10n, h.kind),
                          if (gate) ...h.flatLabels else l10n.daysThisMonth(h.daysThisMonth),
                          if (h.passCode != null && !gate) l10n.codeLabel(h.passCode!),
                        ].join(' · '),
                      ),
                      trailing: gate
                          ? FilledButton.tonal(onPressed: () => _mark(h), child: Text(h.inside ? l10n.markOut : l10n.markIn))
                          : h.inside
                              ? StatusChip(label: l10n.staffInside, tone: StatusTone.success)
                              : null,
                      onTap: () => _showHelpDetails(context, ref, h, gate: gate),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

Future<void> _showAddHelp(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final validators = Validators(l10n);
  final name = TextEditingController();
  final phone = TextEditingController();
  var kind = helpKinds.first;
  DailyHelp? added;

  final saved = await BottomSheetForm.show(
    context,
    title: l10n.addDailyHelp,
    submitLabel: l10n.add,
    fields: [
      DropdownButtonFormField<String>(
        initialValue: kind,
        decoration: InputDecoration(labelText: l10n.helpKindField),
        items: [for (final k in helpKinds) DropdownMenuItem(value: k, child: Text(helpKindLabel(l10n, k)))],
        onChanged: (v) => kind = v ?? kind,
      ),
      TextFormField(
        controller: name,
        decoration: InputDecoration(labelText: l10n.nameField),
        textCapitalization: TextCapitalization.words,
        maxLength: 60,
        validator: (v) => validators.required(v) ?? (v!.trim().length < 2 ? l10n.validationTooShort : null),
      ),
      TextFormField(
        controller: phone,
        decoration: InputDecoration(labelText: l10n.mobileOptionalField, prefixText: '+91 ', helperText: l10n.dailyHelpPhoneHint),
        keyboardType: TextInputType.phone,
        validator: (v) => v == null || v.trim().isEmpty ? null : validators.indianMobile(v),
      ),
    ],
    onSubmit: () async {
      added = await ref.read(gateRepositoryProvider).addDailyHelp(
            name: name.text.trim(),
            kind: kind,
            phone: phone.text.trim().isEmpty ? null : Validators.normalizeIndianMobile(phone.text),
          );
    },
  );
  if (saved == true && added != null) {
    ref.invalidate(dailyHelpProvider);
    messenger.showSnackBar(SnackBar(content: Text(l10n.dailyHelpAdded(added!.name, added!.passCode ?? ''))));
  }
}

/// This month's visits; call, share the gate code, or remove.
Future<void> _showHelpDetails(BuildContext context, WidgetRef ref, DailyHelp h, {required bool gate}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final role = ref.read(currentSessionProvider)?.role;
  // Residents unlink them from their flat; admins remove them from the society.
  final canRemove = role != null && (role.isResident || role == UserRole.admin);

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, controller) => Consumer(
        builder: (sheet, ref, _) {
          final attendance = ref.watch(attendanceProvider((h.id, null)));
          final theme = Theme.of(sheet);
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: PersonAvatar(name: h.name, radius: 24),
                title: Text(h.name, style: theme.textTheme.titleLarge),
                subtitle: Text([helpKindLabel(l10n, h.kind), ...h.flatLabels].join(' · ')),
              ),
              if (h.passCode != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.pin_rounded),
                  title: Text(l10n.gateCode),
                  subtitle: Text(h.passCode!, style: theme.textTheme.titleLarge?.copyWith(letterSpacing: 4)),
                  trailing: IconButton(
                    tooltip: l10n.sharePass,
                    onPressed: () => SharePlus.instance.share(ShareParams(text: l10n.staffCodeShareText(h.name, h.passCode!))),
                    icon: const Icon(Icons.share_rounded),
                  ),
                ),
              if (h.phone != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.call_rounded),
                  title: Text(l10n.callPerson(h.name)),
                  subtitle: Text(formatPhone(h.phone!)),
                  onTap: () => callPhone(sheet, h.phone!),
                ),
              const Divider(),
              Text(l10n.attendanceThisMonth, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              ...attendance.when(
                loading: () => const [Center(child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: CircularProgressIndicator()))],
                error: (e, _) => [Text(describeError(l10n, e))],
                data: (month) => [
                  Text(l10n.daysThisMonth(month.days), style: theme.textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.sm),
                  if (month.entries.isEmpty) Text(l10n.noVisitsYet),
                  for (final e in month.entries)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_available_rounded),
                      title: Text(formatDayShort(sheet, e.inTime)),
                      trailing: Text(
                        e.outTime == null
                            ? '${formatTime(sheet, e.inTime)} – ${l10n.staffInside}'
                            : formatTimeRange(sheet, e.inTime, e.outTime!),
                      ),
                    ),
                ],
              ),
              if (canRemove) ...[
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.person_remove_rounded, color: theme.colorScheme.error),
                  title: Text(l10n.removeDailyHelp, style: TextStyle(color: theme.colorScheme.error)),
                  onTap: () async {
                    final ok = await confirmAction(
                      sheet,
                      title: l10n.removeDailyHelpConfirm(h.name),
                      message: l10n.removeDailyHelpBody,
                      confirmLabel: l10n.remove,
                      destructive: true,
                    );
                    if (!ok || !sheet.mounted) return;
                    Navigator.pop(sheet);
                    try {
                      await ref.read(gateRepositoryProvider).removeDailyHelp(h.id);
                      ref.invalidate(dailyHelpProvider);
                      messenger.showSnackBar(SnackBar(content: Text(l10n.dailyHelpRemoved(h.name))));
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
                    }
                  },
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
}
