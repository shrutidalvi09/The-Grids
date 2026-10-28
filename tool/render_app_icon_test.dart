// Renders the GridsLogo widget to the PNGs flutter_launcher_icons uses:
//   flutter test tool/render_app_icon_test.dart && dart run flutter_launcher_icons
// Kept out of test/ so the normal suite doesn't rewrite the icons.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_grids/core/theme/app_theme.dart';
import 'package:the_grids/core/widgets/grids_logo.dart';

Future<void> _render(WidgetTester tester, String path, {required Color background, required double logoShare}) async {
  const size = 1024.0;
  final key = GlobalKey();
  tester.view
    ..physicalSize = const Size(size, size)
    ..devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: background,
          child: Center(child: GridsLogo(width: size * logoShare)),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('render launcher icon sources', (tester) async {
    // Legacy/iOS icon: logo on white.
    await _render(tester, 'assets/icon/icon.png', background: Colors.white, logoShare: 0.78);
    // Adaptive foreground: transparent, inside Android's 66% safe zone.
    await _render(tester, 'assets/icon/icon_foreground.png', background: Colors.transparent, logoShare: 0.58);
    tester.view.reset();
  });
}
