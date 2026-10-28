import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';
import 'community_providers.dart';

/// Admin: post a club announcement (optionally an event with date, time and
/// venue), or edit [announcement].
class AnnouncementFormPage extends ConsumerStatefulWidget {
  const AnnouncementFormPage({super.key, required this.communityId, this.announcement});

  final String communityId;
  final Announcement? announcement;

  @override
  ConsumerState<AnnouncementFormPage> createState() => _AnnouncementFormPageState();
}

class _AnnouncementFormPageState extends ConsumerState<AnnouncementFormPage> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.announcement?.title);
  late final _body = TextEditingController(text: widget.announcement?.body);
  late final _venue = TextEditingController(text: widget.announcement?.venue);
  late DateTime? _date = widget.announcement?.eventAt == null ? null : DateUtils.dateOnly(widget.announcement!.eventAt!);
  late TimeOfDay? _start = _timeOf(widget.announcement?.eventAt);
  late TimeOfDay? _end = _timeOf(widget.announcement?.endsAt);
  bool _saving = false;
  String? _error;

  static TimeOfDay? _timeOf(DateTime? d) => d == null ? null : TimeOfDay.fromDateTime(d);

  static DateTime? _at(DateTime? date, TimeOfDay? time) =>
      date == null || time == null ? date : DateTime(date.year, date.month, date.day, time.hour, time.minute);

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _venue.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: today.subtract(const Duration(days: 30)),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (start ? _start : _end) ?? _start ?? const TimeOfDay(hour: 18, minute: 0),
    );
    if (picked != null) setState(() => start ? _start = picked : _end = picked);
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!_form.currentState!.validate()) return;
    if (_date != null && _start == null) {
      setState(() => _error = l10n.startTimeRequired);
      return;
    }
    final eventAt = _at(_date, _start);
    final endsAt = _end == null || _date == null ? null : _at(_date, _end);
    if (endsAt != null && (eventAt == null || _start == null || !endsAt.isAfter(eventAt))) {
      setState(() => _error = l10n.endBeforeStart);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final input = AnnouncementInput(
      title: _title.text.trim(),
      body: _body.text.trim(),
      eventAt: eventAt,
      endsAt: endsAt,
      venue: _venue.text.trim().isEmpty ? null : _venue.text.trim(),
    );
    final repo = ref.read(communityRepositoryProvider);
    try {
      final existing = widget.announcement;
      if (existing == null) {
        await repo.createAnnouncement(widget.communityId, input);
      } else {
        await repo.updateAnnouncement(existing.id, input);
      }
      ref
        ..invalidate(communityProvider(widget.communityId))
        ..invalidate(communitiesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.announcementSaved)));
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
    String showTime(TimeOfDay? t) => t == null ? '—' : formatTime(context, DateTime(2000, 1, 1, t.hour, t.minute));

    return GridsPage(
      title: widget.announcement == null ? l10n.addAnnouncement : l10n.editAnnouncement,
      showMenu: false,
      showNotifications: false,
      body: Form(
        key: _form,
        child: ListView(
          padding: AppSpacing.pagePadding,
          children: [
            TextFormField(
              controller: _title,
              decoration: InputDecoration(labelText: l10n.fieldTitle),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 120,
              validator: (v) => validators.required(v) ?? (v!.trim().length < 3 ? l10n.validationTooShort : null),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _body,
              decoration: InputDecoration(labelText: l10n.fieldDescription, alignLabelWithHint: true),
              textCapitalization: TextCapitalization.sentences,
              minLines: 4,
              maxLines: 10,
              maxLength: 2000,
              validator: validators.required,
            ),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_rounded),
                title: Text(l10n.eventDateLabel),
                subtitle: Text(_date == null ? l10n.optionalLabel : formatDate(context, _date!)),
                onTap: _pickDate,
                trailing: _date == null
                    ? null
                    : IconButton(
                        tooltip: l10n.clearDate,
                        onPressed: () => setState(() {
                          _date = null;
                          _start = null;
                          _end = null;
                        }),
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            if (_date != null)
              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: ListTile(
                        title: Text(l10n.startTimeLabel),
                        subtitle: Text(showTime(_start)),
                        onTap: () => _pickTime(true),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Card(
                      child: ListTile(
                        title: Text(l10n.endTimeLabel),
                        subtitle: Text(showTime(_end)),
                        onTap: () => _pickTime(false),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _venue,
              decoration: InputDecoration(labelText: l10n.venueLabel),
              textCapitalization: TextCapitalization.words,
              maxLength: 80,
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
