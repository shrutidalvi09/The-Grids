import { type CanActivate, type ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { ApiError } from '../common/api-error.js';
import type { Role } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { type AuthedRequest, IS_PUBLIC, ROLES } from './auth-context.js';
import type { AccessTokenPayload } from './tokens.service.js';

/**
 * Global guard: every route needs a valid access token unless marked
 * @Public(). The membership is re-checked in the database on each request, so
 * removing a member takes effect immediately rather than when the token expires.
 */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    const request = context.switchToHttp().getRequest<AuthedRequest>();
    const [scheme, token] = (request.headers.authorization ?? '').split(' ');
    if (scheme !== 'Bearer' || !token) throw ApiError.unauthenticated('Missing access token');

    let payload: AccessTokenPayload;
    try {
      payload = await this.jwt.verifyAsync<AccessTokenPayload>(token);
    } catch {
      throw ApiError.unauthenticated('Access token is invalid or expired');
    }

    const membership = await this.prisma.membership.findUnique({
      where: { id: payload.mid },
      select: { userId: true, societyId: true, role: true, flatId: true, status: true },
    });
    if (!membership || membership.status !== 'ACTIVE' || membership.userId !== payload.sub) {
      throw ApiError.unauthenticated('Membership is no longer active');
    }

    request.auth = {
      userId: membership.userId,
      membershipId: payload.mid,
      societyId: membership.societyId,
      role: membership.role,
      flatId: membership.flatId,
    };
    return true;
  }
}

/** Global guard enforcing @Roles(...) after authentication. */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const roles = this.reflector.getAllAndOverride<Role[] | undefined>(ROLES, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!roles?.length) return true;
    const auth = context.switchToHttp().getRequest<AuthedRequest>().auth;
    if (!auth || !roles.includes(auth.role)) throw ApiError.forbidden();
    return true;
  }
}
