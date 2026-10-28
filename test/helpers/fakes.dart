import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:the_grids/core/network/api_exception.dart';
import 'package:the_grids/features/auth/domain/auth_models.dart';
import 'package:the_grids/features/auth/domain/auth_repository.dart';
import 'package:the_grids/features/auth/domain/session.dart';
import 'package:the_grids/features/auth/domain/user_role.dart';

const testSociety = Society(id: 's1', name: 'Sai Icon Co-operative Society', city: 'Thane');

MembershipSummary membership(UserRole role, {String? id, String? flatLabel = 'Tower-C, 502'}) => MembershipSummary(
      id: id ?? 'm-${role.name}',
      role: role,
      societyId: testSociety.id,
      societyName: testSociety.name,
      flatId: role == UserRole.admin ? null : 'f1',
      flatLabel: role == UserRole.admin ? null : flatLabel,
    );

AppSession fakeSession(UserRole role, {List<MembershipSummary>? memberships}) {
  final current = membership(role);
  return AppSession(
    userId: 'u1',
    displayName: role == UserRole.tenant ? 'Shreyas Kulkarni' : 'Shruti Chetan Dalvi',
    phone: '+919000000001',
    membership: current,
    memberships: memberships ?? [current],
  );
}

/// Scriptable AuthRepository for widget tests.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.societies = const [testSociety], this.savedSession});

  List<Society> societies;

  /// Returned by [restoreSession]. Set [restoreError] to simulate failures.
  AppSession? savedSession;
  Object? restoreError;

  /// Phone numbers (10 digits) registered per role.
  final Map<String, UserRole> registered = {'9000000001': UserRole.owner};
  String correctCode = '123456';
  String? devCode;
  int attemptsLeft = 5;
  int otpRequests = 0;
  bool signedOut = false;
  final List<String> switchedTo = [];

  @override
  String? accessToken;

  @override
  Future<List<Society>> searchSocieties(String query) async =>
      societies.where((s) => s.name.toLowerCase().contains(query.toLowerCase())).toList();

  @override
  Future<OtpChallenge> requestOtp({required String phone, required String societyId, required UserRole role}) async {
    otpRequests++;
    if (registered[phone] != role) {
      throw const ApiException(code: 'NOT_REGISTERED', message: 'not registered', statusCode: 404);
    }
    return OtpChallenge(
      challengeId: 'c$otpRequests',
      expiresIn: const Duration(minutes: 5),
      resendIn: const Duration(seconds: 30),
      devCode: devCode,
    );
  }

  @override
  Future<AppSession> verifyOtp({required String challengeId, required String code}) async {
    if (code != correctCode) {
      attemptsLeft--;
      throw ApiException(code: 'OTP_INVALID', message: 'bad', statusCode: 400, details: {'attemptsLeft': attemptsLeft});
    }
    accessToken = 'access';
    return fakeSession(UserRole.owner);
  }

  @override
  Future<AppSession?> restoreSession() async {
    if (restoreError != null) throw restoreError!;
    return savedSession;
  }

  @override
  Future<bool> refreshSession() async => savedSession != null;

  @override
  Future<AppSession> switchMembership(String membershipId) async {
    switchedTo.add(membershipId);
    final current = savedSession ?? fakeSession(UserRole.owner);
    final target = current.memberships.firstWhere((m) => m.id == membershipId);
    return AppSession(
      userId: current.userId,
      displayName: current.displayName,
      phone: current.phone,
      membership: target,
      memberships: current.memberships,
    );
  }

  @override
  Future<void> signOut() async => signedOut = true;
}

/// Dio adapter that answers from a handler instead of the network.
/// Return a (status, json) record, or throw to simulate a connection error.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);

  final (int, Object?) Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final (status, body) = handler(options);
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Thrown from a [FakeHttpAdapter] handler to simulate being offline.
DioException offline(RequestOptions options) =>
    DioException.connectionError(requestOptions: options, reason: 'offline');

Map<String, Object?> apiError(String code, {Map<String, Object?>? details}) => {
      'error': {'code': code, 'message': code, 'details': ?details},
    };

Map<String, Object?> meJson({String role = 'OWNER'}) => {
      'user': {'id': 'u1', 'name': 'Shruti Chetan Dalvi', 'phone': '+919000000001'},
      'membership': {
        'id': 'm1',
        'role': role,
        'societyId': 's1',
        'societyName': 'Sai Icon Co-operative Society',
        'flatId': 'f1',
        'flatLabel': 'Tower-C, 502',
      },
      'memberships': [
        {
          'id': 'm1',
          'role': role,
          'societyId': 's1',
          'societyName': 'Sai Icon Co-operative Society',
          'flatId': 'f1',
          'flatLabel': 'Tower-C, 502',
        },
        {'id': 'm2', 'role': 'ADMIN', 'societyId': 's1', 'societyName': 'Sai Icon Co-operative Society'},
      ],
    };

Map<String, Object?> sessionJson({String access = 'a1', String refresh = 'r1', String role = 'OWNER'}) => {
      'accessToken': access,
      'accessTokenExpiresIn': 900,
      'refreshToken': refresh,
      'me': meJson(role: role),
    };
