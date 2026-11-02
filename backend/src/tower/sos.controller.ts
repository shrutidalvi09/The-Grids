import { Body, Controller, Get, HttpCode, HttpStatus, Param, Post } from '@nestjs/common';
import { IsOptional, IsString, MaxLength } from 'class-validator';
import { Auth, type AuthContext, Everyone, Roles } from '../auth/auth-context.js';
import { ApiError } from '../common/api-error.js';
import { isGate } from '../common/member.js';
import { flatLabel, flatLabelSelect } from '../common/queries.js';
import { Role, type SosStatus } from '../generated/prisma/enums.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import { PrismaService } from '../prisma/prisma.service.js';

class RaiseSosDto {
  /** Optional: "Fire in kitchen", "Medical"… */
  @IsOptional()
  @IsString()
  @MaxLength(120)
  note?: string | null;
}

export interface SosView {
  id: string;
  flatLabel: string | null;
  raisedBy: { name: string; phone: string } | null;
  note: string | null;
  status: SosStatus;
  createdAt: Date;
  resolvedAt: Date | null;
  resolvedBy: string | null;
}

const include = {
  flat: { select: flatLabelSelect },
  raisedBy: { select: { name: true, phone: true } },
  resolvedBy: { select: { name: true } },
} as const;

function sosView(a: {
  id: string;
  note: string | null;
  status: SosStatus;
  createdAt: Date;
  resolvedAt: Date | null;
  flat: { number: string; tower: { name: string } } | null;
  raisedBy: { name: string; phone: string } | null;
  resolvedBy: { name: string } | null;
}): SosView {
  return {
    id: a.id,
    flatLabel: flatLabel(a.flat),
    raisedBy: a.raisedBy,
    note: a.note,
    status: a.status,
    createdAt: a.createdAt,
    resolvedAt: a.resolvedAt,
    resolvedBy: a.resolvedBy?.name ?? null,
  };
}

/** A tap that should never be missed. */
const DOUBLE_TAP_MS = 2 * 60_000;

/**
 * The panic button: one tap alerts every guard, every admin and the rest of
 * the household, with the flat number. These notifications ignore the
 * person's notification switches.
 */
@Controller('sos')
export class SosController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  @Roles(Role.ADMIN, Role.OWNER, Role.TENANT)
  @Post()
  async raise(@Auth() auth: AuthContext, @Body() body: RaiseSosDto): Promise<SosView> {
    // A second tap right after the first doesn't send the alarm twice.
    const recent = await this.prisma.sosAlert.findFirst({
      where: {
        societyId: auth.societyId,
        raisedById: auth.userId,
        status: 'ACTIVE',
        createdAt: { gte: new Date(Date.now() - DOUBLE_TAP_MS) },
      },
      include,
    });
    if (recent) return sosView(recent);

    const alert = await this.prisma.sosAlert.create({
      data: { societyId: auth.societyId, flatId: auth.flatId, raisedById: auth.userId, note: body.note?.trim() || null },
      include,
    });
    const recipients = [
      ...(await this.notifications.gateStaffIds(auth.societyId, { withAdmins: true })),
      ...(auth.flatId ? await this.notifications.flatResidentIds(auth.societyId, auth.flatId) : []),
    ];
    await this.notifications.notify(
      auth.societyId,
      recipients,
      {
        type: 'sos',
        message: { key: 'sos', name: alert.raisedBy?.name ?? '', flat: flatLabel(alert.flat) },
        data: { sosId: alert.id },
      },
      auth.userId,
    );
    return sosView(alert);
  }

  /** The gate and admins: every alert of the last day. Residents: their flat's. */
  @Everyone()
  @Get()
  async list(@Auth() auth: AuthContext): Promise<SosView[]> {
    const since = new Date(Date.now() - 86_400_000);
    const alerts = await this.prisma.sosAlert.findMany({
      where: {
        societyId: auth.societyId,
        AND: [
          { OR: [{ status: 'ACTIVE' }, { createdAt: { gte: since } }] },
          isGate(auth) ? {} : { OR: [{ raisedById: auth.userId }, ...(auth.flatId ? [{ flatId: auth.flatId }] : [])] },
        ],
      },
      include,
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
    // Active ones first.
    return alerts.sort((a, b) => Number(b.status === 'ACTIVE') - Number(a.status === 'ACTIVE')).map(sosView);
  }

  /** The gate, an admin, or the household marks the emergency handled. */
  @Everyone()
  @Post(':id/resolve')
  @HttpCode(HttpStatus.OK)
  async resolve(@Auth() auth: AuthContext, @Param('id') id: string): Promise<SosView> {
    const alert = await this.prisma.sosAlert.findFirst({ where: { id, societyId: auth.societyId } });
    const mine = alert && (alert.raisedById === auth.userId || (auth.flatId !== null && alert.flatId === auth.flatId));
    if (!alert || !(isGate(auth) || mine)) throw ApiError.notFound('Alert not found');
    const updated =
      alert.status === 'ACTIVE'
        ? await this.prisma.sosAlert.update({
            where: { id },
            data: { status: 'RESOLVED', resolvedAt: new Date(), resolvedById: auth.userId },
            include,
          })
        : await this.prisma.sosAlert.findUniqueOrThrow({ where: { id }, include });
    return sosView(updated);
  }
}
