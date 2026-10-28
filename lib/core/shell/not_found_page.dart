import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';
import '../router/routes.dart';
import '../widgets/empty_state.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pageNotFoundTitle)),
      body: EmptyState(
        icon: Icons.explore_off_rounded,
        title: l10n.pageNotFoundTitle,
        actionLabel: l10n.goHome,
        onAction: () => context.go(AppRoutes.home),
      ),
    );
  }
}
