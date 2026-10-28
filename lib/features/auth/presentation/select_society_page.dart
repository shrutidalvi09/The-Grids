import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/session.dart';
import 'session_controller.dart';
import 'sign_in_flow.dart';
import 'widgets/auth_layout.dart';

/// Step 1: pick the society.
class SelectSocietyPage extends ConsumerStatefulWidget {
  const SelectSocietyPage({super.key});

  @override
  ConsumerState<SelectSocietyPage> createState() => _SelectSocietyPageState();
}

class _SelectSocietyPageState extends ConsumerState<SelectSocietyPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final results = ref.watch(societySearchProvider(_query));
    final session = ref.watch(sessionControllerProvider);

    return AuthLayout(
      footer: Text(
        l10n.newToGrids,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(color: GridsColors.of(context).slate),
      ),
      children: [
        if (session case SignedOut(expired: true)) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_clock_rounded),
              title: Text(l10n.sessionExpired),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Semantics(
          header: true,
          child: Text(l10n.selectSocietyTitle, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          decoration: InputDecoration(
            hintText: l10n.searchSocietyHint,
            prefixIcon: const Icon(Icons.search_rounded),
          ),
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _query = value.trim()),
        ),
        const SizedBox(height: AppSpacing.md),
        results.when(
          skipLoadingOnRefresh: false,
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Column(
            children: [
              AuthError(describeError(l10n, error)),
              TextButton(
                onPressed: () => ref.invalidate(societySearchProvider(_query)),
                child: Text(l10n.retry),
              ),
            ],
          ),
          data: (societies) => societies.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(l10n.noSocietiesFound, textAlign: TextAlign.center),
                )
              : Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final society in societies)
                        ListTile(
                          leading: const Icon(Icons.apartment_rounded),
                          title: Text(society.name),
                          subtitle: society.city == null ? null : Text(society.city!),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            ref.read(signInFlowProvider.notifier).selectSociety(society);
                            context.push(AppRoutes.signInRole);
                          },
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
