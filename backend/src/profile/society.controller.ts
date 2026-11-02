import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Post, Put } from '@nestjs/common';
import { Transform } from 'class-transformer';
import { IsInt, IsNumber, IsOptional, IsString, Length, Max, MaxLength, Min } from 'class-validator';
import { Auth, type AuthContext, Everyone, Roles } from '../auth/auth-context.js';
import { ApiError } from '../common/api-error.js';
import { normalizeIndianMobile } from '../common/phone.js';
import { flatLabel } from '../common/queries.js';
import { Role } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';

class ServiceProviderDto {
  @IsString()
  @Length(2, 30)
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  category!: string;

  @IsString()
  @Length(2, 80)
  name!: string;

  @IsString()
  @Length(10, 20)
  phone!: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  location?: string | null;

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(5)
  rating?: number | null;
}

class RatingDto {
  @IsInt()
  @Min(1)
  @Max(5)
  stars!: number;
}

export interface ServiceProviderView {
  id: string;
  category: string;
  name: string;
  phone: string;
  location: string | null;
  /** Residents' average (or the admin's starting rating until anyone rates). */
  rating: number | null;
  ratingCount: number;
  /** The caller's own stars, if they've rated. */
  myRating: number | null;
}

export interface FlatOption {
  id: string;
  label: string;
  towerName: string;
  number: string;
  /** Owners/tenants currently linked (active or invited). */
  occupants: { name: string; phone: string; role: 'OWNER' | 'TENANT'; status: 'INVITED' | 'ACTIVE' }[];
}

export interface SocietyView {
  id: string;
  name: string;
  address: string | null;
  city: string | null;
  /** The society office (admins) for the Help screen. */
  office: { name: string; phone: string }[];
}

/** Society details, its office contacts and the services directory. */
@Controller()
export class SocietyController {
  constructor(private readonly prisma: PrismaService) {}

  @Everyone()
  @Get('society')
  async society(@Auth() auth: AuthContext): Promise<SocietyView> {
    const society = await this.prisma.society.findUniqueOrThrow({
      where: { id: auth.societyId },
      include: {
        memberships: {
          where: { role: 'ADMIN', status: 'ACTIVE' },
          include: { user: { select: { name: true, phone: true } } },
          orderBy: { createdAt: 'asc' },
        },
      },
    });
    return {
      id: society.id,
      name: society.name,
      address: society.address,
      city: society.city,
      office: society.memberships.map((m) => ({ name: m.user.name, phone: m.user.phone })),
    };
  }

  /** Maids, cooks, drivers, plumbers… recommended within the society. */
  @Everyone()
  @Get('services')
  async services(@Auth() auth: AuthContext): Promise<ServiceProviderView[]> {
    const services = await this.prisma.serviceProvider.findMany({
      where: { societyId: auth.societyId },
      include: { ratings: { select: { userId: true, stars: true } } },
    });
    const views = services.map((s) => toView(s, auth.userId));
    // Best rated first within each category.
    return views.sort(
      (a, b) => a.category.localeCompare(b.category) || (b.rating ?? 0) - (a.rating ?? 0) || a.name.localeCompare(b.name),
    );
  }

  @Roles(Role.ADMIN)
  @Post('services')
  async addService(@Auth() auth: AuthContext, @Body() body: ServiceProviderDto): Promise<ServiceProviderView> {
    const phone = normalizeIndianMobile(body.phone);
    if (!phone) {
      throw new ApiError(HttpStatus.BAD_REQUEST, 'VALIDATION_FAILED', 'Enter a valid Indian mobile number', {
        fields: ['phone must be a valid Indian mobile number'],
      });
    }
    const created = await this.prisma.serviceProvider.create({
      include: { ratings: { select: { userId: true, stars: true } } },
      data: {
        societyId: auth.societyId,
        category: body.category,
        name: body.name.trim(),
        phone,
        location: body.location?.trim() || null,
        rating: body.rating ?? null,
      },
    });
    return toView(created, auth.userId);
  }

  /** Rate a service provider 1–5 (once per person; rating again replaces it). */
  @Put('services/:id/rating')
  async rate(@Auth() auth: AuthContext, @Param('id') id: string, @Body() body: RatingDto): Promise<ServiceProviderView> {
    const service = await this.prisma.serviceProvider.findFirst({ where: { id, societyId: auth.societyId } });
    if (!service) throw ApiError.notFound('Service not found');
    await this.prisma.serviceRating.upsert({
      where: { serviceId_userId: { serviceId: id, userId: auth.userId } },
      update: { stars: body.stars },
      create: { serviceId: id, userId: auth.userId, stars: body.stars },
    });
    const updated = await this.prisma.serviceProvider.findUniqueOrThrow({
      where: { id },
      include: { ratings: { select: { userId: true, stars: true } } },
    });
    return toView(updated, auth.userId);
  }

  /** Admin and gate: every flat with who lives there (inviting residents, logging visitors). */
  @Roles(Role.ADMIN, Role.GUARD)
  @Get('flats')
  async flats(@Auth() auth: AuthContext): Promise<FlatOption[]> {
    const flats = await this.prisma.flat.findMany({
      where: { societyId: auth.societyId },
      include: {
        tower: { select: { name: true } },
        memberships: {
          where: { role: { in: ['OWNER', 'TENANT'] }, status: { in: ['ACTIVE', 'INVITED'] } },
          include: { user: { select: { name: true, phone: true } } },
          orderBy: { role: 'asc' },
        },
      },
    });
    return flats
      .map((f) => ({
        id: f.id,
        label: flatLabel(f) ?? f.number,
        towerName: f.tower.name,
        number: f.number,
        occupants: f.memberships.map((m) => ({
          name: m.user.name,
          phone: m.user.phone, // so the gate can call the flat
          role: m.role as 'OWNER' | 'TENANT',
          status: m.status as 'INVITED' | 'ACTIVE',
        })),
      }))
      .sort((a, b) => a.towerName.localeCompare(b.towerName) || a.number.localeCompare(b.number, 'en', { numeric: true }));
  }

  @Roles(Role.ADMIN)
  @Delete('services/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async removeService(@Auth() auth: AuthContext, @Param('id') id: string): Promise<void> {
    const { count } = await this.prisma.serviceProvider.deleteMany({ where: { id, societyId: auth.societyId } });
    if (count === 0) throw ApiError.notFound('Service not found');
  }
}

function toView(
  s: {
    id: string;
    category: string;
    name: string;
    phone: string;
    location: string | null;
    rating: number | null;
    ratings: { userId: string; stars: number }[];
  },
  userId: string,
): ServiceProviderView {
  const count = s.ratings.length;
  const average = count ? s.ratings.reduce((sum, r) => sum + r.stars, 0) / count : s.rating;
  return {
    id: s.id,
    category: s.category,
    name: s.name,
    phone: s.phone,
    location: s.location,
    rating: average === null ? null : Math.round(average * 10) / 10,
    ratingCount: count,
    myRating: s.ratings.find((r) => r.userId === userId)?.stars ?? null,
  };
}
