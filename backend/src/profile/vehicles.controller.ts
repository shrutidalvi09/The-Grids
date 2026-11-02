import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Patch, Post, Query } from '@nestjs/common';
import { IsEnum, IsOptional, IsString, Length, MaxLength, ValidateIf } from 'class-validator';
import { Auth, type AuthContext, Roles } from '../auth/auth-context.js';
import { ApiError } from '../common/api-error.js';
import { normalizeVehicleNumber } from '../common/codes.js';
import { flatLabel, flatLabelSelect } from '../common/queries.js';
import { Prisma } from '../generated/prisma/client.js';
import { Role, VehicleType } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';

class AddVehicleDto {
  @IsString()
  @Length(4, 16)
  number!: string;

  @IsEnum(VehicleType)
  type!: VehicleType;

  /** "White Swift" */
  @IsOptional()
  @IsString()
  @MaxLength(40)
  description?: string | null;

  /** Admins only: which flat. */
  @IsOptional()
  @IsString()
  flatId?: string;
}

class SlotDto {
  /** null frees the slot. */
  @ValidateIf((_, v) => v !== null)
  @IsString()
  @Length(1, 20)
  parkingSlot!: string | null;
}

class SearchQuery {
  @IsString()
  @Length(2, 16)
  q!: string;
}

export interface VehicleView {
  id: string;
  number: string;
  type: VehicleType;
  description: string | null;
  parkingSlot: string | null;
  flatLabel: string | null;
}

/** "Whose car is this?": the flat and how to reach them. */
export interface VehicleOwnerView extends VehicleView {
  contacts: { name: string; phone: string }[];
}

const VEHICLE_NUMBER = /^[A-Z0-9]{4,12}$/;
const include = { flat: { select: flatLabelSelect } } as const;

function vehicleView(v: {
  id: string;
  number: string;
  type: VehicleType;
  description: string | null;
  parkingSlot: string | null;
  flat: { number: string; tower: { name: string } };
}): VehicleView {
  return {
    id: v.id,
    number: v.number,
    type: v.type,
    description: v.description,
    parkingSlot: v.parkingSlot,
    flatLabel: flatLabel(v.flat),
  };
}

/** Vehicles per flat, parking slots (admin), and the gate's number lookup. */
@Controller('vehicles')
export class VehiclesController {
  constructor(private readonly prisma: PrismaService) {}

  /** Residents: their flat's vehicles. Admins: everyone's. */
  @Get()
  async list(@Auth() auth: AuthContext): Promise<VehicleView[]> {
    const admin = auth.role === Role.ADMIN;
    if (!admin && !auth.flatId) return [];
    const vehicles = await this.prisma.vehicle.findMany({
      where: { societyId: auth.societyId, ...(admin ? {} : { flatId: auth.flatId! }) },
      include,
      orderBy: { createdAt: 'asc' },
    });
    return vehicles.map(vehicleView);
  }

  @Post()
  async add(@Auth() auth: AuthContext, @Body() body: AddVehicleDto): Promise<VehicleView> {
    let flatId: string;
    if (auth.role === Role.ADMIN) {
      if (!body.flatId) throw new ApiError(HttpStatus.BAD_REQUEST, 'VALIDATION_FAILED', 'Choose a flat');
      const flat = await this.prisma.flat.findFirst({ where: { id: body.flatId, societyId: auth.societyId } });
      if (!flat) throw ApiError.notFound('Flat not found');
      flatId = flat.id;
    } else {
      if (!auth.flatId) throw ApiError.forbidden('You are not linked to a flat');
      flatId = auth.flatId;
    }
    const number = normalizeVehicleNumber(body.number);
    if (!VEHICLE_NUMBER.test(number)) {
      throw new ApiError(HttpStatus.BAD_REQUEST, 'VALIDATION_FAILED', 'Enter a valid vehicle number', {
        fields: ['number must be a vehicle registration number'],
      });
    }
    try {
      const vehicle = await this.prisma.vehicle.create({
        data: { societyId: auth.societyId, flatId, number, type: body.type, description: body.description?.trim() || null },
        include,
      });
      return vehicleView(vehicle);
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new ApiError(HttpStatus.CONFLICT, 'VEHICLE_EXISTS', 'This vehicle is already registered in the society');
      }
      throw e;
    }
  }

  /** Admin assigns or frees a parking slot. */
  @Roles(Role.ADMIN)
  @Patch(':id')
  async assignSlot(@Auth() auth: AuthContext, @Param('id') id: string, @Body() body: SlotDto): Promise<VehicleView> {
    const vehicle = await this.prisma.vehicle.findFirst({ where: { id, societyId: auth.societyId } });
    if (!vehicle) throw ApiError.notFound('Vehicle not found');
    const updated = await this.prisma.vehicle.update({
      where: { id },
      data: { parkingSlot: body.parkingSlot?.trim() || null },
      include,
    });
    return vehicleView(updated);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(@Auth() auth: AuthContext, @Param('id') id: string): Promise<void> {
    const vehicle = await this.prisma.vehicle.findFirst({
      where: { id, societyId: auth.societyId, ...(auth.role === Role.ADMIN ? {} : { flatId: auth.flatId ?? '' }) },
    });
    if (!vehicle) throw ApiError.notFound('Vehicle not found');
    await this.prisma.vehicle.delete({ where: { id } });
  }

  /** The gate and admins: find a vehicle by (part of) its number. */
  @Roles(Role.ADMIN, Role.GUARD)
  @Get('search')
  async search(@Auth() auth: AuthContext, @Query() query: SearchQuery): Promise<VehicleOwnerView[]> {
    const q = normalizeVehicleNumber(query.q);
    if (q.length < 2) return [];
    const vehicles = await this.prisma.vehicle.findMany({
      where: { societyId: auth.societyId, number: { contains: q } },
      include: {
        flat: {
          select: {
            ...flatLabelSelect,
            memberships: {
              where: { role: { in: ['OWNER', 'TENANT'] }, status: 'ACTIVE' },
              select: { user: { select: { name: true, phone: true } } },
            },
          },
        },
      },
      take: 10,
    });
    return vehicles.map((v) => ({ ...vehicleView(v), contacts: v.flat.memberships.map((m) => m.user) }));
  }
}
