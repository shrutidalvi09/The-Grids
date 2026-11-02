import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../domain/profile_models.dart';
import '../profile_providers.dart';

/// Admin: choose a flat (shows who lives there, to avoid mistakes).
class FlatPicker extends ConsumerStatefulWidget {
  const FlatPicker({super.key, required this.onChanged, this.initial});

  final ValueChanged<String?> onChanged;
  final String? initial;

  @override
  ConsumerState<FlatPicker> createState() => _FlatPickerState();
}

class _FlatPickerState extends ConsumerState<FlatPicker> {
  late String? _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final flats = ref.watch(flatOptionsProvider).value ?? const <FlatOption>[];
    return DropdownButtonFormField<String>(
      initialValue: _value,
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.flatLabelField),
      items: [
        for (final f in flats)
          DropdownMenuItem(
            value: f.id,
            child: Text(
              f.occupants.isEmpty ? '${f.label} · ${l10n.flatVacant}' : '${f.label} · ${f.occupants.join(', ')}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      validator: (v) => v == null ? l10n.validationRequired : null,
      onChanged: (v) {
        setState(() => _value = v);
        widget.onChanged(v);
      },
    );
  }
}
