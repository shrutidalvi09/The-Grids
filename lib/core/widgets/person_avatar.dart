import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/uploads_api.dart';
import '../utils/formatters.dart';

/// Profile photo if there is one, otherwise coloured initials. The colour is
/// stable per name so the same person always looks the same.
class PersonAvatar extends ConsumerWidget {
  const PersonAvatar({super.key, required this.name, this.photoPath, this.radius = 20});

  final String name;
  final String? photoPath;
  final double radius;

  static const _palette = [
    Color(0xFF2E7D32),
    Color(0xFFF57C00),
    Color(0xFF1E88E5),
    Color(0xFF8E24AA),
    Color(0xFF00897B),
    Color(0xFFD81B60),
    Color(0xFF5D4037),
    Color(0xFF3949AB),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(photoUrlProvider(photoPath));
    final color = _palette[name.codeUnits.fold<int>(0, (a, b) => a + b) % _palette.length];
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: radius,
        backgroundColor: color,
        foregroundImage: url == null ? null : NetworkImage(url),
        child: Text(
          initialsOf(name),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: radius * 0.75),
        ),
      ),
    );
  }
}
