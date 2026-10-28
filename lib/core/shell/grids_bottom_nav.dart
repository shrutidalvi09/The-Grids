import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'nav_destinations.dart';

/// Floating green pill navigation bar from the mockups. The selected tab is an
/// orange pill with its label (dark text, for contrast); the others show a
/// white icon only.
///
/// Switching tabs animates as one motion: the pill slides to the new tab while
/// the tabs resize, the label fades and slides in, and the icon pops slightly.
/// Animations are skipped when the system asks for reduced motion.
class GridsBottomNav extends StatelessWidget {
  const GridsBottomNav({super.key, required this.destinations, required this.selectedIndex, required this.onSelected});

  final List<NavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const duration = Duration(milliseconds: 360);
  static const curve = Curves.easeOutCubic;

  /// The selected tab's width relative to the others, so long labels
  /// ("Maintenance") fit inside the pill.
  static const _selectedShare = 2.4;

  /// Height of the bar and inset of the pill inside it.
  static const _height = 68.0;
  static const _pillInset = 14.0; // a 40 dp pill, as in the mockups

  @override
  Widget build(BuildContext context) {
    final grids = GridsColors.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final motion = reduceMotion ? Duration.zero : duration;

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
            height: _height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The selected tab takes a wider share of the width, the others one.
                final share = constraints.maxWidth / (destinations.length - 1 + _selectedShare);
                final pillLeft = share * selectedIndex;
                return Stack(
                  // The tab row fills the bar so items centre on the pill.
                  fit: StackFit.expand,
                  children: [
                    // One pill that slides between tabs (rather than one per tab
                    // fading in and out), so the motion reads as a single gesture.
                    AnimatedPositioned(
                      duration: motion,
                      curve: curve,
                      left: pillLeft + AppSpacing.xs,
                      width: share * _selectedShare - AppSpacing.xs * 2,
                      top: _pillInset,
                      bottom: _pillInset,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(shape: const StadiumBorder(), color: grids.navActive),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < destinations.length; i++)
                          AnimatedContainer(
                            duration: motion,
                            curve: curve,
                            width: share * (i == selectedIndex ? _selectedShare : 1),
                            alignment: Alignment.center,
                            child: _NavItem(
                              destination: destinations[i],
                              selected: i == selectedIndex,
                              inactiveColor: grids.navInactive,
                              duration: motion,
                              onTap: () {
                                if (i != selectedIndex) HapticFeedback.selectionClick();
                                onSelected(i);
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
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
    required this.inactiveColor,
    required this.duration,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final Color inactiveColor;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.ink : inactiveColor;
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w700);
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
            // Keeps the icon and label clear of the pill's rounded ends.
            child: AnimatedPadding(
              duration: duration,
              curve: GridsBottomNav.curve,
              padding: EdgeInsets.symmetric(horizontal: selected ? AppSpacing.md + AppSpacing.xs : 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Colour and a small "pop" as the tab becomes active.
                  AnimatedScale(
                    scale: selected ? 1.08 : 1,
                    duration: duration,
                    curve: Curves.easeOutBack,
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(end: color),
                      duration: duration,
                      builder: (context, value, _) => Icon(destination.icon, color: value, size: 24),
                    ),
                  ),
                  // The label grows in from the icon and fades/slides into place.
                  // (AnimatedSize can't take a zero duration, so reduced motion
                  // skips it.)
                  Flexible(
                    child: duration == Duration.zero
                        ? (selected
                              ? _Label(text: destination.label, style: labelStyle, duration: duration)
                              : const SizedBox.shrink())
                        : ClipRect(
                            child: AnimatedSize(
                              duration: duration,
                              curve: GridsBottomNav.curve,
                              alignment: Alignment.centerLeft,
                              child: selected
                                  ? _Label(text: destination.label, style: labelStyle, duration: duration)
                                  : const SizedBox.shrink(),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text, required this.style, required this.duration});

  final String text;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(8 * (1 - t), 0), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.xs),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(text, maxLines: 1, style: style),
        ),
      ),
    );
  }
}
