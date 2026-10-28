import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_providers.dart';
import '../domain/auth_models.dart';
import '../domain/user_role.dart';

/// What the user has picked so far: society → role → phone → code.
@immutable
class SignInFlow {
  const SignInFlow({this.society, this.role, this.phone, this.challenge});

  final Society? society;
  final UserRole? role;

  /// As typed (without +91); the backend normalises it.
  final String? phone;
  final OtpChallenge? challenge;
}

class SignInFlowController extends Notifier<SignInFlow> {
  @override
  SignInFlow build() => const SignInFlow();

  void selectSociety(Society society) => state = SignInFlow(society: society);

  void selectRole(UserRole role) => state = SignInFlow(society: state.society, role: role);

  void codeSent(String phone, OtpChallenge challenge) =>
      state = SignInFlow(society: state.society, role: state.role, phone: phone, challenge: challenge);

  void reset() => state = const SignInFlow();
}

final signInFlowProvider = NotifierProvider<SignInFlowController, SignInFlow>(SignInFlowController.new);

/// Society search, debounced: typing quickly disposes the pending lookups.
final societySearchProvider = FutureProvider.autoDispose.family<List<Society>, String>((ref, query) async {
  if (query.isNotEmpty) {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!ref.mounted) return const [];
  }
  return ref.read(authRepositoryProvider).searchSocieties(query);
});
