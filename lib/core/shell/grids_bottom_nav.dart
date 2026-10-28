import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'nav_destinations.dart';

/// Floating green pill navigation bar from the mockups: the selected tab
/// shows its label in orange, the others show a white icon only.
class GridsBottomNav extends StatelessWidget {
  const GridsBottomNav({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<NavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final grids = GridsColors.of(context);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Material(
          color: grids.navBar,
          shape: const StadiumBorder(),
          elevation: 3,
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    flex: i == selectedIndex ? 2 : 1,
                    child: _NavItem(
                      destination: destinations[i],
                      selected: i == selectedIndex,
                      activeColor: grids.navActive,
                      inactiveColor: grids.navInactive,
                      onTap: () => onSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : inactiveColor;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: Tooltip(
        message: destination.label,
        excludeFromSemantics: true,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(destination.icon, color: color, size: 28),
                  if (selected) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          destination.label,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
