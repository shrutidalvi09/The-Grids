import { Body, Controller, Get, HttpStatus, Param, Patch, Post } from '@nestjs/common';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsDate,
  IsInt,
  IsOptional,
  IsString,
  Length,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';
import { Auth, type AuthContext, Roles } from '../auth/auth-context.js';
import { ApiError } from '../common/api-error.js';
import { inr } from '../common/money.js';
import { normalizeIndianMobile } from '../common/phone.js';
import { flatLabel, flatLabelSelect } from '../common/queries.js';
import { Role } from '../generated/prisma/enums.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import type { BreakdownItem } from '../payments/payments.service.js';
import { PrismaService } from '../prisma/prisma.service.js';

class RentItemDto {
  @IsString()
  @Length(2, 40)
  label!: string;

  @IsInt()
  @Min(100)
  @Max(100_000_000)
  amountPaise!: number;
}

/** Rent terms. Monthly rent is the sum of the breakdown (rent items only, not maintenance). */
class TermsDto {
  @ValidateNested({ each: true })
  @Type(() => RentItemDto)
  @ArrayMinSize(1)
  @ArrayMaxSize(10)
  rentBreakdown!: RentItemDto[];

  @IsInt()
  @Min(0)
  @Max(1_000_000_000)
  depositPaise!: number;

  @IsInt()
  @Min(1)
  @Max(28)
  rentDueDay!: number;

  @Type(() => Date)
  @IsDate()
  startDate!: Date;

  @IsOptional()
  @Type(() => Date)
  @IsDate()
  endDate?: Date | null;
}

class AddTenantDto extends TermsDto {
  @IsString()
  @Length(2, 80)
  tenantName!: string;

  @IsString()
  @Length(10, 20)
  tenantPhone!: string;
}

export interface TenancyView {
  id: string;
  flatLabel: string | null;
  monthlyRentPaise: number;
  depositPaise: number;
  rentDueDay: number;
  rentBreakdown: BreakdownItem[];
  startDate: Date;
  endDate: Date | null;
  tenant: { name: string; phone: string; status: 'INVITED' | 'ACTIVE' | 'REMOVED' };
  owner: { name: string; phone: string };
}

const include = {
  flat: { select: flatLabelSelect },
  tenant: { select: { name: true, phone: true } },
  owner: { select: { name: true, phone: true } },
} as const;

/**
 * Owners: their flat's current tenant and lease (Profile → Tenant Info).
 * Tenants: their owner's contact and lease details.
 */
@Controller('tenancy')
export class TenancyController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  @Roles(Role.OWNER, Role.TENANT)
  @Get()
  async current(@Auth() auth: AuthContext): Promise<{ tenancy: TenancyView | null }> {
    if (!auth.flatId) return { tenancy: null };
    const tenancy = await this.prisma.tenancy.findFirst({
      where: {
        societyId: auth.societyId,
        flatId: auth.flatId,
        ...(auth.role === 'TENANT' ? { tenantId: auth.userId } : {}),
        OR: [{ endDate: null }, { endDate: { gte: startOfToday() } }],
      },
      include,
      orderBy: { startDate: 'desc' },
    });
    return { tenancy: tenancy ? await this.view(auth.societyId, tenancy) : null };
  }

  /** Adds (invites) the tenant by mobile number; they sign in with OTP. */
  @Roles(Role.OWNER)
  @Post()
  async add(@Auth() auth: AuthContext, @Body() body: AddTenantDto): Promise<{ tenancy: TenancyView }> {
    const flatId = auth.flatId;
    if (!flatId) throw ApiError.forbidden('You are not linked to a flat');
    const phone = normalizeIndianMobile(body.tenantPhone);
    if (!phone) {
      throw new ApiError(HttpStatus.BAD_REQUEST, 'VALIDATION_FAILED', 'Enter a valid Indian mobile number', {
        fields: ['tenantPhone must be a valid Indian mobile number'],
      });
    }
    const terms = validTerms(body);
    const active = await this.prisma.tenancy.count({
      where: { flatId, OR: [{ endDate: null }, { endDate: { gte: startOfToday() } }] },
    });
    if (active) {
      throw new ApiError(HttpStatus.CONFLICT, 'TENANCY_EXISTS', 'This flat already has a tenant. End that tenancy first.');
    }

    const tenancy = await this.prisma.$transaction(async (tx) => {
      const user = await tx.user.upsert({ where: { phone }, update: {}, create: { phone, name: body.tenantName.trim() } });
      if (user.id === auth.userId) throw ApiError.forbidden('You cannot be your own tenant');
      const existing = await tx.membership.findUnique({
        where: { userId_societyId_role: { userId: user.id, societyId: auth.societyId, role: 'TENANT' } },
      });
      if (existing && existing.status !== 'REMOVED' && existing.flatId !== flatId) {
        throw new ApiError(HttpStatus.CONFLICT, 'ALREADY_MEMBER', 'This number is already a tenant of another flat');
      }
      const membership = { flatId, invitedById: auth.userId };
      if (existing) {
        await tx.membership.update({
          where: { id: existing.id },
          data: { ...membership, status: existing.status === 'REMOVED' ? 'INVITED' : existing.status },
        });
      } else {
        await tx.membership.create({
          data: { ...membership, userId: user.id, societyId: auth.societyId, role: 'TENANT', status: 'INVITED' },
        });
      }
      return tx.tenancy.create({
        data: { ...terms, societyId: auth.societyId, flatId, ownerId: auth.userId, tenantId: user.id },
        include,
      });
    });

    await this.notifications.notify(auth.societyId, [tenancy.tenantId], {
      type: 'tenancy',
      title: 'Welcome to your new home',
      body: `${tenancy.owner.name} added you as the tenant of ${flatLabel(tenancy.flat)}. Rent: ${inr(tenancy.monthlyRentPaise)} a month.`,
      data: { tenancyId: tenancy.id },
    });
    return { tenancy: await this.view(auth.societyId, tenancy) };
  }

  /** Updates rent terms; takes effect from the next rent due. */
  @Roles(Role.OWNER)
  @Patch(':id')
  async update(@Auth() auth: AuthContext, @Param('id') id: string, @Body() body: TermsDto): Promise<{ tenancy: TenancyView }> {
    await this.ownTenancy(auth, id);
    const tenancy = await this.prisma.tenancy.update({ where: { id }, data: validTerms(body), include });
    return { tenancy: await this.view(auth.societyId, tenancy) };
  }

  /** Ends the lease now; the tenant loses access to the flat straight away. */
  @Roles(Role.OWNER)
  @Post(':id/end')
  async end(@Auth() auth: AuthContext, @Param('id') id: string): Promise<{ tenancy: null }> {
    const tenancy = await this.ownTenancy(auth, id);
    await this.prisma.$transaction([
      // Leases count as active through their end date, so close it as of yesterday.
      this.prisma.tenancy.update({ where: { id }, data: { endDate: new Date(startOfToday().getTime() - 1) } }),
      this.prisma.membership.updateMany({
        where: { userId: tenancy.tenantId, societyId: auth.societyId, role: 'TENANT', flatId: tenancy.flatId },
        data: { status: 'REMOVED' },
      }),
    ]);
    return { tenancy: null };
  }

  private async ownTenancy(auth: AuthContext, id: string) {
    const tenancy = await this.prisma.tenancy.findFirst({
      where: { id, societyId: auth.societyId, flatId: auth.flatId ?? '', OR: [{ endDate: null }, { endDate: { gte: startOfToday() } }] },
    });
    if (!tenancy) throw ApiError.notFound('Tenancy not found');
    return tenancy;
  }

  private async view(
    societyId: string,
    t: {
      id: string;
      tenantId: string;
      monthlyRentPaise: number;
      depositPaise: number;
      rentDueDay: number;
      rentBreakdown: unknown;
      startDate: Date;
      endDate: Date | null;
      flat: { number: string; tower: { name: string } };
      tenant: { name: string; phone: string };
      owner: { name: string; phone: string };
    },
  ): Promise<TenancyView> {
    const membership = await this.prisma.membership.findFirst({
      where: { societyId, userId: t.tenantId, role: 'TENANT' },
      select: { status: true },
    });
    return {
      id: t.id,
      flatLabel: flatLabel(t.flat),
      monthlyRentPaise: t.monthlyRentPaise,
      depositPaise: t.depositPaise,
      rentDueDay: t.rentDueDay,
      rentBreakdown: t.rentBreakdown as BreakdownItem[],
      startDate: t.startDate,
      endDate: t.endDate,
      tenant: { name: t.tenant.name, phone: t.tenant.phone, status: membership?.status ?? 'INVITED' },
      owner: t.owner,
    };
  }
}

function validTerms(body: TermsDto) {
  if (body.endDate && body.endDate <= body.startDate) {
    throw new ApiError(HttpStatus.BAD_REQUEST, 'VALIDATION_FAILED', 'The end date must be after the start date');
  }
  const rentBreakdown = body.rentBreakdown.map((i) => ({ label: i.label.trim(), amountPaise: i.amountPaise }));
  return {
    rentBreakdown,
    monthlyRentPaise: rentBreakdown.reduce((sum, i) => sum + i.amountPaise, 0),
    depositPaise: body.depositPaise,
    rentDueDay: body.rentDueDay,
    startDate: body.startDate,
    endDate: body.endDate ?? null,
  };
}

function startOfToday(): Date {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
}
