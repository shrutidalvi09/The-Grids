import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../notifications/data/push_service.dart';
import '../data/auth_providers.dart';
import '../domain/session.dart';

/// Holds the current [SessionState]. At launch it restores the saved session
/// (refresh token in the keystore) before the router decides where to go.
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    unawaited(Future.microtask(restore));
    return const SessionUnknown();
  }

  Future<void> restore() async {
    state = const SessionUnknown();
    try {
      final session = await ref.read(authRepositoryProvider).restoreSession();
      state = session == null ? const SignedOut() : SignedIn(session);
    } on ApiException catch (e) {
      state = e.code == ApiException.network ? const SessionRestoreFailed() : const SignedOut();
    } catch (_) {
      state = const SignedOut();
    }
  }

  /// Called by the OTP screen after a successful verification.
  void signedIn(AppSession session) => state = SignedIn(session);

  Future<void> switchTo(String membershipId) async {
    state = SignedIn(await ref.read(authRepositoryProvider).switchMembership(membershipId));
  }

  Future<void> signOut() async {
    // While still authenticated, so the server forgets this phone's push token.
    await ref.read(pushServiceProvider).stop();
    await ref.read(authRepositoryProvider).signOut();
    state = const SignedOut();
  }

  /// After editing the profile: same membership, fresh name/photo/email.
  void updated(AppSession session) {
    if (state is SignedIn) state = SignedIn(session);
  }

  /// The server ended the session (refresh token revoked or expired).
  void expire() {
    if (state is SignedIn) state = const SignedOut(expired: true);
  }
}

final sessionControllerProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

/// Convenience: the signed-in session, or `null`.
final currentSessionProvider = Provider<AppSession?>((ref) {
  final state = ref.watch(sessionControllerProvider);
  return state is SignedIn ? state.session : null;
});

/// The membership being acted as. Data providers watch this so they refetch
/// when the user signs in again or switches society/role.
final sessionKeyProvider = Provider<String?>(
  (ref) => ref.watch(currentSessionProvider.select((s) => s?.membership.id)),
);
