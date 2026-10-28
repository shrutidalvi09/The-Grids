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
import '../../home/presentation/home_providers.dart';
import '../data/tower_repository.dart';
import '../domain/tower_models.dart';
import 'tower_labels.dart';
import 'tower_providers.dart';

/// Admin: add a notice, or edit [notice].
class NoticeFormPage extends ConsumerStatefulWidget {
  const NoticeFormPage({super.key, this.notice});

  final Notice? notice;

  @override
  ConsumerState<NoticeFormPage> createState() => _NoticeFormPageState();
}

class _NoticeFormPageState extends ConsumerState<NoticeFormPage> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.notice?.title);
  late final _body = TextEditingController(text: widget.notice?.body);
  late String? _category = noticeCategories.contains(widget.notice?.category) ? widget.notice!.category : null;
  late DateTime? _scheduledAt = widget.notice?.scheduledAt;
  late bool _isAlert = widget.notice?.isAlert ?? false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_scheduledAt ?? now));
    if (time == null) return;
    setState(() => _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final input = NoticeInput(
      title: _title.text.trim(),
      body: _body.text.trim(),
      category: _category,
      scheduledAt: _scheduledAt,
      isAlert: _isAlert,
    );
    final repo = ref.read(towerRepositoryProvider);
    try {
      if (widget.notice == null) {
        await repo.createNotice(input);
      } else {
        await repo.updateNotice(widget.notice!.id, input);
      }
      ref
        ..invalidate(noticesProvider)
        ..invalidate(homeProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.noticeSaved)));
      context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = describeError(context.l10n, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final validators = Validators(l10n);
    return GridsPage(
      title: widget.notice == null ? l10n.addNotice : l10n.editNotice,
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
              validator: validators.required,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(labelText: l10n.fieldCategory),
              items: [
                for (final c in noticeCategories) DropdownMenuItem(value: c, child: Text(categoryLabel(l10n, c))),
              ],
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _body,
              decoration: InputDecoration(labelText: l10n.fieldDescription, alignLabelWithHint: true),
              textCapitalization: TextCapitalization.sentences,
              minLines: 4,
              maxLines: 10,
              maxLength: 2000,
              validator: validators.required,
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_rounded),
                title: Text(l10n.noticeScheduleLabel),
                subtitle: _scheduledAt == null
                    ? null
                    : Text('${formatDate(context, _scheduledAt!)} · ${formatTime(context, _scheduledAt!)}'),
                trailing: _scheduledAt == null
                    ? const Icon(Icons.chevron_right_rounded)
                    : IconButton(
                        tooltip: l10n.cancel,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() => _scheduledAt = null),
                      ),
                onTap: _pickSchedule,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: SwitchListTile(
                value: _isAlert,
                onChanged: (value) => setState(() => _isAlert = value),
                title: Text(l10n.noticeAlertLabel),
                subtitle: Text(l10n.noticeAlertHint),
              ),
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
