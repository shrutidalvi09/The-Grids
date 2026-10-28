import { Body, Controller, HttpStatus, Post } from '@nestjs/common';
import { IsEnum, IsOptional, IsString, Length } from 'class-validator';
import { Auth, type AuthContext, Roles } from '../auth/auth-context.js';
import { ApiError } from '../common/api-error.js';
import { normalizeIndianMobile } from '../common/phone.js';
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
  async invite(@Auth() auth: AuthContext, @Body() body: InviteDto): Promise<InviteView> {
    const phone = normalizeIndianMobile(body.phone);
    if (!phone) {
      throw new ApiError(HttpStatus.BAD_REQUEST, 'VALIDATION_FAILED', 'Enter a valid Indian mobile number', {
        fields: ['phone must be a valid Indian mobile number'],
      });
    }

    let flatId = body.flatId ?? null;
    if (auth.role === Role.OWNER) {
      if (body.role !== Role.TENANT) throw ApiError.forbidden('Owners can only invite tenants');
      if (flatId && flatId !== auth.flatId) throw ApiError.forbidden('You can only invite a tenant for your own flat');
      flatId = auth.flatId;
    }
    if (body.role !== Role.ADMIN && !flatId) {
      throw new ApiError(HttpStatus.BAD_REQUEST, 'VALIDATION_FAILED', 'A flat is required for owners and tenants', {
        fields: ['flatId is required for OWNER and TENANT'],
      });
    }
    if (flatId) {
      const flat = await this.prisma.flat.findFirst({ where: { id: flatId, societyId: auth.societyId } });
      if (!flat) throw ApiError.notFound('Flat not found in this society');
    }

    const user = await this.prisma.user.upsert({
      where: { phone },
      update: {},
      create: { phone, name: body.name.trim() },
    });

    const existing = await this.prisma.membership.findUnique({
      where: { userId_societyId_role: { userId: user.id, societyId: auth.societyId, role: body.role } },
    });
    if (existing && existing.status !== 'REMOVED') {
      throw new ApiError(HttpStatus.CONFLICT, 'ALREADY_MEMBER', 'This number already has that role in this society');
    }

    const data = { flatId, status: 'INVITED' as const, invitedById: auth.userId };
    const membership = existing
      ? await this.prisma.membership.update({ where: { id: existing.id }, data })
      : await this.prisma.membership.create({
          data: { ...data, userId: user.id, societyId: auth.societyId, role: body.role },
        });

    return {
      membershipId: membership.id,
      userId: user.id,
      role: membership.role,
      flatId: membership.flatId,
      status: membership.status as 'INVITED' | 'ACTIVE',
    };
  }
}
