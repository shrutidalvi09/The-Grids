import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Post, Query } from '@nestjs/common';
import { IsIn, IsOptional, IsString, Length, Matches } from 'class-validator';
import { Auth, type AuthContext, Everyone, Roles } from '../auth/auth-context.js';
import { ApiError } from '../common/api-error.js';
import { STAFF_CODE_DIGITS, withUniqueCode } from '../common/codes.js';
import { isGate } from '../common/member.js';
import { normalizeIndianMobile } from '../common/phone.js';
import { flatLabel, flatLabelSelect } from '../common/queries.js';
import { localDate, zonedToUtc } from '../common/zoned-time.js';
import { Role } from '../generated/prisma/enums.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import { PrismaService } from '../prisma/prisma.service.js';

export const HELP_KINDS = ['Maid', 'Cook', 'Driver', 'Nanny', 'Cleaner', 'Other'] as const;

class AddHelpDto {
  @IsString()
  @Length(2, 60)
  name!: string;

  @IsIn(HELP_KINDS)
  kind!: (typeof HELP_KINDS)[number];

  @IsOptional()
  @IsString()
  @Length(10, 20)
  phone?: string | null;
}

class MonthQuery {
  /** "2026-10"; this month if left out. */
  @IsOptional()
  @Matches(/^\d{4}-(0[1-9]|1[0-2])$/)
  month?: string;
}

export interface DailyHelpView {
  id: string;
  name: string;
  kind: string;
  phone: string | null;
  /** Permanent gate code; shown to the flats they work for and admins. */
  passCode: string | null;
  /** Flats they work for (the gate and admins only). */
  flatLabels: string[];
  inside: boolean;
  lastIn: Date | null;
  /** Days they came this month. */
  daysThisMonth: number;
}

export interface AttendanceView {
  month: string;
  days: number;
  entries: { inTime: Date; outTime: Date | null }[];
}

const include = {
  flats: { include: { flat: { select: flatLabelSelect } } },
} as const;

/**
 * Maids, cooks and drivers who come every day. Residents add them to their
 * flat and get a permanent gate code; the gate marks them in and out, and
 * each flat sees a monthly attendance count.
 */
@Controller('daily-help')
export class DailyHelpController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  @Everyone()
  @Get()
  async list(@Auth() auth: AuthContext): Promise<DailyHelpView[]> {
    const gate = isGate(auth);
    if (!gate && !auth.flatId) return [];
    const helpers = await this.prisma.dailyHelp.findMany({
      where: { societyId: auth.societyId, ...(gate ? {} : { flats: { some: { flatId: auth.flatId! } } }) },
      include,
      orderBy: { name: 'asc' },
    });
    return this.views(auth, helpers);
  }

  /** Residents add a helper to their flat. Same phone number → same person, linked to one more flat. */
  @Roles(Role.OWNER, Role.TENANT)
  @Post()
  async add(@Auth() auth: AuthContext, @Body() body: AddHelpDto): Promise<DailyHelpView> {
    if (!auth.flatId) throw ApiError.forbidden('You are not linked to a flat');
    let phone: string | null = null;
    if (body.phone) {
      phone = normalizeIndianMobile(body.phone);
      if (!phone) {
        throw new ApiError(HttpStatus.BAD_REQUEST, 'VALIDATION_FAILED', 'Enter a valid Indian mobile number', {
          fields: ['phone must be a valid Indian mobile number'],
        });
      }
    }
    const existing = phone ? await this.prisma.dailyHelp.findFirst({ where: { societyId: auth.societyId, phone } }) : null;
    const helper =
      existing ??
      (await withUniqueCode(STAFF_CODE_DIGITS, (passCode) =>
        this.prisma.dailyHelp.create({
          data: { societyId: auth.societyId, name: body.name.trim(), kind: body.kind, phone, passCode },
        }),
      ));
    await this.prisma.dailyHelpFlat.upsert({
      where: { dailyHelpId_flatId: { dailyHelpId: helper.id, flatId: auth.flatId } },
      update: {},
      create: { dailyHelpId: helper.id, flatId: auth.flatId, addedById: auth.userId },
    });
    const [view] = await this.views(auth, [await this.prisma.dailyHelp.findUniqueOrThrow({ where: { id: helper.id }, include })]);
    return view;
  }

  /** Residents remove a helper from their flat; admins remove them from the society. */
  @Roles(Role.ADMIN, Role.OWNER, Role.TENANT)
  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(@Auth() auth: AuthContext, @Param('id') id: string): Promise<void> {
    const helper = await this.prisma.dailyHelp.findFirst({
      where: { id, societyId: auth.societyId },
      include: { flats: { select: { flatId: true } } },
    });
    if (!helper) throw ApiError.notFound('Not found');
    if (auth.role === Role.ADMIN) {
      await this.prisma.dailyHelp.delete({ where: { id } });
      return;
    }
    if (!helper.flats.some((f) => f.flatId === auth.flatId)) throw ApiError.notFound('Not found');
    await this.prisma.dailyHelpFlat.delete({ where: { dailyHelpId_flatId: { dailyHelpId: id, flatId: auth.flatId! } } });
    // Nobody employs them any more: their code stops working.
    if (helper.flats.length === 1) await this.prisma.dailyHelp.delete({ where: { id } });
  }

  /** The gate marks them in, or out if they're inside. */
  @Roles(Role.ADMIN, Role.GUARD)
  @Post(':id/attendance')
  @HttpCode(HttpStatus.OK)
  async mark(@Auth() auth: AuthContext, @Param('id') id: string): Promise<DailyHelpView> {
    const helper = await this.prisma.dailyHelp.findFirst({ where: { id, societyId: auth.societyId }, include });
    if (!helper) throw ApiError.notFound('Not found');
    const open = await this.prisma.dailyHelpEntry.findFirst({ where: { dailyHelpId: id, outTime: null } });
    const now = new Date();
    if (open) {
      await this.prisma.dailyHelpEntry.update({ where: { id: open.id }, data: { outTime: now } });
    } else {
      await this.prisma.dailyHelpEntry.create({ data: { dailyHelpId: id, inTime: now } });
      const flatIds = helper.flats.map((f) => f.flatId);
      const residents = (
        await Promise.all(flatIds.map((flatId) => this.notifications.flatResidentIds(auth.societyId, flatId)))
      ).flat();
      await this.notifications.notify(auth.societyId, residents, {
        type: 'staff',
        message: { key: 'staff_arrived', name: helper.name },
        data: { dailyHelpId: id },
      });
    }
    const [view] = await this.views(auth, [helper]);
    return view;
  }

  /** One month's visits, for the flats they work for, admins and the gate. */
  @Everyone()
  @Get(':id/attendance')
  async attendance(@Auth() auth: AuthContext, @Param('id') id: string, @Query() query: MonthQuery): Promise<AttendanceView> {
    const helper = await this.prisma.dailyHelp.findFirst({
      where: {
        id,
        societyId: auth.societyId,
        ...(isGate(auth) ? {} : { flats: { some: { flatId: auth.flatId ?? '' } } }),
      },
    });
    if (!helper) throw ApiError.notFound('Not found');
    const timezone = await this.timezone(auth.societyId);
    const month = query.month ?? localDate(new Date(), timezone).slice(0, 7);
    const { start, end } = monthRange(month, timezone);
    const entries = await this.prisma.dailyHelpEntry.findMany({
      where: { dailyHelpId: id, inTime: { gte: start, lt: end } },
      orderBy: { inTime: 'desc' },
      select: { inTime: true, outTime: true },
    });
    return { month, days: new Set(entries.map((e) => localDate(e.inTime, timezone))).size, entries };
  }

  private async timezone(societyId: string): Promise<string> {
    const society = await this.prisma.society.findUniqueOrThrow({ where: { id: societyId }, select: { timezone: true } });
    return society.timezone;
  }

  private async views(
    auth: AuthContext,
    helpers: {
      id: string;
      name: string;
      kind: string;
      phone: string | null;
      passCode: string;
      flats: { flatId: string; flat: { number: string; tower: { name: string } } }[];
    }[],
  ): Promise<DailyHelpView[]> {
    if (!helpers.length) return [];
    const timezone = await this.timezone(auth.societyId);
    const { start } = monthRange(localDate(new Date(), timezone).slice(0, 7), timezone);
    const entries = await this.prisma.dailyHelpEntry.findMany({
      where: { dailyHelpId: { in: helpers.map((h) => h.id) }, OR: [{ inTime: { gte: start } }, { outTime: null }] },
      orderBy: { inTime: 'desc' },
    });
    const gate = isGate(auth);
    return helpers.map((h) => {
      const mine = entries.filter((e) => e.dailyHelpId === h.id);
      return {
        id: h.id,
        name: h.name,
        kind: h.kind,
        phone: h.phone,
        // Guards check the code at the gate; they don't need to see it.
        passCode: auth.role === Role.GUARD ? null : h.passCode,
        flatLabels: gate ? h.flats.map((f) => flatLabel(f.flat) ?? '') : [],
        inside: mine.some((e) => e.outTime === null),
        lastIn: mine[0]?.inTime ?? null,
        daysThisMonth: new Set(mine.filter((e) => e.inTime >= start).map((e) => localDate(e.inTime, timezone))).size,
      };
    });
  }
}

/** [start, end) of a "YYYY-MM" month in the society's time zone. */
function monthRange(month: string, timezone: string): { start: Date; end: Date } {
  const [y, m] = month.split('-').map(Number);
  const next = m === 12 ? `${y + 1}-01` : `${y}-${String(m + 1).padStart(2, '0')}`;
  return { start: zonedToUtc(`${month}-01`, '00:00', timezone), end: zonedToUtc(`${next}-01`, '00:00', timezone) };
}
