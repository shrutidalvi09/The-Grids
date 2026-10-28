import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/session.dart';
import 'session_controller.dart';

/// Shown while the saved session is restored. If the server can't be reached
/// the session is kept and the user can retry.
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failed = ref.watch(sessionControllerProvider) is SessionRestoreFailed;
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GridsWordmark(logoWidth: 180),
                const SizedBox(height: AppSpacing.xxl),
                if (failed) ...[
                  Text(l10n.errorNetwork, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: () => ref.read(sessionControllerProvider.notifier).restore(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l10n.retry),
                  ),
                ] else
                  const SizedBox.square(dimension: 32, child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
