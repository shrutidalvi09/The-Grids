import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/phone_call.dart';
import '../../home/domain/home_models.dart';
import '../../home/presentation/home_providers.dart';
import '../data/gate_repository.dart';

/// App bar button on Home: asks once, then alerts the guards, admins and the
/// household.
class SosButton extends ConsumerWidget {
  const SosButton({super.key});

  Future<void> _raise(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final note = await showDialog<String>(context: context, builder: (_) => const _SosDialog());
    if (note == null) return; // cancelled
    unawaited(HapticFeedback.heavyImpact());
    try {
      await ref.read(gateRepositoryProvider).raiseSos(note: note.isEmpty ? null : note);
      ref.invalidate(homeProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.sosSent)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: l10n.sosButton,
      onPressed: () => _raise(context, ref),
      icon: Icon(Icons.sos_rounded, color: scheme.error),
    );
  }
}

/// "Send an emergency alert?" with an optional note. Returns the note ('' if
/// none), or null when cancelled.
class _SosDialog extends StatefulWidget {
  const _SosDialog();

  @override
  State<_SosDialog> createState() => _SosDialogState();
}

class _SosDialogState extends State<_SosDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(Icons.sos_rounded, color: scheme.error, size: 40),
      title: Text(l10n.sosConfirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.sosConfirmBody),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _note,
            maxLength: 120,
            decoration: InputDecoration(labelText: l10n.sosNoteField, hintText: l10n.sosNoteHint),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
          onPressed: () => Navigator.pop(context, _note.text.trim()),
          child: Text(l10n.sosSend),
        ),
      ],
    );
  }
}

/// Unresolved alerts on top of Home: who, which flat, when; call them or mark
/// the emergency handled.
class SosBanners extends ConsumerWidget {
  const SosBanners({super.key, required this.alerts});

  final List<ActiveSos> alerts;

  Future<void> _resolve(BuildContext context, WidgetRef ref, ActiveSos alert) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(gateRepositoryProvider).resolveSos(alert.id);
      ref.invalidate(homeProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.sosResolved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final alert in alerts)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Semantics(
              liveRegion: true,
              child: Card(
                color: AppColors.danger,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.sos_rounded, color: Colors.white, size: 32),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              l10n.sosActiveTitle(alert.flatLabel ?? l10n.sosNoFlat),
                              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.sosActiveBody(alert.raisedBy ?? '', formatTime(context, alert.createdAt)),
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          if (alert.raisedByPhone != null)
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.danger),
                              onPressed: () => callPhone(context, alert.raisedByPhone!),
                              icon: const Icon(Icons.call_rounded),
                              label: Text(l10n.callPerson(alert.raisedBy ?? '')),
                            ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                            ),
                            onPressed: () => _resolve(context, ref, alert),
                            icon: const Icon(Icons.check_rounded),
                            label: Text(l10n.sosMarkResolved),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
