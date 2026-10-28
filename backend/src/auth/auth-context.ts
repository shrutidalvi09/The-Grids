import { createParamDecorator, type ExecutionContext, SetMetadata } from '@nestjs/common';
import type { Request } from 'express';
import type { Role } from '../generated/prisma/enums.js';

/** Who is calling, resolved by JwtAuthGuard from the token + a DB check. */
export interface AuthContext {
  userId: string;
  membershipId: string;
  societyId: string;
  role: Role;
  flatId: string | null;
}

export type AuthedRequest = Request & { auth?: AuthContext };

export const IS_PUBLIC = 'isPublic';
/** Skips authentication (sign-in endpoints, society list, health). */
export const Public = () => SetMetadata(IS_PUBLIC, true);

export const ROLES = 'roles';
/** Restricts a route to the given roles. */
export const Roles = (...roles: Role[]) => SetMetadata(ROLES, roles);

/** Injects the caller's AuthContext into a controller method. */
export const Auth = createParamDecorator((_: unknown, ctx: ExecutionContext): AuthContext => {
  const auth = ctx.switchToHttp().getRequest<AuthedRequest>().auth;
  if (!auth) throw new Error('@Auth() used on a route without authentication');
  return auth;
});
