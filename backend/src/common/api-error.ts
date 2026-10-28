import { HttpException, HttpStatus } from '@nestjs/common';

/**
 * Machine-readable error codes the app switches on. Messages are for logs and
 * developers; the app shows its own localised text per code.
 */
export type ErrorCode =
  | 'VALIDATION_FAILED'
  | 'UNAUTHENTICATED'
  | 'FORBIDDEN'
  | 'NOT_FOUND'
  | 'RATE_LIMITED'
  | 'NOT_REGISTERED'
  | 'OTP_COOLDOWN'
  | 'OTP_LIMIT_REACHED'
  | 'OTP_INVALID'
  | 'OTP_EXPIRED'
  | 'INVALID_REFRESH_TOKEN'
  | 'ALREADY_MEMBER'
  | 'SLOT_FULL'
  | 'SLOT_INVALID'
  | 'ALREADY_BOOKED'
  | 'UNSUPPORTED_FILE'
  | 'DUE_NOT_PENDING'
  | 'PAYMENT_VERIFICATION_FAILED'
  | 'ALREADY_REMINDED'
  | 'ALREADY_VOTED'
  | 'POLL_CLOSED'
  | 'COMMUNITY_EXISTS'
  | 'LAST_ADMIN'
  | 'TENANCY_EXISTS'
  | 'INTERNAL';

export class ApiError extends HttpException {
  constructor(
    status: HttpStatus,
    readonly code: ErrorCode,
    message: string,
    readonly details?: Record<string, unknown>,
  ) {
    super({ error: { code, message, ...(details ? { details } : {}) } }, status);
  }

  static notFound(message = 'Not found'): ApiError {
    return new ApiError(HttpStatus.NOT_FOUND, 'NOT_FOUND', message);
  }

  static forbidden(message = 'You do not have access to this'): ApiError {
    return new ApiError(HttpStatus.FORBIDDEN, 'FORBIDDEN', message);
  }

  static unauthenticated(message = 'Sign in again'): ApiError {
    return new ApiError(HttpStatus.UNAUTHORIZED, 'UNAUTHENTICATED', message);
  }
}
