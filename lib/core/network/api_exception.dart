import 'package:dio/dio.dart';

import '../l10n/l10n.dart';

/// An error from the backend (`{ error: { code, message, details } }`) or
/// from the network. UI code switches on [code] and shows localised text.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details = const {},
  });

  /// No response: offline, DNS failure, timeout, server down.
  static const network = 'NETWORK';
  static const unknown = 'UNKNOWN';

  final String code;
  final String message;
  final int? statusCode;
  final Map<String, Object?> details;

  int? get attemptsLeft => details['attemptsLeft'] as int?;
  int? get retryAfterSeconds => details['retryAfterSeconds'] as int?;

  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    if (response == null) {
      return ApiException(code: network, message: error.message ?? 'Network error');
    }
    final data = response.data;
    if (data is Map && data['error'] is Map) {
      final body = (data['error'] as Map).cast<String, Object?>();
      return ApiException(
        code: body['code'] as String? ?? unknown,
        message: body['message'] as String? ?? 'Request failed',
        statusCode: response.statusCode,
        details: (body['details'] as Map?)?.cast<String, Object?>() ?? const {},
      );
    }
    return ApiException(
      code: unknown,
      message: 'HTTP ${response.statusCode}',
      statusCode: response.statusCode,
    );
  }

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}

/// User-facing text for any error thrown by a repository.
String describeError(AppLocalizations l10n, Object error) {
  if (error is! ApiException) return l10n.errorGeneric;
  return switch (error.code) {
    ApiException.network => l10n.errorNetwork,
    'NOT_REGISTERED' => l10n.errorNotRegistered,
    'OTP_INVALID' => l10n.errorOtpInvalid(error.attemptsLeft ?? 0),
    'OTP_EXPIRED' => l10n.errorOtpExpired,
    'OTP_COOLDOWN' => l10n.errorOtpCooldown(error.retryAfterSeconds ?? 30),
    'OTP_LIMIT_REACHED' || 'RATE_LIMITED' => l10n.errorOtpLimit,
    'INVALID_REFRESH_TOKEN' || 'UNAUTHENTICATED' => l10n.sessionExpired,
    'SLOT_FULL' => l10n.errorSlotFull,
    'ALREADY_BOOKED' => l10n.errorAlreadyBooked,
    'SLOT_INVALID' => l10n.errorSlotInvalid,
    'UNSUPPORTED_FILE' => l10n.errorUnsupportedFile,
    'FORBIDDEN' => l10n.errorForbidden,
    'DUE_NOT_PENDING' => l10n.errorDueAlreadyPaid,
    'PAYMENT_VERIFICATION_FAILED' => l10n.errorPaymentVerification,
    'ALREADY_REMINDED' => l10n.errorAlreadyReminded,
    'ALREADY_VOTED' => l10n.errorAlreadyVoted,
    'POLL_CLOSED' => l10n.errorPollClosed,
    'COMMUNITY_EXISTS' => l10n.errorCommunityExists,
    'LAST_ADMIN' => l10n.errorLastAdmin,
    'TENANCY_EXISTS' => l10n.errorTenancyExists,
    'ALREADY_MEMBER' => l10n.errorAlreadyMember,
    _ => l10n.errorGeneric,
  };
}
