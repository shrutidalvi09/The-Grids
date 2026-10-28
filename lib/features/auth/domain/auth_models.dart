import 'package:flutter/foundation.dart';

@immutable
class Society {
  const Society({required this.id, required this.name, this.city});

  final String id;
  final String name;
  final String? city;
}

/// A code has been sent; verify it against [challengeId].
@immutable
class OtpChallenge {
  const OtpChallenge({
    required this.challengeId,
    required this.expiresIn,
    required this.resendIn,
    this.devCode,
  });

  final String challengeId;
  final Duration expiresIn;
  final Duration resendIn;

  /// Only present when the dev backend echoes codes (never in production).
  final String? devCode;
}
