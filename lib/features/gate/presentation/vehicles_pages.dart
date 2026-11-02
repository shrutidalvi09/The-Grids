import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/phone_call.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/session_controller.dart';
import '../../profile/presentation/widgets/flat_picker.dart';
import '../data/gate_repository.dart';
import '../domain/gate_models.dart';
import 'gate_labels.dart';
import 'gate_providers.dart';

/// Residents: their flat's cars and bikes. Admins: every vehicle, with
/// parking slots to assign.
class VehiclesPage extends ConsumerWidget {
  const VehiclesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isAdmin = ref.watch(currentSessionProvider)?.role == UserRole.admin;
    return GridsPage(
      title: l10n.vehiclesTitle,
      showMenu: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddVehicle(context, ref, isAdmin: isAdmin),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.addVehicle),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(vehiclesProvider.future),
        child: AsyncValueView(
          value: ref.watch(vehiclesProvider),
          onRetry: () => ref.invalidate(vehiclesProvider),
          isEmpty: (v) => v.isEmpty,
          empty: EmptyState(icon: Icons.directions_car_rounded, title: l10n.noVehicles, message: l10n.vehiclesHint),
          data: (vehicles) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
            itemCount: vehicles.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => Card(
              clipBehavior: Clip.antiAlias,
              child: VehicleTile(
                vehicle: vehicles[i],
                showFlat: isAdmin,
                onTap: () => _showVehicleActions(context, ref, vehicles[i], isAdmin: isAdmin),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VehicleTile extends StatelessWidget {
  const VehicleTile({super.key, required this.vehicle, this.showFlat = false, this.onTap});

  final Vehicle vehicle;
  final bool showFlat;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final v = vehicle;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      leading: CircleAvatar(child: Icon(vehicleIcon(v.type))),
      title: Text(v.displayNumber, style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
      subtitle: Text(
        [
          v.description ?? vehicleTypeLabel(l10n, v.type),
          if (showFlat && v.flatLabel != null) v.flatLabel!,
        ].join(' · '),
      ),
      trailing: StatusChip(
        label: v.parkingSlot == null ? l10n.noSlot : l10n.slotLabel(v.parkingSlot!),
        tone: v.parkingSlot == null ? StatusTone.neutral : StatusTone.info,
      ),
      onTap: onTap,
    );
  }
}

Future<void> _showAddVehicle(BuildContext context, WidgetRef ref, {required bool isAdmin}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final number = TextEditingController();
  final description = TextEditingController();
  var type = VehicleType.car;
  String? flatId;

  final saved = await BottomSheetForm.show(
    context,
    title: l10n.addVehicle,
    submitLabel: l10n.add,
    fields: [
      DropdownButtonFormField<VehicleType>(
        initialValue: type,
        decoration: InputDecoration(labelText: l10n.vehicleTypeField),
        items: [
          for (final t in VehicleType.values)
            DropdownMenuItem(
              value: t,
              child: Row(children: [Icon(vehicleIcon(t)), const SizedBox(width: AppSpacing.sm), Text(vehicleTypeLabel(l10n, t))]),
            ),
        ],
        onChanged: (v) => type = v ?? type,
      ),
      TextFormField(
        controller: number,
        decoration: InputDecoration(labelText: l10n.vehicleNumberField, hintText: 'MH 04 AB 1234'),
        textCapitalization: TextCapitalization.characters,
        maxLength: 16,
        validator: (v) {
          final n = (v ?? '').toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
          return RegExp(r'^[A-Z0-9]{4,12}$').hasMatch(n) ? null : l10n.vehicleNumberInvalid;
        },
      ),
      TextFormField(
        controller: description,
        decoration: InputDecoration(labelText: l10n.vehicleDescriptionField, hintText: l10n.vehicleDescriptionHint),
        textCapitalization: TextCapitalization.words,
        maxLength: 40,
      ),
      if (isAdmin) FlatPicker(onChanged: (id) => flatId = id),
    ],
    onSubmit: () => ref.read(gateRepositoryProvider).addVehicle(
          VehicleInput(
            number: number.text,
            type: type,
            description: description.text.trim().isEmpty ? null : description.text.trim(),
            flatId: flatId,
          ),
        ),
  );
  if (saved == true) {
    ref.invalidate(vehiclesProvider);
    messenger.showSnackBar(SnackBar(content: Text(l10n.vehicleAdded)));
  }
}

Future<void> _showVehicleActions(BuildContext context, WidgetRef ref, Vehicle v, {required bool isAdmin}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(gateRepositoryProvider);

  Future<void> run(Future<void> Function() action, String done) async {
    try {
      await action();
      ref.invalidate(vehiclesProvider);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    }
  }

  final action = await showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VehicleTile(vehicle: v, showFlat: isAdmin),
          const Divider(),
          if (isAdmin)
            ListTile(
              leading: const Icon(Icons.local_parking_rounded),
              title: Text(l10n.assignSlot),
              onTap: () => Navigator.pop(sheet, 'slot'),
            ),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: Theme.of(sheet).colorScheme.error),
            title: Text(l10n.removeVehicle, style: TextStyle(color: Theme.of(sheet).colorScheme.error)),
            onTap: () => Navigator.pop(sheet, 'remove'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  switch (action) {
    case 'slot':
      final slot = await _askSlot(context, v.parkingSlot);
      if (slot != null) await run(() => repo.setParkingSlot(v.id, slot.isEmpty ? null : slot), l10n.slotSaved);
    case 'remove':
      final ok = await confirmAction(
        context,
        title: l10n.removeVehicleConfirm(v.displayNumber),
        confirmLabel: l10n.remove,
        destructive: true,
      );
      if (ok) await run(() => repo.removeVehicle(v.id), l10n.vehicleRemoved);
  }
}

/// Returns the new slot, '' to free it, or null if cancelled.
Future<String?> _askSlot(BuildContext context, String? current) =>
    showDialog<String>(context: context, builder: (_) => _SlotDialog(current: current));

class _SlotDialog extends StatefulWidget {
  const _SlotDialog({required this.current});

  final String? current;

  @override
  State<_SlotDialog> createState() => _SlotDialogState();
}

class _SlotDialogState extends State<_SlotDialog> {
  late final _slot = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _slot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.assignSlot),
      content: TextField(
        controller: _slot,
        autofocus: true,
        maxLength: 20,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(labelText: l10n.parkingSlotField, hintText: 'B1-23'),
      ),
      actions: [
        if (widget.current != null) TextButton(onPressed: () => Navigator.pop(context, ''), child: Text(l10n.freeSlot)),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, _slot.text.trim()), child: Text(l10n.save)),
      ],
    );
  }
}

/// The gate: "whose car is this?" Search by part of the number; call the flat.
class VehicleSearchPage extends ConsumerStatefulWidget {
  const VehicleSearchPage({super.key});

  @override
  ConsumerState<VehicleSearchPage> createState() => _VehicleSearchPageState();
}

class _VehicleSearchPageState extends ConsumerState<VehicleSearchPage> {
  Timer? _debounce;
  String _query = '';
  Future<List<Vehicle>>? _results;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final q = value.replaceAll(RegExp(r'\s'), '');
      setState(() {
        _query = q;
        _results = q.length < 2 ? null : ref.read(gateRepositoryProvider).searchVehicles(q);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GridsPage(
      title: l10n.findVehicleTitle,
      showMenu: false,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          TextField(
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              labelText: l10n.vehicleNumberField,
              hintText: l10n.findVehicleHint,
            ),
            onChanged: _onChanged,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_results == null)
            EmptyState(icon: Icons.directions_car_rounded, title: l10n.findVehicleTitle, message: l10n.findVehicleHint)
          else
            FutureBuilder<List<Vehicle>>(
              key: ValueKey(_query),
              future: _results,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.xl), child: CircularProgressIndicator()));
                }
                if (snap.hasError) return EmptyState(icon: Icons.cloud_off_rounded, title: describeError(l10n, snap.error!));
                final found = snap.data!;
                if (found.isEmpty) return EmptyState(icon: Icons.search_off_rounded, title: l10n.noVehicleFound(_query));
                return Column(
                  children: [
                    for (final v in found)
                      Card(
                        child: Column(
                          children: [
                            VehicleTile(vehicle: v, showFlat: true),
                            for (final c in v.contacts)
                              ListTile(
                                leading: const Icon(Icons.call_rounded),
                                title: Text(c.name),
                                subtitle: Text(formatPhone(c.phone)),
                                onTap: () => callPhone(context, c.phone),
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
