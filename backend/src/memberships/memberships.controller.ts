import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
} from '@nestjs/common';
import { IsEnum, IsOptional, IsString, Length } from 'class-validator';
import { Auth, type AuthContext, Roles } from '../auth/auth-context.js';
import { ApiError } from '../common/api-error.js';
import { normalizeIndianMobile } from '../common/phone.js';
import { flatLabel, flatLabelSelect } from '../common/queries.js';
import { Role } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';

class InviteDto {
  @IsString()
  @Length(10, 20)
  phone!: string;

  @IsString()
  @Length(2, 80)
  name!: string;

  @IsEnum(Role)
  role!: Role;

  @IsOptional()
  @IsString()
  flatId?: string;
}

export interface MemberView {
  membershipId: string;
  userId: string;
  name: string;
  phone: string;
  role: Role;
  status: 'INVITED' | 'ACTIVE';
  flatId: string | null;
  flatLabel: string | null;
}

export interface InviteView {
  membershipId: string;
  userId: string;
  role: Role;
  flatId: string | null;
  status: 'INVITED' | 'ACTIVE';
}

/**
 * Registers a phone number for a society + role so that person can sign in.
 * Admins may invite admins, owners and tenants; an owner may only invite a
 * tenant for their own flat; tenants cannot invite.
 */
@Controller('memberships')
export class MembershipsController {
  constructor(private readonly prisma: PrismaService) {}

  @Roles(Role.ADMIN, Role.OWNER)
  @Post('invites')
  async invite(
    @Auth() auth: AuthContext,
    @Body() body: InviteDto,
  ): Promise<InviteView> {
    const phone = normalizeIndianMobile(body.phone);
    if (!phone) {
      throw new ApiError(
        HttpStatus.BAD_REQUEST,
        'VALIDATION_FAILED',
        'Enter a valid Indian mobile number',
        {
          fields: ['phone must be a valid Indian mobile number'],
        },
      );
    }

    let flatId = body.flatId ?? null;
    if (auth.role === Role.OWNER) {
      if (body.role !== Role.TENANT)
        throw ApiError.forbidden('Owners can only invite tenants');
      if (flatId && flatId !== auth.flatId)
        throw ApiError.forbidden(
          'You can only invite a tenant for your own flat',
        );
      flatId = auth.flatId;
    }
    // Guards work at the gate, not in a flat.
    if (body.role === Role.GUARD) flatId = null;
    if ((body.role === Role.OWNER || body.role === Role.TENANT) && !flatId) {
      throw new ApiError(
        HttpStatus.BAD_REQUEST,
        'VALIDATION_FAILED',
        'A flat is required for owners and tenants',
        {
          fields: ['flatId is required for OWNER and TENANT'],
        },
      );
    }
    if (flatId) {
      const flat = await this.prisma.flat.findFirst({
        where: { id: flatId, societyId: auth.societyId },
      });
      if (!flat) throw ApiError.notFound('Flat not found in this society');
    }

    const user = await this.prisma.user.upsert({
      where: { phone },
      update: {},
      create: { phone, name: body.name.trim() },
    });

    const existing = await this.prisma.membership.findUnique({
      where: {
        userId_societyId_role: {
          userId: user.id,
          societyId: auth.societyId,
          role: body.role,
        },
      },
    });
    if (existing && existing.status !== 'REMOVED') {
      throw new ApiError(
        HttpStatus.CONFLICT,
        'ALREADY_MEMBER',
        'This number already has that role in this society',
      );
    }

    const data = {
      flatId,
      status: 'INVITED' as const,
      invitedById: auth.userId,
    };
    const membership = existing
      ? await this.prisma.membership.update({
          where: { id: existing.id },
          data,
        })
      : await this.prisma.membership.create({
          data: {
            ...data,
            userId: user.id,
            societyId: auth.societyId,
            role: body.role,
          },
        });

    return {
      membershipId: membership.id,
      userId: user.id,
      role: membership.role,
      flatId: membership.flatId,
      status: membership.status as 'INVITED' | 'ACTIVE',
    };
  }

  /** Admin: everyone registered in the society, invited or active. */
  @Roles(Role.ADMIN)
  @Get()
  async list(@Auth() auth: AuthContext): Promise<MemberView[]> {
    const memberships = await this.prisma.membership.findMany({
      where: {
        societyId: auth.societyId,
        status: { in: ['INVITED', 'ACTIVE'] },
      },
      include: {
        user: { select: { name: true, phone: true } },
        flat: { select: flatLabelSelect },
      },
    });
    const order = { ADMIN: 0, GUARD: 1, OWNER: 2, TENANT: 3 } as const;
    return memberships
      .map((m) => ({
        membershipId: m.id,
        userId: m.userId,
        name: m.user.name,
        phone: m.user.phone,
        role: m.role,
        status: m.status as 'INVITED' | 'ACTIVE',
        flatId: m.flatId,
        flatLabel: flatLabel(m.flat),
      }))
      .sort(
        (a, b) =>
          order[a.role] - order[b.role] ||
          (a.flatLabel ?? '').localeCompare(b.flatLabel ?? '', 'en', {
            numeric: true,
          }) ||
          a.name.localeCompare(b.name),
      );
  }

  /**
   * Admin: remove someone's access (they're signed out on their next request).
   * The society must keep at least one active admin.
   */
  @Roles(Role.ADMIN)
  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(
    @Auth() auth: AuthContext,
    @Param('id') id: string,
  ): Promise<void> {
    const membership = await this.prisma.membership.findFirst({
      where: {
        id,
        societyId: auth.societyId,
        status: { in: ['INVITED', 'ACTIVE'] },
      },
    });
    if (!membership) throw ApiError.notFound('Member not found');
    if (membership.role === Role.ADMIN) {
      const admins = await this.prisma.membership.count({
        where: {
          societyId: auth.societyId,
          role: Role.ADMIN,
          status: 'ACTIVE',
          id: { not: id },
        },
      });
      if (admins === 0) {
        throw new ApiError(
          HttpStatus.CONFLICT,
          'LAST_ADMIN_REMOVE',
          'The society needs at least one admin',
        );
      }
    }
    await this.prisma.$transaction([
      this.prisma.membership.update({
        where: { id },
        data: { status: 'REMOVED' },
      }),
      this.prisma.refreshToken.deleteMany({ where: { membershipId: id } }),
    ]);
  }
}
