import 'package:flutter/material.dart';

/// Full-width orange pill button. Shows a spinner and ignores taps while
/// [isLoading] is true.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final child = isLoading
        ? SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.onSecondaryContainer),
          )
        : Text(label);

    return Semantics(
      label: isLoading ? label : null,
      child: icon == null || isLoading
          ? FilledButton(onPressed: isLoading ? null : onPressed, child: child)
          : FilledButton.icon(onPressed: onPressed, icon: Icon(icon), label: child),
    );
  }
}
