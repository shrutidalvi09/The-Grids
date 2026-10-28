import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';

/// Shared frame for the sign-in screens: wordmark on top, centred content,
/// back button when there is somewhere to go back to.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.children, this.footer});

  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: canPop ? AppBar(toolbarHeight: 48) : null,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: GridsWordmark(logoWidth: 150)),
                        const SizedBox(height: AppSpacing.xl),
                        ...children,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.lg),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

/// "Welcome to The Grids!" + optional orange subtitle ("ADMIN LOGIN").
class AuthHeading extends StatelessWidget {
  const AuthHeading({super.key, this.subtitle, this.body});

  final String? subtitle;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Semantics(
          header: true,
          child: Text(
            context.l10n.welcomeUser,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(color: GridsColors.of(context).slate),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
        if (body != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            body!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: GridsColors.of(context).slate),
          ),
        ],
      ],
    );
  }
}

/// Inline error under a form, announced to screen readers.
class AuthError extends StatelessWidget {
  const AuthError(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: color, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message!, style: TextStyle(color: color))),
          ],
        ),
      ),
    );
  }
}
