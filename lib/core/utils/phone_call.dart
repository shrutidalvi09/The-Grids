import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';

/// Opens the dialler with [phone] filled in (the user still taps Call).
Future<void> callPhone(BuildContext context, String phone) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final opened = await launchUrl(Uri(scheme: 'tel', path: phone));
  if (!opened) messenger.showSnackBar(SnackBar(content: Text(l10n.cannotCall)));
}
