import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../tower/domain/tower_models.dart';

/// The QR on a white square with a quiet zone, readable in any chat app's
/// light or dark theme.
Future<Uint8List?> _qrPng(String code) async {
  const size = 720.0, margin = 48.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..drawRect(const Rect.fromLTWH(0, 0, size, size), Paint()..color = AppColors.white);
  canvas.translate(margin, margin);
  QrPainter(
    data: guestPassQrData(code),
    version: QrVersions.auto,
    gapless: true,
    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.ink),
    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.ink),
  ).paint(canvas, const Size.square(size - 2 * margin));
  final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List();
}

/// What the guard's scanner reads.
String guestPassQrData(String code) => 'grids:pass:$code';

/// The guest's one-time gate pass: a QR code and the digits, to show or share.
Future<void> showGuestPass(BuildContext context, Visitor visitor) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheet) => _GuestPassSheet(visitor: visitor),
  );
}

class _GuestPassSheet extends StatelessWidget {
  const _GuestPassSheet({required this.visitor});

  final Visitor visitor;

  Future<void> _share(BuildContext context) async {
    final l10n = context.l10n;
    final code = visitor.passCode!;
    final text = visitor.expectedAt == null
        ? l10n.guestPassShareText(visitor.name, code)
        : l10n.guestPassShareTextAt(visitor.name, code, '${formatDayShort(context, visitor.expectedAt!)}, ${formatTime(context, visitor.expectedAt!)}');
    // The QR as an image too, so the guest can show it at the gate.
    final files = <XFile>[];
    try {
      final png = await _qrPng(code);
      if (png != null) {
        final file = File('${(await getTemporaryDirectory()).path}/gate-pass-$code.png');
        await file.writeAsBytes(png, flush: true);
        files.add(XFile(file.path, mimeType: 'image/png'));
      }
    } catch (_) {
      // Sharing the code as text still works.
    }
    await SharePlus.instance.share(ShareParams(text: text, files: files.isEmpty ? null : files));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final code = visitor.passCode!;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.guestPassTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.guestPassFor(visitor.name), style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              label: l10n.guestPassQrLabel(code),
              image: true,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: AppColors.white, borderRadius: AppRadii.card),
                child: QrImageView(
                  data: guestPassQrData(code),
                  size: 200,
                  backgroundColor: AppColors.white,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.ink),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.ink),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SelectableText(
              '${code.substring(0, 3)} ${code.substring(3)}',
              style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 4),
              semanticsLabel: code.split('').join(' '),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.guestPassHint, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _share(context),
                icon: const Icon(Icons.share_rounded),
                label: Text(l10n.sharePass),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
