import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Post } from '@nestjs/common';
import { Transform } from 'class-transformer';
import { IsNumber, IsOptional, IsString, Length, Max, MaxLength, Min } from 'class-validator';
import { Auth, type AuthContext, Roles } from '../auth/auth-context.js';
import { ApiError } from '../common/api-error.js';
import { normalizeIndianMobile } from '../common/phone.js';
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

export interface ServiceProviderView {
  id: string;
  category: string;
  name: string;
  phone: string;
  location: string | null;
  rating: number | null;
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
  @Get('services')
  async services(@Auth() auth: AuthContext): Promise<ServiceProviderView[]> {
    const services = await this.prisma.serviceProvider.findMany({
      where: { societyId: auth.societyId },
      orderBy: [{ category: 'asc' }, { rating: 'desc' }, { name: 'asc' }],
    });
    return services.map(toView);
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
      data: {
        societyId: auth.societyId,
        category: body.category,
        name: body.name.trim(),
        phone,
        location: body.location?.trim() || null,
        rating: body.rating ?? null,
      },
    });
    return toView(created);
  }

  @Roles(Role.ADMIN)
  @Delete('services/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async removeService(@Auth() auth: AuthContext, @Param('id') id: string): Promise<void> {
    const { count } = await this.prisma.serviceProvider.deleteMany({ where: { id, societyId: auth.societyId } });
    if (count === 0) throw ApiError.notFound('Service not found');
  }
}

function toView(s: {
  id: string;
  category: string;
  name: string;
  phone: string;
  location: string | null;
  rating: number | null;
}): ServiceProviderView {
  return {
    id: s.id,
    category: s.category,
    name: s.name,
    phone: s.phone,
    location: s.location,
    rating: s.rating === null ? null : Math.round(s.rating * 10) / 10,
  };
}
