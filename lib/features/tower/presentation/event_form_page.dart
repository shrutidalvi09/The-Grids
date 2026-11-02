import 'package:flutter/material.dart';
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
import '../data/tower_repository.dart';
import '../domain/tower_models.dart';
import 'tower_providers.dart';

/// Admin: add a society event (residents are notified), or edit [event].
class EventFormPage extends ConsumerStatefulWidget {
  const EventFormPage({super.key, this.event});

  final SocietyEvent? event;

  @override
  ConsumerState<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends ConsumerState<EventFormPage> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.event?.title);
  late final _location = TextEditingController(text: widget.event?.location);
  late final _description = TextEditingController(text: widget.event?.description);
  late String? _photoPath = widget.event?.imagePath;
  late DateTime _date = DateUtils.dateOnly(widget.event?.startsAt ?? DateTime.now().add(const Duration(days: 1)));
  late TimeOfDay _start = TimeOfDay.fromDateTime(widget.event?.startsAt ?? DateTime(2000, 1, 1, 18));
  late TimeOfDay? _end = widget.event?.endsAt == null ? null : TimeOfDay.fromDateTime(widget.event!.endsAt!);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  DateTime _at(TimeOfDay t) => DateTime(_date.year, _date.month, _date.day, t.hour, t.minute);

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(context: context, initialTime: start ? _start : (_end ?? _start));
    if (picked != null) setState(() => start ? _start = picked : _end = picked);
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!_form.currentState!.validate()) return;
    final startsAt = _at(_start);
    final endsAt = _end == null ? null : _at(_end!);
    if (endsAt != null && !endsAt.isAfter(startsAt)) {
      setState(() => _error = l10n.endBeforeStart);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final input = EventInput(
      title: _title.text.trim(),
      location: _location.text.trim(),
      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      imagePath: _photoPath,
      startsAt: startsAt,
      endsAt: endsAt,
    );
    final repo = ref.read(towerRepositoryProvider);
    try {
      if (widget.event == null) {
        await repo.createEvent(input);
      } else {
        await repo.updateEvent(widget.event!.id, input);
      }
      ref
        ..invalidate(eventsProvider)
        ..invalidate(homeProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.eventSaved)));
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
      title: widget.event == null ? l10n.addEvent : l10n.editEvent,
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
              controller: _title,
              decoration: InputDecoration(labelText: l10n.fieldTitle),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 100,
              validator: (v) => validators.required(v) ?? (v!.trim().length < 3 ? l10n.validationTooShort : null),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _location,
              decoration: InputDecoration(labelText: l10n.venueLabel),
              textCapitalization: TextCapitalization.words,
              maxLength: 80,
              validator: (v) => validators.required(v) ?? (v!.trim().length < 2 ? l10n.validationTooShort : null),
            ),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_rounded),
                title: Text(l10n.eventDateLabel),
                subtitle: Text(formatDate(context, _date)),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: ListTile(title: Text(l10n.startTimeLabel), subtitle: Text(show(_start)), onTap: () => _pickTime(true)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Card(
                    child: ListTile(
                      title: Text(l10n.endTimeLabel),
                      subtitle: Text(_end == null ? l10n.optionalLabel : show(_end!)),
                      onTap: () => _pickTime(false),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _description,
              decoration: InputDecoration(labelText: l10n.fieldDescription, alignLabelWithHint: true),
              textCapitalization: TextCapitalization.sentences,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(label: l10n.save, isLoading: _saving, onPressed: _save),
            if (widget.event == null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.eventNotifyNote, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
