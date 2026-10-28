import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';
import 'community_providers.dart';

/// Admin: ask the society a question with 2–6 choices.
class PollFormPage extends ConsumerStatefulWidget {
  const PollFormPage({super.key});

  static const minOptions = 2;
  static const maxOptions = 6;

  @override
  ConsumerState<PollFormPage> createState() => _PollFormPageState();
}

class _PollFormPageState extends ConsumerState<PollFormPage> {
  final _form = GlobalKey<FormState>();
  final _question = TextEditingController();
  final _options = [TextEditingController(), TextEditingController()];
  DateTime? _closesOn;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _closesOn ?? today.add(const Duration(days: 7)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _closesOn = picked);
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(communityRepositoryProvider).createPoll(
            PollInput(
              question: _question.text.trim(),
              options: [for (final c in _options) c.text.trim()],
              // Open through the end of the chosen day.
              closesAt: _closesOn == null ? null : DateTime(_closesOn!.year, _closesOn!.month, _closesOn!.day, 23, 59),
            ),
          );
      ref.invalidate(pollsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.pollCreated)));
      context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = describeError(l10n, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateOption(int index, String? value) {
    final l10n = context.l10n;
    final text = value?.trim() ?? '';
    if (text.isEmpty) return l10n.validationRequired;
    final duplicate = _options.indexed.any((e) => e.$1 < index && e.$2.text.trim().toLowerCase() == text.toLowerCase());
    return duplicate ? l10n.validationDuplicateOption : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final validators = Validators(l10n);
    final slate = GridsColors.of(context).slate;

    return GridsPage(
      title: l10n.newPoll,
      showMenu: false,
      showNotifications: false,
      body: Form(
        key: _form,
        child: ListView(
          padding: AppSpacing.pagePadding,
          children: [
            TextFormField(
              controller: _question,
              decoration: InputDecoration(labelText: l10n.pollQuestionLabel),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 200,
              minLines: 1,
              maxLines: 3,
              validator: (v) => validators.required(v) ?? (v!.trim().length < 5 ? l10n.validationTooShort : null),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final (index, controller) in _options.indexed)
              Padding(
                key: ObjectKey(controller),
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: controller,
                        decoration: InputDecoration(labelText: l10n.pollOptionLabel(index + 1)),
                        textCapitalization: TextCapitalization.sentences,
                        maxLength: 60,
                        validator: (v) => _validateOption(index, v),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.removeOption,
                      onPressed: _options.length > PollFormPage.minOptions
                          ? () => setState(() => _options.removeAt(index).dispose())
                          : null,
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                  ],
                ),
              ),
            if (_options.length < PollFormPage.maxOptions)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _options.add(TextEditingController())),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.addOption),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_rounded),
                title: Text(l10n.pollClosesLabel),
                subtitle: Text(_closesOn == null ? l10n.pollNoEnd : formatDate(context, _closesOn!)),
                onTap: _pickDate,
                trailing: _closesOn == null
                    ? null
                    : IconButton(
                        tooltip: l10n.clearDate,
                        onPressed: () => setState(() => _closesOn = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(label: l10n.createPoll, isLoading: _saving, onPressed: _save),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.pollNotifyNote, style: TextStyle(color: slate), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
