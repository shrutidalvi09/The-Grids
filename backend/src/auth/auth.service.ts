import { randomUUID } from 'node:crypto';
import { HttpStatus, Inject, Injectable, Logger } from '@nestjs/common';
import { ApiError } from '../common/api-error.js';
import { maskPhone, normalizeIndianMobile } from '../common/phone.js';
import { ENV, type Env } from '../config/env.js';
import type { Role } from '../generated/prisma/enums.js';
import { MeService, type MeView } from '../me/me.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { AuthContext } from './auth-context.js';
import {
  generateOtp,
  hashOtp,
  OTP_MAX_ATTEMPTS,
  OTP_MAX_PER_HOUR,
  OTP_RESEND_COOLDOWN_SECONDS,
  OTP_TTL_SECONDS,
  otpMatches,
} from './otp.js';
import { SmsSender } from './sms.js';
import { type IssuedTokens, TokensService } from './tokens.service.js';

export interface OtpChallengeView {
  challengeId: string;
  expiresInSeconds: number;
  resendInSeconds: number;
  /** Only when OTP_DEV_ECHO=true (never in production). */
  devCode?: string;
}

export type SessionView = IssuedTokens & { me: MeView };

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly tokens: TokensService,
    private readonly me: MeService,
    private readonly sms: SmsSender,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /**
   * Step 1: send a code, but only to a number an admin (or owner) has
   * registered for this society and role.
   */
  async requestOtp(input: { phone: string; societyId: string; role: Role }): Promise<OtpChallengeView> {
    const phone = normalizeIndianMobile(input.phone);
    if (!phone) {
      throw new ApiError(HttpStatus.BAD_REQUEST, 'VALIDATION_FAILED', 'Enter a valid Indian mobile number', {
        fields: ['phone must be a valid Indian mobile number'],
      });
    }

    const membership = await this.prisma.membership.findFirst({
      where: {
        societyId: input.societyId,
        role: input.role,
        status: { in: ['INVITED', 'ACTIVE'] },
        user: { phone },
        society: { isActive: true },
      },
      select: { id: true },
    });
    if (!membership) {
      throw new ApiError(
        HttpStatus.NOT_FOUND,
        'NOT_REGISTERED',
        'This number is not registered for this society and role. Contact your society admin.',
      );
    }

    const now = Date.now();
    const recent = await this.prisma.otpChallenge.findMany({
      where: { phone, createdAt: { gte: new Date(now - 3_600_000) } },
      select: { createdAt: true },
      orderBy: { createdAt: 'desc' },
    });
    const last = recent[0];
    if (last) {
      const wait = Math.ceil(OTP_RESEND_COOLDOWN_SECONDS - (now - last.createdAt.getTime()) / 1000);
      if (wait > 0) {
        throw new ApiError(HttpStatus.TOO_MANY_REQUESTS, 'OTP_COOLDOWN', `Wait ${wait}s before requesting a new code`, {
          retryAfterSeconds: wait,
        });
      }
    }
    if (recent.length >= OTP_MAX_PER_HOUR) {
      throw new ApiError(HttpStatus.TOO_MANY_REQUESTS, 'OTP_LIMIT_REACHED', 'Too many codes requested. Try again later.');
    }

    const challengeId = randomUUID();
    const code = generateOtp();
    await this.prisma.otpChallenge.create({
      data: {
        id: challengeId,
        membershipId: membership.id,
        phone,
        codeHash: hashOtp(this.env.otpPepper, challengeId, code),
        expiresAt: new Date(now + OTP_TTL_SECONDS * 1000),
      },
    });
    await this.sms.send(
      phone,
      `${code} is your The Grids login code. It expires in ${OTP_TTL_SECONDS / 60} minutes. Do not share it with anyone.`,
    );
    this.logger.log(`OTP sent to ${maskPhone(phone)}`);

    return {
      challengeId,
      expiresInSeconds: OTP_TTL_SECONDS,
      resendInSeconds: OTP_RESEND_COOLDOWN_SECONDS,
      ...(this.env.otpDevEcho ? { devCode: code } : {}),
    };
  }

  /** Step 2: check the code and start a session. */
  async verifyOtp(input: { challengeId: string; code: string }): Promise<SessionView> {
    const challenge = await this.prisma.otpChallenge.findUnique({
      where: { id: input.challengeId },
      include: { membership: true },
    });
    if (
      !challenge ||
      challenge.consumedAt ||
      challenge.expiresAt <= new Date() ||
      challenge.attempts >= OTP_MAX_ATTEMPTS ||
      challenge.membership.status === 'REMOVED'
    ) {
      throw otpExpired();
    }

    if (!otpMatches(this.env.otpPepper, challenge.id, input.code, challenge.codeHash)) {
      const updated = await this.prisma.otpChallenge.update({
        where: { id: challenge.id },
        data: { attempts: { increment: 1 } },
        select: { attempts: true },
      });
      const attemptsLeft = Math.max(0, OTP_MAX_ATTEMPTS - updated.attempts);
      if (attemptsLeft === 0) throw otpExpired();
      throw new ApiError(HttpStatus.BAD_REQUEST, 'OTP_INVALID', 'Incorrect code', { attemptsLeft });
    }

    // Consume exactly once, even if two verifications race.
    const { count } = await this.prisma.otpChallenge.updateMany({
      where: { id: challenge.id, consumedAt: null },
      data: { consumedAt: new Date() },
    });
    if (count === 0) throw otpExpired();

    const membership =
      challenge.membership.status === 'INVITED'
        ? await this.prisma.membership.update({ where: { id: challenge.membershipId }, data: { status: 'ACTIVE' } })
        : challenge.membership;

    return this.session(membership);
  }

  async refresh(refreshToken: string): Promise<SessionView> {
    const { tokens, membershipId } = await this.tokens.rotate(refreshToken);
    const membership = await this.prisma.membership.findUniqueOrThrow({ where: { id: membershipId } });
    return { ...tokens, me: await this.me.get(membership.userId, membership.id) };
  }

  logout(refreshToken: string): Promise<void> {
    return this.tokens.revoke(refreshToken);
  }

  /**
   * Switch society/role. The phone number is already verified for this user,
   * so any of their memberships (including INVITED ones) can be activated.
   */
  async switchMembership(auth: AuthContext, input: { membershipId: string; refreshToken: string }): Promise<SessionView> {
    if ((await this.tokens.userIdFor(input.refreshToken)) !== auth.userId) {
      throw ApiError.forbidden('Refresh token does not belong to this user');
    }
    const target = await this.prisma.membership.findFirst({
      where: {
        id: input.membershipId,
        userId: auth.userId,
        status: { in: ['INVITED', 'ACTIVE'] },
        society: { isActive: true },
      },
    });
    if (!target) throw ApiError.notFound('Membership not found');

    const membership =
      target.status === 'INVITED'
        ? await this.prisma.membership.update({ where: { id: target.id }, data: { status: 'ACTIVE' } })
        : target;

    await this.tokens.revoke(input.refreshToken);
    return this.session(membership);
  }

  private async session(membership: { id: string; userId: string; societyId: string; role: Role }): Promise<SessionView> {
    const tokens = await this.tokens.issue(membership);
    return { ...tokens, me: await this.me.get(membership.userId, membership.id) };
  }
}

function otpExpired(): ApiError {
  return new ApiError(HttpStatus.GONE, 'OTP_EXPIRED', 'This code has expired. Request a new one.');
}
