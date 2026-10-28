import 'package:flutter/material.dart';

import '../../features/auth/domain/user_role.dart';
import '../l10n/l10n.dart';

class NavDestination {
  const NavDestination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// The five bottom tabs, in shell-branch order. Tenants see "Rent" where
/// everyone else sees "Maintenance".
List<NavDestination> navDestinations(AppLocalizations l10n, UserRole role) => [
      NavDestination(icon: Icons.home_rounded, label: l10n.navHome),
      NavDestination(icon: Icons.apartment_rounded, label: l10n.navTower),
      role == UserRole.tenant
          ? NavDestination(icon: Icons.payments_rounded, label: l10n.navRent)
          : NavDestination(icon: Icons.receipt_long_rounded, label: l10n.navMaintenance),
      NavDestination(icon: Icons.groups_rounded, label: l10n.navCommunity),
      NavDestination(icon: Icons.person_rounded, label: l10n.navProfile),
    ];
