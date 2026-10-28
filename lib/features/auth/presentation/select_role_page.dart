import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/user_role.dart';
import 'sign_in_flow.dart';
import 'widgets/auth_layout.dart';

/// Step 2: Admin, Member (Owner) or Tenant.
class SelectRolePage extends ConsumerWidget {
  const SelectRolePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final society = ref.watch(signInFlowProvider).society;

    return AuthLayout(
      children: [
        AuthHeading(body: society?.name),
        const SizedBox(height: AppSpacing.xl),
        for (final role in UserRole.values) ...[
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(AppRadii.md)),
            ),
            onPressed: () {
              ref.read(signInFlowProvider.notifier).selectRole(role);
              context.push(AppRoutes.signInPhone);
            },
            child: Text(role.loginLabel(l10n)),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}
