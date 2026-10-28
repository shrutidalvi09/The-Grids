import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../network/api_exception.dart';
import '../theme/app_spacing.dart';
import 'primary_button.dart';

/// A modal bottom sheet holding a validated form with a title, close button
/// and submit button. Closes itself after [onSubmit] completes.
///
/// ```dart
/// await BottomSheetForm.show(
///   context,
///   title: 'Add Notice',
///   submitLabel: 'Add',
///   fields: [TextFormField(validator: validators.required)],
///   onSubmit: () => repo.addNotice(...),
/// );
/// ```
class BottomSheetForm extends StatefulWidget {
  const BottomSheetForm({
    super.key,
    required this.title,
    required this.fields,
    required this.submitLabel,
    required this.onSubmit,
  });

  final String title;
  final List<Widget> fields;
  final String submitLabel;
  final Future<void> Function() onSubmit;

  /// Returns `true` if the form was submitted, `null` if dismissed.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required List<Widget> fields,
    required String submitLabel,
    required Future<void> Function() onSubmit,
  }) {
    return showModalBottomSheet<bool>(
      useRootNavigator: true, // above the bottom nav bar
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BottomSheetForm(
        title: title,
        fields: fields,
        submitLabel: submitLabel,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<BottomSheetForm> createState() => _BottomSheetFormState();
}

class _BottomSheetFormState extends State<BottomSheetForm> {
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      // Keep the sheet open with what the user typed.
      if (mounted) setState(() => _error = describeError(context.l10n, e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ),
                ),
                const CloseButton(),
              ],
            ),
            const Divider(),
            const SizedBox(height: AppSpacing.lg),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final field in widget.fields) ...[
                      field,
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ],
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: widget.submitLabel,
              isLoading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
