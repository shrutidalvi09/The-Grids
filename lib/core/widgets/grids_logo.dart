import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';

/// The Grids house mark, drawn as vectors so it stays sharp at any size and
/// adapts its wall colour to light/dark mode.
///
/// Redrawn from the design mockups; swap for the designer's SVG when available.
class GridsLogo extends StatelessWidget {
  const GridsLogo({super.key, this.width = 120});

  final double width;

  static const _aspect = _LogoPainter.designHeight / _LogoPainter.designWidth;

  @override
  Widget build(BuildContext context) {
    final grids = GridsColors.of(context);
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(width, width * _aspect),
        painter: _LogoPainter(
          walls: grids.logoWalls,
          roof: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// Logo + "The Grids" + tagline, as on the splash and sign-in screens.
class GridsWordmark extends StatelessWidget {
  const GridsWordmark({super.key, this.logoWidth = 140});

  final double logoWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Semantics(
      label: '${l10n.appTitle}. ${l10n.appTagline}',
      container: true,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GridsLogo(width: logoWidth),
            Text(
              l10n.appTitle,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              l10n.appTagline,
              style: theme.textTheme.bodySmall?.copyWith(
                color: GridsColors.of(context).slate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.walls, required this.roof});

  static const designWidth = 260.0;
  static const designHeight = 215.0;

  final Color walls;
  final Color roof;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / designWidth, size.height / designHeight);
    canvas
      ..save()
      ..translate(
        (size.width - designWidth * scale) / 2,
        (size.height - designHeight * scale) / 2,
      )
      ..scale(scale);

    // Roof: two tapered strokes.
    _taperedLine(canvas, const Offset(60, 10), const Offset(238, 92), 0.6, 5, roof);
    _taperedLine(canvas, const Offset(122, 43), const Offset(16, 129), 0.6, 4.5, roof);

    Paint stroke(double width) => Paint()
      ..color = walls
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Walls and floor.
    canvas
      ..drawLine(const Offset(62, 96), const Offset(62, 206), stroke(4.5))
      ..drawLine(const Offset(210, 80), const Offset(210, 203), stroke(4.5))
      ..drawLine(const Offset(46, 209), const Offset(212, 202), stroke(4.5))
      // The "T" and the figure leaning on it.
      ..drawLine(const Offset(118, 107), const Offset(150, 106), stroke(3))
      ..drawLine(const Offset(132, 107), const Offset(132, 206), stroke(3))
      ..drawLine(const Offset(132, 133), const Offset(160, 138), stroke(2.5))
      ..drawLine(const Offset(162, 141), const Offset(162, 205), stroke(2.5));

    // Window.
    canvas.drawRect(
      const Rect.fromLTWH(83, 129, 27, 27),
      Paint()..color = AppColors.logoWindow,
    );

    // Heart.
    canvas.drawPath(_heart(const Offset(162, 130), 9), Paint()..color = AppColors.logoHeart);

    // Sprout by the door.
    final sprout = Paint()
      ..color = roof
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const sparkCentre = Offset(226, 162);
    for (final angle in const [-150.0, -110.0, -70.0, -30.0, 10.0, 170.0]) {
      final rad = angle * math.pi / 180;
      final direction = Offset(math.cos(rad), math.sin(rad));
      canvas.drawLine(sparkCentre + direction * 3, sparkCentre + direction * 8, sprout);
    }
    canvas.drawPath(
      Path()
        ..moveTo(229, 177)
        ..lineTo(217, 186)
        ..lineTo(226, 190)
        ..lineTo(213, 202),
      sprout..strokeWidth = 3,
    );

    canvas.restore();
  }

  /// A line that grows from [startWidth] to [endWidth], like a brush stroke.
  void _taperedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    double startWidth,
    double endWidth,
    Color color,
  ) {
    final direction = end - start;
    final normal = Offset(-direction.dy, direction.dx) / direction.distance;
    final path = Path()
      ..moveTo((start + normal * startWidth / 2).dx, (start + normal * startWidth / 2).dy)
      ..lineTo((end + normal * endWidth / 2).dx, (end + normal * endWidth / 2).dy)
      ..lineTo((end - normal * endWidth / 2).dx, (end - normal * endWidth / 2).dy)
      ..lineTo((start - normal * startWidth / 2).dx, (start - normal * startWidth / 2).dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  Path _heart(Offset c, double w) => Path()
    ..moveTo(c.dx, c.dy + w * 0.45)
    ..cubicTo(c.dx - w * 1.1, c.dy - w * 0.15, c.dx - w * 0.45, c.dy - w, c.dx, c.dy - w * 0.4)
    ..cubicTo(c.dx + w * 0.45, c.dy - w, c.dx + w * 1.1, c.dy - w * 0.15, c.dx, c.dy + w * 0.45)
    ..close();

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) =>
      oldDelegate.walls != walls || oldDelegate.roof != roof;
}
