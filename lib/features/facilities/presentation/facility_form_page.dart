import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/photo_field.dart';
import '../../../core/widgets/widgets.dart';
import '../../home/presentation/home_providers.dart';
import '../data/facilities_repository.dart';
import '../domain/facility_models.dart';
import 'facility_providers.dart';

/// Admin: add a facility, or edit [facility].
class FacilityFormPage extends ConsumerStatefulWidget {
  const FacilityFormPage({super.key, this.facility});

  final Facility? facility;

  static const slotLengths = [30, 45, 60, 90, 120, 180];

  @override
  ConsumerState<FacilityFormPage> createState() => _FacilityFormPageState();
}

class _FacilityFormPageState extends ConsumerState<FacilityFormPage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.facility?.name);
  late final _description = TextEditingController(text: widget.facility?.description);
  late final _capacity = TextEditingController(text: widget.facility?.capacity?.toString());
  late String? _photoPath = widget.facility?.photoPath;
  late TimeOfDay _open = _parse(widget.facility?.openTime ?? '06:00');
  late TimeOfDay _close = _parse(widget.facility?.closeTime ?? '22:00');
  late int _slotLength = FacilityFormPage.slotLengths.contains(widget.facility?.maxDurationMins)
      ? widget.facility!.maxDurationMins
      : 60;
  bool _saving = false;
  String? _error;

  static TimeOfDay _parse(String hhmm) {
    final [h, m] = hhmm.split(':').map(int.parse).toList();
    return TimeOfDay(hour: h, minute: m);
  }

  static String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool opening) async {
    final picked = await showTimePicker(context: context, initialTime: opening ? _open : _close);
    if (picked != null) setState(() => opening ? _open = picked : _close = picked);
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!_form.currentState!.validate()) return;
    final minutesOpen = (_close.hour * 60 + _close.minute) - (_open.hour * 60 + _open.minute);
    if (minutesOpen < _slotLength) {
      setState(() => _error = l10n.facilityHoursTooShort);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final input = FacilityInput(
      name: _name.text.trim(),
      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      photoPath: _photoPath,
      openTime: _format(_open),
      closeTime: _format(_close),
      maxDurationMins: _slotLength,
      capacity: int.tryParse(_capacity.text),
    );
    final repo = ref.read(facilitiesRepositoryProvider);
    try {
      if (widget.facility == null) {
        await repo.create(input);
      } else {
        await repo.update(widget.facility!.id, input);
      }
      ref
        ..invalidate(facilitiesProvider)
        ..invalidate(homeProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.facilitySaved)));
      context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = describeError(l10n, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final validators = Validators(l10n);
    String show(TimeOfDay t) => formatTime(context, DateTime(2000, 1, 1, t.hour, t.minute));

    return GridsPage(
      title: widget.facility == null ? l10n.addFacility : l10n.editFacility,
      showMenu: false,
      showNotifications: false,
      body: Form(
        key: _form,
        child: ListView(
          padding: AppSpacing.pagePadding,
          children: [
            PhotoField(path: _photoPath, onChanged: (path) => setState(() => _photoPath = path)),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.facilityNameLabel),
              textCapitalization: TextCapitalization.words,
              maxLength: 60,
              validator: (v) => validators.required(v) ?? (v!.trim().length < 2 ? l10n.validationTooShort : null),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _description,
              decoration: InputDecoration(labelText: l10n.fieldDescription, alignLabelWithHint: true),
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 5,
              maxLength: 500,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: ListTile(
                      title: Text(l10n.openTimeLabel),
                      subtitle: Text(show(_open)),
                      onTap: () => _pickTime(true),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Card(
                    child: ListTile(
                      title: Text(l10n.closeTimeLabel),
                      subtitle: Text(show(_close)),
                      onTap: () => _pickTime(false),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<int>(
              initialValue: _slotLength,
              decoration: InputDecoration(labelText: l10n.slotLengthLabel),
              items: [
                for (final m in FacilityFormPage.slotLengths) DropdownMenuItem(value: m, child: Text(l10n.minutes(m))),
              ],
              onChanged: (value) => setState(() => _slotLength = value!),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _capacity,
              decoration: InputDecoration(labelText: l10n.capacityFieldLabel, helperText: l10n.capacityHint),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
              validator: (v) => v == null || v.isEmpty || (int.tryParse(v) ?? 0) >= 1 ? null : l10n.validationAmount,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(label: l10n.save, isLoading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
