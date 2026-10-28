import 'auth_models.dart';
import 'session.dart';
import 'user_role.dart';

/// Phone-OTP sign-in and session lifecycle. Methods throw `ApiException`.
abstract interface class AuthRepository {
  Future<List<Society>> searchSocieties(String query);

  /// Sends a code if [phone] is registered for that society and role.
  Future<OtpChallenge> requestOtp({
    required String phone,
    required String societyId,
    required UserRole role,
  });

  /// Verifies the code, stores the session and returns it.
  Future<AppSession> verifyOtp({required String challengeId, required String code});

  /// Restores the saved session at launch; `null` if there is none or the
  /// server rejected it. Throws `ApiException(network)` when offline.
  Future<AppSession?> restoreSession();

  /// Refreshes tokens in the background; false if the session is gone.
  Future<bool> refreshSession();

  /// Act as another of the user's memberships (society or role).
  Future<AppSession> switchMembership(String membershipId);

  /// Revokes the session on the server (best effort) and clears it locally.
  Future<void> signOut();

  /// The current access token, if signed in.
  String? get accessToken;
}
