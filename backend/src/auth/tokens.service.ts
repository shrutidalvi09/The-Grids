import { createHash, randomBytes, randomUUID } from 'node:crypto';
import { HttpStatus, Inject, Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ApiError } from '../common/api-error.js';
import { ENV, type Env } from '../config/env.js';
import type { Role } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';

export interface AccessTokenPayload {
  sub: string; // userId
  mid: string; // membershipId
  sid: string; // societyId
  role: Role;
}

export interface IssuedTokens {
  accessToken: string;
  accessTokenExpiresIn: number;
  refreshToken: string;
}

interface MembershipRef {
  id: string;
  userId: string;
  societyId: string;
  role: Role;
}

const sha256 = (value: string) => createHash('sha256').update(value).digest('hex');

@Injectable()
export class TokensService {
  constructor(
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /** Starts a new login: fresh refresh-token family. */
  issue(membership: MembershipRef): Promise<IssuedTokens> {
    return this.issueInFamily(membership, randomUUID());
  }

  /**
   * Exchanges a refresh token for a new pair. The old token is revoked; if a
   * revoked token is ever presented again (stolen and replayed), the whole
   * family is revoked and the user must sign in again.
   */
  async rotate(refreshToken: string): Promise<{ tokens: IssuedTokens; membershipId: string }> {
    const stored = await this.prisma.refreshToken.findUnique({
      where: { tokenHash: sha256(refreshToken) },
      include: { membership: true },
    });
    if (!stored) throw invalidRefresh();

    if (stored.revokedAt) {
      await this.revokeFamily(stored.familyId);
      throw invalidRefresh();
    }
    if (stored.expiresAt <= new Date() || stored.membership.status !== 'ACTIVE') {
      await this.revokeFamily(stored.familyId);
      throw invalidRefresh();
    }

    // Conditional update so two concurrent refreshes can't both succeed.
    const { count } = await this.prisma.refreshToken.updateMany({
      where: { id: stored.id, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    if (count === 0) {
      await this.revokeFamily(stored.familyId);
      throw invalidRefresh();
    }

    const tokens = await this.issueInFamily(stored.membership, stored.familyId);
    return { tokens, membershipId: stored.membershipId };
  }

  /** Logout: revokes the token's family. Unknown tokens are ignored. */
  async revoke(refreshToken: string): Promise<void> {
    const stored = await this.prisma.refreshToken.findUnique({
      where: { tokenHash: sha256(refreshToken) },
      select: { familyId: true },
    });
    if (stored) await this.revokeFamily(stored.familyId);
  }

  /** Returns the owning user of a live refresh token, or throws. */
  async userIdFor(refreshToken: string): Promise<string> {
    const stored = await this.prisma.refreshToken.findUnique({
      where: { tokenHash: sha256(refreshToken) },
      select: { userId: true, revokedAt: true, expiresAt: true },
    });
    if (!stored || stored.revokedAt || stored.expiresAt <= new Date()) throw invalidRefresh();
    return stored.userId;
  }

  private async issueInFamily(membership: MembershipRef, familyId: string): Promise<IssuedTokens> {
    const payload: AccessTokenPayload = {
      sub: membership.userId,
      mid: membership.id,
      sid: membership.societyId,
      role: membership.role,
    };
    const accessToken = await this.jwt.signAsync(payload, {
      expiresIn: this.env.jwtAccessTtlSeconds,
    });

    const refreshToken = randomBytes(32).toString('base64url');
    await this.prisma.refreshToken.create({
      data: {
        userId: membership.userId,
        membershipId: membership.id,
        familyId,
        tokenHash: sha256(refreshToken),
        expiresAt: new Date(Date.now() + this.env.refreshTokenTtlDays * 86_400_000),
      },
    });

    return { accessToken, accessTokenExpiresIn: this.env.jwtAccessTtlSeconds, refreshToken };
  }

  private async revokeFamily(familyId: string): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: { familyId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }
}

function invalidRefresh(): ApiError {
  return new ApiError(HttpStatus.UNAUTHORIZED, 'INVALID_REFRESH_TOKEN', 'Session expired, sign in again');
}
