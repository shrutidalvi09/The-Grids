import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Asks "Are you sure?" and resolves to true only if the user confirms.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? message,
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialog) {
      final scheme = Theme.of(dialog).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: Text(context.l10n.cancel)),
          FilledButton(
            style: destructive ? FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError) : null,
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
