import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import 'empty_state.dart';

/// Renders loading, error (with retry) and data states for an [AsyncValue].
/// Pass [isEmpty] + [empty] to show an empty state for empty collections.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.isEmpty,
    this.empty,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final bool Function(T data)? isEmpty;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      data: (result) {
        if (empty != null && (isEmpty?.call(result) ?? false)) return empty!;
        return data(result);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: context.l10n.errorGeneric,
        actionLabel: onRetry == null ? null : context.l10n.retry,
        onAction: onRetry,
      ),
    );
  }
}
