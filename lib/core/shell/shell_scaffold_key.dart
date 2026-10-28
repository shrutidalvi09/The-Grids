import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Key of the outer shell [Scaffold] that owns the drawer, so a tab page's
/// hamburger button can open a drawer that also covers the bottom nav.
final shellScaffoldKeyProvider = Provider<GlobalKey<ScaffoldState>>(
  (ref) => GlobalKey<ScaffoldState>(debugLabel: 'shell'),
);
