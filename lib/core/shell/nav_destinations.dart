import 'package:flutter/material.dart';

import '../../features/auth/domain/user_role.dart';
import '../l10n/l10n.dart';

class NavDestination {
  const NavDestination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Which shell branches (0 Home … 4 Profile) a role has as tabs. Guards get
/// Gate (Home), Visitors (Tower) and Profile.
List<int> navBranches(UserRole role) => role == UserRole.guard ? const [0, 1, 4] : const [0, 1, 2, 3, 4];

/// The bottom tabs for [role], in the order of [navBranches].
List<NavDestination> navDestinations(AppLocalizations l10n, UserRole role) => role == UserRole.guard
    ? [
        NavDestination(icon: Icons.shield_rounded, label: l10n.navGate),
        NavDestination(icon: Icons.badge_rounded, label: l10n.navVisitors),
        NavDestination(icon: Icons.person_rounded, label: l10n.navProfile),
      ]
    : [
      NavDestination(icon: Icons.home_rounded, label: l10n.navHome),
      NavDestination(icon: Icons.apartment_rounded, label: l10n.navTower),
      role == UserRole.tenant
          ? NavDestination(icon: Icons.payments_rounded, label: l10n.navRent)
          : NavDestination(icon: Icons.receipt_long_rounded, label: l10n.navMaintenance),
      NavDestination(icon: Icons.groups_rounded, label: l10n.navCommunity),
      NavDestination(icon: Icons.person_rounded, label: l10n.navProfile),
    ];
