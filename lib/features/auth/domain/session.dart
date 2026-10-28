import 'package:flutter/foundation.dart';

import 'user_role.dart';

/// One society + role a person can act as.
@immutable
class MembershipSummary {
  const MembershipSummary({
    required this.id,
    required this.role,
    required this.societyId,
    required this.societyName,
    this.flatId,
    this.flatLabel,
  });

  final String id;
  final UserRole role;
  final String societyId;
  final String societyName;
  final String? flatId;

  /// e.g. "Tower-C, 502". Admins may not have a flat.
  final String? flatLabel;
}

/// The signed-in person and the membership they are currently acting as.
@immutable
class AppSession {
  const AppSession({
    required this.userId,
    required this.displayName,
    required this.phone,
    required this.membership,
    this.memberships = const [],
    this.email,
    this.photoPath,
  });

  final String userId;
  final String displayName;

  /// E.164, e.g. +919000000001.
  final String phone;
  final String? email;

  /// Server path of the profile photo (`/uploads/…`).
  final String? photoPath;
  final MembershipSummary membership;

  /// Everything the person can switch to (includes [membership]).
  final List<MembershipSummary> memberships;

  UserRole get role => membership.role;
  String get societyId => membership.societyId;
  String get societyName => membership.societyName;
  String? get flatLabel => membership.flatLabel;
  String get firstName => displayName.split(' ').first;
}

/// Auth state as the router sees it.
sealed class SessionState {
  const SessionState();
}

/// Restoring the previous session at launch.
final class SessionUnknown extends SessionState {
  const SessionUnknown();
}

/// Couldn't reach the server while restoring; the saved session is kept and
/// the splash screen offers a retry.
final class SessionRestoreFailed extends SessionState {
  const SessionRestoreFailed();
}

final class SignedOut extends SessionState {
  const SignedOut({this.expired = false});

  /// True when the server ended the session (show "please sign in again").
  final bool expired;
}

final class SignedIn extends SessionState {
  const SignedIn(this.session);

  final AppSession session;
}
