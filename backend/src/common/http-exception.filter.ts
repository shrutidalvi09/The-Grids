import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { ThrottlerException } from '@nestjs/throttler';
import type { Response } from 'express';
import { ApiError, type ErrorCode } from './api-error.js';

/** Every error leaves the API as `{ error: { code, message, details? } }`. */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger('HTTP');

  catch(exception: unknown, host: ArgumentsHost): void {
    const res = host.switchToHttp().getResponse<Response>();

    if (exception instanceof ApiError) {
      res.status(exception.getStatus()).json(exception.getResponse());
      return;
    }

    if (exception instanceof ThrottlerException) {
      res.status(HttpStatus.TOO_MANY_REQUESTS).json(body('RATE_LIMITED', 'Too many requests, slow down'));
      return;
    }

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const response = exception.getResponse();
      // class-validator errors arrive as { message: string[] }.
      if (status === HttpStatus.BAD_REQUEST && typeof response === 'object' && response !== null) {
        const messages = (response as { message?: unknown }).message;
        res.status(status).json(
          body('VALIDATION_FAILED', 'Request is invalid', {
            fields: Array.isArray(messages) ? messages : [String(messages)],
          }),
        );
        return;
      }
      res.status(status).json(body(codeFor(status), exception.message));
      return;
    }

    this.logger.error(exception instanceof Error ? exception.stack : String(exception));
    res.status(HttpStatus.INTERNAL_SERVER_ERROR).json(body('INTERNAL', 'Something went wrong'));
  }
}

function body(code: ErrorCode, message: string, details?: Record<string, unknown>) {
  return { error: { code, message, ...(details ? { details } : {}) } };
}

function codeFor(status: number): ErrorCode {
  switch (status) {
    case HttpStatus.UNAUTHORIZED:
      return 'UNAUTHENTICATED';
    case HttpStatus.FORBIDDEN:
      return 'FORBIDDEN';
    case HttpStatus.NOT_FOUND:
      return 'NOT_FOUND';
    case HttpStatus.TOO_MANY_REQUESTS:
      return 'RATE_LIMITED';
    default:
      return status >= 500 ? 'INTERNAL' : 'VALIDATION_FAILED';
  }
}
