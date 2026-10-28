import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../network/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'section_header.dart';

/// A titled card on a dashboard (Home, Tower) with its own loading, error
/// and empty states, so one failing section doesn't blank the whole screen.
class AsyncSection<T> extends StatelessWidget {
  const AsyncSection({
    super.key,
    required this.title,
    required this.icon,
    required this.value,
    required this.builder,
    required this.emptyText,
    this.isEmpty,
    this.onViewAll,
    this.onRetry,
    this.action,
  });

  final String title;
  final IconData icon;
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final String emptyText;
  final bool Function(T data)? isEmpty;
  final VoidCallback? onViewAll;
  final VoidCallback? onRetry;

  /// Extra button under the card ("Add Notice", "Post Complaint").
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final slate = GridsColors.of(context).slate;
    final body = value.when(
      skipLoadingOnRefresh: true,
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
      ),
      error: (error, _) => ListTile(
        leading: const Icon(Icons.cloud_off_rounded),
        title: Text(describeError(l10n, error)),
        trailing: onRetry == null ? null : TextButton(onPressed: onRetry, child: Text(l10n.retry)),
      ),
      data: (data) => (isEmpty?.call(data) ?? false)
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(emptyText, style: TextStyle(color: slate)),
            )
          : builder(data),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title, icon: icon, actionLabel: onViewAll == null ? null : l10n.viewAll, onAction: onViewAll),
        Card(clipBehavior: Clip.antiAlias, child: body),
        if (action != null) Align(alignment: Alignment.centerRight, child: action),
      ],
    );
  }
}
