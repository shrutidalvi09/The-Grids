import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Patch, Put } from '@nestjs/common';
import {
  IsEmail,
  IsIn,
  IsObject,
  IsOptional,
  IsString,
  Length,
  Matches,
  ValidateIf,
} from 'class-validator';
import { Auth, type AuthContext } from '../auth/auth-context.js';
import { ApiError } from '../common/api-error.js';
import { Prisma } from '../generated/prisma/client.js';
import { MeService, type MeView } from '../me/me.service.js';
import { PREFERENCE_KEYS, readPreferences, type NotificationPreferences } from '../notifications/preferences.js';
import { PrismaService } from '../prisma/prisma.service.js';

export const LANGUAGES = ['en', 'hi', 'gu', 'mr', 'ta', 'te', 'kn', 'bn'] as const;
export const PAYMENT_METHODS = ['upi', 'card', 'netbanking'] as const;

class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @Length(2, 80)
  name?: string;

  /** Empty string or null clears it. */
  @IsOptional()
  @ValidateIf((_, v) => v !== null && v !== '')
  @IsEmail()
  email?: string | null;

  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsString()
  @Matches(/^\/uploads\/[\w-]+\.(jpg|png|webp)$/, { message: 'photoUrl must come from /v1/uploads' })
  photoUrl?: string | null;

  @IsOptional()
  @IsIn(LANGUAGES)
  language?: string;

  @IsOptional()
  @IsIn(['system', 'light', 'dark'])
  theme?: string;
}

class PreferencesDto {
  @IsOptional()
  @IsObject()
  notifications?: Record<string, unknown>;

  /** null = no preference; Razorpay shows every method. */
  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsIn(PAYMENT_METHODS)
  paymentMethod?: string | null;
}

export interface PreferencesView {
  notifications: NotificationPreferences;
  paymentMethod: string | null;
}

/** Edit profile, preferences and delete account (Profile → Account Options). */
@Controller('me')
export class AccountController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly me: MeService,
  ) {}

  @Patch()
  async update(@Auth() auth: AuthContext, @Body() body: UpdateProfileDto): Promise<MeView> {
    await this.prisma.user.update({
      where: { id: auth.userId },
      data: {
        name: body.name?.trim(),
        email: body.email === undefined ? undefined : body.email?.trim().toLowerCase() || null,
        photoUrl: body.photoUrl,
        language: body.language,
        theme: body.theme,
      },
    });
    return this.me.get(auth.userId, auth.membershipId);
  }

  @Get('preferences')
  async preferences(@Auth() auth: AuthContext): Promise<PreferencesView> {
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: auth.userId } });
    return { notifications: readPreferences(user.notificationPrefs), paymentMethod: user.paymentMethod };
  }

  @Put('preferences')
  async savePreferences(@Auth() auth: AuthContext, @Body() body: PreferencesDto): Promise<PreferencesView> {
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: auth.userId } });
    let notifications = readPreferences(user.notificationPrefs);
    if (body.notifications) {
      const unknown = Object.keys(body.notifications).filter((k) => !(PREFERENCE_KEYS as readonly string[]).includes(k));
      const notBool = Object.values(body.notifications).some((v) => typeof v !== 'boolean');
      if (unknown.length || notBool) {
        throw new ApiError(HttpStatus.BAD_REQUEST, 'VALIDATION_FAILED', 'Unknown or invalid notification preference', {
          fields: unknown,
        });
      }
      notifications = { ...notifications, ...(body.notifications as Partial<NotificationPreferences>) };
    }
    const updated = await this.prisma.user.update({
      where: { id: auth.userId },
      data: {
        notificationPrefs: notifications,
        ...(body.paymentMethod !== undefined ? { paymentMethod: body.paymentMethod } : {}),
      },
    });
    return { notifications, paymentMethod: updated.paymentMethod };
  }

  /**
   * Deletes the account: personal details are erased and every membership
   * ends. Payment records stay (with the name removed) for the society's
   * accounts. A society's last admin must hand over first.
   */
  @Delete()
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(@Auth() auth: AuthContext): Promise<void> {
    const adminOf = await this.prisma.membership.findMany({
      where: { userId: auth.userId, role: 'ADMIN', status: 'ACTIVE' },
      select: { societyId: true },
    });
    for (const { societyId } of adminOf) {
      const others = await this.prisma.membership.count({
        where: { societyId, role: 'ADMIN', status: 'ACTIVE', userId: { not: auth.userId } },
      });
      if (others === 0) {
        throw new ApiError(
          HttpStatus.CONFLICT,
          'LAST_ADMIN',
          'You are the only admin of this society. Make someone else an admin first.',
        );
      }
    }
    await this.prisma.$transaction([
      this.prisma.membership.updateMany({ where: { userId: auth.userId }, data: { status: 'REMOVED' } }),
      this.prisma.refreshToken.deleteMany({ where: { userId: auth.userId } }),
      this.prisma.deviceToken.deleteMany({ where: { userId: auth.userId } }),
      this.prisma.communityMember.deleteMany({ where: { userId: auth.userId } }),
      this.prisma.notification.deleteMany({ where: { userId: auth.userId } }),
      this.prisma.user.update({
        where: { id: auth.userId },
        data: {
          name: 'Deleted user',
          phone: `deleted:${auth.userId}`,
          email: null,
          photoUrl: null,
          notificationPrefs: Prisma.DbNull,
          paymentMethod: null,
        },
      }),
    ]);
  }
}
