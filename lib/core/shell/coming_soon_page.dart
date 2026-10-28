import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../widgets/empty_state.dart';
import 'grids_page.dart';

/// Placeholder for a screen whose content lands in a later phase.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({
    super.key,
    required this.title,
    required this.icon,
    this.isTab = false,
  });

  final String title;
  final IconData icon;

  /// Tab pages show the menu button; pushed pages show a back button.
  final bool isTab;

  @override
  Widget build(BuildContext context) {
    return GridsPage(
      title: title,
      showMenu: isTab,
      body: EmptyState(
        icon: icon,
        title: context.l10n.comingSoonTitle,
        message: context.l10n.comingSoonBody,
      ),
    );
  }
}
