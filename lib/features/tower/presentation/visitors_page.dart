import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../../core/widgets/photo_field.dart';
import '../../gate/presentation/guest_pass_sheet.dart';
import '../../profile/domain/profile_models.dart';
import '../../profile/presentation/profile_providers.dart';
import '../../profile/presentation/widgets/flat_picker.dart';
import '../data/tower_repository.dart';
import '../domain/tower_models.dart';
import 'tower_labels.dart';
import 'tower_providers.dart';
import 'widgets/tower_tiles.dart';

/// Visitor & service log. Residents pre-approve visitors for their flat (with
/// a gate pass) and allow or deny walk-ins; the gate (guards, or admins
/// standing in) logs arrivals and checks people in and out.
class VisitorsPage extends ConsumerWidget {
  const VisitorsPage({super.key, this.asTab = false});

  /// The guard's Visitors tab (menu button instead of back).
  final bool asTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final role = ref.watch(currentSessionProvider)?.role;
    final isGate = role?.isGate ?? false;
    final isResident = role?.isResident ?? false;
    // Flat contacts, so the gate can call a flat from a visitor's sheet.
    if (isGate) ref.watch(flatOptionsProvider);
    return GridsPage(
      title: l10n.visitorsTitle,
      showMenu: asTab,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showVisitorForm(context, ref, isGate: isGate),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(isGate ? l10n.logVisitor : l10n.addVisitor),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(visitorsProvider(null).future),
        child: AsyncValueView(
          value: ref.watch(visitorsProvider(null)),
          onRetry: () => ref.invalidate(visitorsProvider(null)),
          isEmpty: (v) => v.isEmpty,
          empty: EmptyState(icon: Icons.badge_rounded, title: l10n.noVisitors, message: l10n.addVisitorHint),
          data: (visitors) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
            itemCount: visitors.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  VisitorTile(
                    visitor: visitors[i],
                    showFlat: isGate,
                    onTap: () => _showVisitorActions(context, ref, visitors[i], isGate: isGate),
                  ),
                  if (isResident && visitors[i].awaitingApproval) _DecisionBar(visitor: visitors[i]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _refreshVisitors(WidgetRef ref) {
  ref
    ..invalidate(visitorsProvider)
    ..invalidate(homeProvider);
}

/// "Swiggy is at the gate": Allow / Deny, right in the list.
class _DecisionBar extends ConsumerStatefulWidget {
  const _DecisionBar({required this.visitor});

  final Visitor visitor;

  @override
  ConsumerState<_DecisionBar> createState() => _DecisionBarState();
}

class _DecisionBarState extends ConsumerState<_DecisionBar> {
  bool _busy = false;

  Future<void> _decide(bool allow) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(towerRepositoryProvider).decideVisitor(widget.visitor.id, allow: allow);
      _refreshVisitors(ref);
      messenger.showSnackBar(
        SnackBar(content: Text(allow ? l10n.visitorAllowed(widget.visitor.name) : l10n.visitorDeniedDone(widget.visitor.name))),
      );
    } catch (e) {
      _refreshVisitors(ref); // someone else may have answered
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
              onPressed: _busy ? null : () => _decide(false),
              icon: const Icon(Icons.block_rounded),
              label: Text(l10n.deny),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _decide(true),
              icon: const Icon(Icons.check_rounded),
              label: Text(l10n.allow),
            ),
          ),
        ],
      ),
    );
  }
}

/// Details plus what the person can do: call, show the gate pass, cancel (if
/// not arrived) and, for the gate, check in / parcel held / check out and
/// call the flat.
Future<void> _showVisitorActions(BuildContext context, WidgetRef ref, Visitor v, {required bool isGate}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(towerRepositoryProvider);

  Future<void> run(Future<void> Function() action, String done) async {
    try {
      await action();
      _refreshVisitors(ref);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    }
  }

  final gateActions = isGate
      ? <(GateStatus, IconData, String)>[
          if (v.status == VisitorStatus.expected ||
              v.status == VisitorStatus.heldAtGate ||
              v.status == VisitorStatus.pendingApproval)
            (GateStatus.checkedIn, Icons.login_rounded, l10n.checkIn),
          if (v.status == VisitorStatus.expected && v.type == VisitorType.delivery)
            (GateStatus.heldAtGate, Icons.inventory_2_rounded, l10n.holdAtGate),
          if (v.status == VisitorStatus.checkedIn) (GateStatus.checkedOut, Icons.logout_rounded, l10n.checkOut),
        ]
      : const <(GateStatus, IconData, String)>[];
  final canCancel = v.status == VisitorStatus.expected && ref.read(currentSessionProvider)?.role != UserRole.guard;
  // The gate calls the flat (e.g. no answer to the Allow / Deny request).
  final flatContacts = isGate && v.flatId != null
      ? (ref.read(flatOptionsProvider).value ?? const <FlatOption>[])
          .where((f) => f.id == v.flatId)
          .expand((f) => f.contacts)
          .toList()
      : const <Contact>[];

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // above the bottom nav bar
    useSafeArea: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(visitorIcon(v.type), size: 32),
            title: Text(v.name, style: Theme.of(sheet).textTheme.titleLarge),
            subtitle: Text([?v.purpose, ?v.flatLabel, ?v.vehicleNumber].join(' · ')),
            trailing: visitorStatusChip(l10n, v.status),
          ),
          const Divider(),
          if (v.passCode != null && v.status == VisitorStatus.expected)
            ListTile(
              leading: const Icon(Icons.qr_code_2_rounded),
              title: Text(l10n.showGatePass),
              subtitle: Text(l10n.codeLabel(v.passCode!)),
              onTap: () {
                Navigator.pop(sheet);
                showGuestPass(context, v);
              },
            ),
          for (final c in flatContacts)
            ListTile(
              leading: const Icon(Icons.phone_in_talk_rounded),
              title: Text(l10n.callPerson(c.name)),
              subtitle: Text(formatPhone(c.phone)),
              onTap: () {
                Navigator.pop(sheet);
                callPhone(context, c.phone);
              },
            ),
          if (v.phone != null)
            ListTile(
              leading: const Icon(Icons.call_rounded),
              title: Text(l10n.callPerson(v.name)),
              subtitle: Text(formatPhone(v.phone!)),
              onTap: () {
                Navigator.pop(sheet);
                callPhone(context, v.phone!);
              },
            ),
          for (final (status, icon, label) in gateActions)
            ListTile(
              leading: Icon(icon),
              title: Text(label),
              onTap: () {
                Navigator.pop(sheet);
                run(() => repo.setVisitorStatus(v.id, status), l10n.visitorUpdated);
              },
            ),
          if (canCancel)
            ListTile(
              leading: Icon(Icons.cancel_outlined, color: Theme.of(sheet).colorScheme.error),
              title: Text(l10n.cancelVisitor, style: TextStyle(color: Theme.of(sheet).colorScheme.error)),
              onTap: () {
                Navigator.pop(sheet);
                run(() => repo.cancelVisitor(v.id), l10n.visitorCancelled);
              },
            ),
          if (v.phone == null && gateActions.isEmpty && !canCancel && v.passCode == null && flatContacts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                v.outTime != null
                    ? l10n.visitorLeftAt(formatTime(context, v.outTime!))
                    : v.inTime != null
                        ? l10n.visitorArrivedAt(formatTime(context, v.inTime!))
                        : l10n.visitorExpected,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}

/// Residents: pre-approve a visitor for their flat (and get a gate pass to
/// share). The gate: log one for any flat, asking the flat or letting them in.
Future<void> showVisitorForm(BuildContext context, WidgetRef ref, {required bool isGate}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final validators = Validators(l10n);
  final name = TextEditingController();
  final purpose = TextEditingController();
  final phone = TextEditingController();
  var type = VisitorType.guest;
  final vehicle = TextEditingController();
  DateTime? expectedAt;
  String? flatId;
  String? photoUrl;
  // Guards meet people at the gate; admins mostly log expected ones.
  var arrival = ref.read(currentSessionProvider)?.role == UserRole.guard ? GateArrival.ask : GateArrival.expected;
  Visitor? created;

  final saved = await BottomSheetForm.show(
    context,
    title: isGate ? l10n.logVisitor : l10n.addVisitor,
    submitLabel: isGate ? l10n.logVisitor : l10n.addVisitor,
    fields: [
      if (isGate)
        _ChoiceField<GateArrival>(
          initial: arrival,
          options: [
            (GateArrival.ask, l10n.arrivalAsk, Icons.notifications_active_rounded),
            (GateArrival.checkIn, l10n.arrivalLetIn, Icons.login_rounded),
            (GateArrival.expected, l10n.arrivalLater, Icons.schedule_rounded),
          ],
          onChanged: (a) => arrival = a,
        ),
      if (isGate) FlatPicker(onChanged: (id) => flatId = id),
      _ChoiceField<VisitorType>(
        initial: type,
        options: [
          (VisitorType.guest, l10n.visitorTypeGuest, Icons.person_rounded),
          (VisitorType.delivery, l10n.visitorTypeDelivery, Icons.local_shipping_rounded),
          (VisitorType.service, l10n.visitorTypeService, Icons.cleaning_services_rounded),
        ],
        onChanged: (t) => type = t,
      ),
      TextFormField(
        controller: name,
        decoration: InputDecoration(labelText: l10n.nameField, hintText: l10n.visitorNameHint),
        textCapitalization: TextCapitalization.words,
        maxLength: 60,
        validator: (v) => validators.required(v) ?? (v!.trim().length < 2 ? l10n.validationTooShort : null),
      ),
      TextFormField(
        controller: purpose,
        decoration: InputDecoration(labelText: l10n.purposeOptionalField, hintText: l10n.visitorPurposeHint),
        textCapitalization: TextCapitalization.sentences,
        maxLength: 40,
      ),
      TextFormField(
        controller: phone,
        decoration: InputDecoration(labelText: l10n.mobileOptionalField, prefixText: '+91 '),
        keyboardType: TextInputType.phone,
        validator: (v) => v == null || v.trim().isEmpty ? null : validators.indianMobile(v),
      ),
      TextFormField(
        controller: vehicle,
        decoration: InputDecoration(labelText: l10n.guestVehicleField, hintText: 'MH 04 AB 1234'),
        textCapitalization: TextCapitalization.characters,
        maxLength: 16,
      ),
      if (!isGate) _ExpectedAtField(onChanged: (d) => expectedAt = d),
      if (isGate) _GatePhotoField(onChanged: (p) => photoUrl = p),
    ],
    onSubmit: () async {
      created = await ref.read(towerRepositoryProvider).addVisitor(
            VisitorInput(
              name: name.text.trim(),
              type: type,
              purpose: purpose.text.trim().isEmpty ? null : purpose.text.trim(),
              phone: phone.text.trim().isEmpty ? null : Validators.normalizeIndianMobile(phone.text),
              expectedAt: expectedAt,
              flatId: flatId,
              vehicleNumber: vehicle.text.trim().isEmpty ? null : vehicle.text.trim(),
              arrival: isGate ? arrival : null,
              photoUrl: photoUrl,
            ),
          );
    },
  );
  if (saved != true) return;
  _refreshVisitors(ref);
  final visitor = created;
  if (isGate) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (arrival) {
          GateArrival.ask => l10n.visitorAskedFlat(name.text.trim()),
          GateArrival.checkIn => l10n.visitorLetIn(name.text.trim()),
          GateArrival.expected => l10n.visitorLogged,
        }),
      ),
    );
  } else {
    messenger.showSnackBar(SnackBar(content: Text(l10n.visitorAdded)));
    if (visitor?.passCode != null && context.mounted) await showGuestPass(context, visitor!);
  }
}

/// The guard's photo of the visitor (optional).
class _GatePhotoField extends StatefulWidget {
  const _GatePhotoField({required this.onChanged});

  final ValueChanged<String?> onChanged;

  @override
  State<_GatePhotoField> createState() => _GatePhotoFieldState();
}

class _GatePhotoFieldState extends State<_GatePhotoField> {
  String? _path;

  @override
  Widget build(BuildContext context) => PhotoField(
        path: _path,
        onChanged: (p) {
          setState(() => _path = p);
          widget.onChanged(p);
        },
      );
}

class _ChoiceField<T> extends StatefulWidget {
  const _ChoiceField({required this.initial, required this.options, required this.onChanged});

  final T initial;
  final List<(T, String, IconData)> options;
  final ValueChanged<T> onChanged;

  @override
  State<_ChoiceField<T>> createState() => _ChoiceFieldState<T>();
}

class _ChoiceFieldState<T> extends State<_ChoiceField<T>> {
  late T _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      segments: [
        for (final (value, label, icon) in widget.options)
          ButtonSegment(value: value, label: Text(label), icon: Icon(icon)),
      ],
      selected: {_value},
      showSelectedIcon: false,
      onSelectionChanged: (s) {
        setState(() => _value = s.single);
        widget.onChanged(s.single);
      },
    );
  }
}

/// Optional: today/tomorrow and a time.
class _ExpectedAtField extends StatefulWidget {
  const _ExpectedAtField({required this.onChanged});

  final ValueChanged<DateTime?> onChanged;

  @override
  State<_ExpectedAtField> createState() => _ExpectedAtFieldState();
}

class _ExpectedAtFieldState extends State<_ExpectedAtField> {
  DateTime? _value;

  Future<void> _pick() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _value ?? now,
      firstDate: DateUtils.dateOnly(now),
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_value ?? now));
    if (time == null) return;
    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => _value = picked);
    widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final value = _value;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: l10n.expectedAtField,
        contentPadding: const EdgeInsets.only(left: AppSpacing.lg),
        suffixIcon: value == null
            ? null
            : IconButton(
                tooltip: l10n.clearDate,
                onPressed: () {
                  setState(() => _value = null);
                  widget.onChanged(null);
                },
                icon: const Icon(Icons.close_rounded),
              ),
      ),
      child: InkWell(
        onTap: _pick,
        child: SizedBox(
          height: AppSpacing.minTapTarget,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              value == null ? l10n.optionalLabel : '${formatDayShort(context, value)}, ${formatTime(context, value)}',
            ),
          ),
        ),
      ),
    );
  }
}
