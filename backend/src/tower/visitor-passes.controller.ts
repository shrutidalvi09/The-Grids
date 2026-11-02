import { Body, Controller, Delete, HttpCode, HttpStatus, Param, Patch, Post } from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsBoolean, IsDate, IsEnum, IsIn, IsOptional, IsString, Length, Matches, MaxLength } from 'class-validator';
import { Auth, type AuthContext, Everyone, Roles } from '../auth/auth-context.js';
import { ApiError } from '../common/api-error.js';
import { GUEST_PASS_DIGITS, normalizeVehicleNumber, withUniqueCode } from '../common/codes.js';
import { isGate } from '../common/member.js';
import { normalizeIndianMobile } from '../common/phone.js';
import { flatLabel, flatLabelSelect } from '../common/queries.js';
import { Role, VisitorType } from '../generated/prisma/enums.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { type VisitorView, visitorView } from './residents.controller.js';

class ExpectVisitorDto {
  @IsString()
  @Length(2, 60)
  name!: string;

  /** "Maid", "Parcel", "Guest for dinner"… */
  @IsOptional()
  @IsString()
  @MaxLength(40)
  purpose?: string | null;

  @IsEnum(VisitorType)
  type!: VisitorType;

  @IsOptional()
  @IsString()
  @Length(10, 20)
  phone?: string | null;

  @IsOptional()
  @Type(() => Date)
  @IsDate()
  expectedAt?: Date | null;

  /** Guest parking: the car or bike they'll come in. */
  @IsOptional()
  @IsString()
  @MaxLength(20)
  vehicleNumber?: string | null;

  /** The gate only: which flat. Residents always use their own. */
  @IsOptional()
  @IsString()
  flatId?: string;

  /**
   * The gate only. EXPECTED: log for later (default). ASK: the visitor is at
   * the gate; ask the flat to allow or deny. CHECK_IN: let them in now.
   */
  @IsOptional()
  @IsIn(['EXPECTED', 'ASK', 'CHECK_IN'])
  arrival?: 'EXPECTED' | 'ASK' | 'CHECK_IN';

  /** Photo taken at the gate (from POST /uploads). */
  @IsOptional()
  @Matches(/^\/uploads\/[\w.-]+$/)
  photoUrl?: string | null;
}

class GateStatusDto {
  @IsIn(['CHECKED_IN', 'HELD_AT_GATE', 'CHECKED_OUT'])
  status!: 'CHECKED_IN' | 'HELD_AT_GATE' | 'CHECKED_OUT';
}

class DecisionDto {
  @IsBoolean()
  allow!: boolean;
}

class VerifyPassDto {
  /** The code typed by the guard, or the scanned QR ("grids:pass:482913"). */
  @IsString()
  @Length(4, 40)
  code!: string;
}

export interface StaffPassView {
  id: string;
  name: string;
  kind: string;
  phone: string | null;
  flatLabels: string[];
  inside: boolean;
}

export type PassCheck = { kind: 'visitor'; visitor: VisitorView } | { kind: 'staff'; staff: StaffPassView };

const include = { flat: { select: flatLabelSelect } } as const;

/**
 * Residents pre-approve visitors (with a one-time gate pass); the gate
 * (guards, or admins standing in) logs walk-ins, asks the flat to allow or
 * deny them, and checks people in and out. The flat is notified.
 */
@Controller('visitors')
export class VisitorPassesController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  @Everyone()
  @Post()
  async expect(@Auth() auth: AuthContext, @Body() body: ExpectVisitorDto): Promise<VisitorView> {
    const gate = isGate(auth);
    let flatId: string;
    if (gate) {
      if (!body.flatId) throw new ApiError(HttpStatus.BAD_REQUEST, 'VALIDATION_FAILED', 'Choose a flat');
      const flat = await this.prisma.flat.findFirst({ where: { id: body.flatId, societyId: auth.societyId } });
      if (!flat) throw ApiError.notFound('Flat not found');
      flatId = flat.id;
    } else {
      if (!auth.flatId) throw ApiError.forbidden('You are not linked to a flat');
      flatId = auth.flatId; // residents can't add visitors for other flats
    }
    let phone: string | null = null;
    if (body.phone) {
      phone = normalizeIndianMobile(body.phone);
      if (!phone) {
        throw new ApiError(HttpStatus.BAD_REQUEST, 'VALIDATION_FAILED', 'Enter a valid Indian mobile number', {
          fields: ['phone must be a valid Indian mobile number'],
        });
      }
    }
    if (body.expectedAt && body.expectedAt.getTime() < Date.now() - 60 * 60 * 1000) {
      throw new ApiError(HttpStatus.BAD_REQUEST, 'VALIDATION_FAILED', 'Expected time is in the past');
    }
    const vehicleNumber = body.vehicleNumber ? normalizeVehicleNumber(body.vehicleNumber) || null : null;
    const arrival = gate ? (body.arrival ?? 'EXPECTED') : 'EXPECTED';
    const now = new Date();
    const data = {
      societyId: auth.societyId,
      flatId,
      name: body.name.trim(),
      purpose: body.purpose?.trim() || null,
      type: body.type,
      phone,
      vehicleNumber,
      expectedAt: body.expectedAt ?? null,
      photoUrl: gate ? (body.photoUrl ?? null) : null,
      // Only a resident's own invitation counts as pre-approved.
      createdById: gate ? null : auth.userId,
      status: arrival === 'ASK' ? ('PENDING_APPROVAL' as const) : arrival === 'CHECK_IN' ? ('CHECKED_IN' as const) : ('EXPECTED' as const),
      inTime: arrival === 'CHECK_IN' ? now : null,
    };
    const visitor = gate
      ? await this.prisma.visitor.create({ data, include })
      : await withUniqueCode(GUEST_PASS_DIGITS, (passCode) =>
          this.prisma.visitor.create({ data: { ...data, passCode }, include }),
        );

    if (arrival !== 'EXPECTED') {
      const residents = await this.notifications.flatResidentIds(auth.societyId, flatId);
      await this.notifications.notify(auth.societyId, residents, {
        type: arrival === 'ASK' ? 'visitor_approval' : 'visitor',
        message: { key: arrival === 'ASK' ? 'visitor_approval' : 'visitor_arrived', name: visitor.name },
        data: { visitorId: visitor.id },
      });
    }
    return visitorView(visitor, { showPass: !gate });
  }

  /** The gate marks arrival, parcel held, or exit. */
  @Roles(Role.ADMIN, Role.GUARD)
  @Patch(':id/status')
  async gate(@Auth() auth: AuthContext, @Param('id') id: string, @Body() body: GateStatusDto): Promise<VisitorView> {
    const visitor = await this.prisma.visitor.findFirst({ where: { id, societyId: auth.societyId } });
    if (!visitor) throw ApiError.notFound('Visitor not found');
    const now = new Date();
    const updated = await this.prisma.visitor.update({
      where: { id },
      data: {
        status: body.status,
        inTime: visitor.inTime ?? now,
        outTime: body.status === 'CHECKED_OUT' ? now : null,
        passCode: null, // a pass works once
      },
      include,
    });

    if (body.status !== 'CHECKED_OUT' && visitor.status !== body.status) {
      const residents = await this.notifications.flatResidentIds(auth.societyId, visitor.flatId);
      await this.notifications.notify(auth.societyId, residents, {
        type: body.status === 'HELD_AT_GATE' ? 'parcel' : 'visitor',
        message: { key: body.status === 'HELD_AT_GATE' ? 'visitor_at_gate' : 'visitor_arrived', name: visitor.name },
        data: { visitorId: id },
      });
    }
    return visitorView(updated);
  }

  /** The flat answers a walk-in: allow (they go in) or deny. First answer wins. */
  @Roles(Role.OWNER, Role.TENANT)
  @Patch(':id/decision')
  async decide(@Auth() auth: AuthContext, @Param('id') id: string, @Body() body: DecisionDto): Promise<VisitorView> {
    const visitor = await this.prisma.visitor.findFirst({
      where: { id, societyId: auth.societyId, flatId: auth.flatId ?? '' },
      include,
    });
    if (!visitor) throw ApiError.notFound('Visitor not found');
    const { count } = await this.prisma.visitor.updateMany({
      where: { id, status: 'PENDING_APPROVAL' },
      data: body.allow
        ? { status: 'CHECKED_IN', inTime: new Date(), decidedById: auth.userId }
        : { status: 'DENIED', decidedById: auth.userId },
    });
    if (!count) {
      throw new ApiError(HttpStatus.CONFLICT, 'VISITOR_DECIDED', 'Someone has already answered for this visitor');
    }
    await this.notifications.notify(
      auth.societyId,
      await this.notifications.gateStaffIds(auth.societyId),
      {
        type: 'visitor_decision',
        message: { key: 'visitor_decision', name: visitor.name, flat: flatLabel(visitor.flat) ?? '', allowed: body.allow },
        data: { visitorId: id },
      },
      auth.userId,
    );
    const updated = await this.prisma.visitor.findUniqueOrThrow({ where: { id }, include });
    return visitorView(updated, { showPass: true });
  }

  /** The gate looks up a guest pass or a daily-help code. */
  @Roles(Role.ADMIN, Role.GUARD)
  @Post('verify-pass')
  @HttpCode(HttpStatus.OK)
  async verify(@Auth() auth: AuthContext, @Body() body: VerifyPassDto): Promise<PassCheck> {
    const code = body.code.trim().replace(/^grids:(pass|staff):/i, '').replace(/\s/g, '');
    if (code.length === GUEST_PASS_DIGITS) {
      const visitor = await this.prisma.visitor.findFirst({
        where: { societyId: auth.societyId, passCode: code, status: 'EXPECTED' },
        include,
      });
      if (visitor) return { kind: 'visitor', visitor: visitorView(visitor) };
    } else {
      const staff = await this.prisma.dailyHelp.findFirst({
        where: { societyId: auth.societyId, passCode: code },
        include: {
          flats: { include: { flat: { select: flatLabelSelect } } },
          entries: { where: { outTime: null }, take: 1 },
        },
      });
      if (staff) {
        return {
          kind: 'staff',
          staff: {
            id: staff.id,
            name: staff.name,
            kind: staff.kind,
            phone: staff.phone,
            flatLabels: staff.flats.map((f) => flatLabel(f.flat) ?? ''),
            inside: staff.entries.length > 0,
          },
        };
      }
    }
    throw new ApiError(HttpStatus.NOT_FOUND, 'PASS_NOT_FOUND', 'No valid pass with this code');
  }

  /** Cancel a visitor who hasn't arrived yet (own flat, or any for admins). */
  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async cancel(@Auth() auth: AuthContext, @Param('id') id: string): Promise<void> {
    const visitor = await this.prisma.visitor.findFirst({
      where: { id, societyId: auth.societyId, ...(auth.role === Role.ADMIN ? {} : { flatId: auth.flatId ?? '' }) },
    });
    if (!visitor) throw ApiError.notFound('Visitor not found');
    if (visitor.status !== 'EXPECTED') {
      throw new ApiError(HttpStatus.CONFLICT, 'VISITOR_ARRIVED', 'This visitor has already arrived');
    }
    await this.prisma.visitor.delete({ where: { id } });
  }
}
