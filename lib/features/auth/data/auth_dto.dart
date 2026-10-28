import '../domain/auth_models.dart';
import '../domain/session.dart';
import '../domain/user_role.dart';

typedef Json = Map<String, dynamic>;

Society societyFromJson(Json json) => Society(
      id: json['id'] as String,
      name: json['name'] as String,
      city: json['city'] as String?,
    );

OtpChallenge otpChallengeFromJson(Json json) => OtpChallenge(
      challengeId: json['challengeId'] as String,
      expiresIn: Duration(seconds: json['expiresInSeconds'] as int),
      resendIn: Duration(seconds: json['resendInSeconds'] as int),
      devCode: json['devCode'] as String?,
    );

MembershipSummary membershipFromJson(Json json) => MembershipSummary(
      id: json['id'] as String,
      role: UserRole.fromApi(json['role'] as String),
      societyId: json['societyId'] as String,
      societyName: json['societyName'] as String,
      flatId: json['flatId'] as String?,
      flatLabel: json['flatLabel'] as String?,
    );

/// Parses the `/me` payload (also embedded in every sign-in/refresh response).
AppSession sessionFromMeJson(Json me) {
  final user = me['user'] as Json;
  return AppSession(
    userId: user['id'] as String,
    displayName: user['name'] as String,
    phone: user['phone'] as String,
    email: user['email'] as String?,
    photoPath: user['photoUrl'] as String?,
    membership: membershipFromJson(me['membership'] as Json),
    memberships: [
      for (final m in me['memberships'] as List<dynamic>) membershipFromJson(m as Json),
    ],
  );
}
