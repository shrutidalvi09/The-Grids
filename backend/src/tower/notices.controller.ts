import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Patch, Post, Query } from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsBoolean, IsDate, IsOptional, IsString, Length, MaxLength } from 'class-validator';
import { Auth, type AuthContext, Roles } from '../auth/auth-context.js';
import { ApiError } from '../common/api-error.js';
import { towerScope } from '../common/member.js';
import { LimitQuery } from '../common/queries.js';
import { Role } from '../generated/prisma/enums.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import { PrismaService } from '../prisma/prisma.service.js';

class NoticeDto {
  @IsString()
  @Length(3, 120)
  title!: string;

  @IsString()
  @Length(1, 2000)
  body!: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  category?: string | null;

  /** When the work/event happens. */
  @IsOptional()
  @Type(() => Date)
  @IsDate()
  scheduledAt?: Date | null;

  /** Show as the Home banner until it expires. */
  @IsOptional()
  @IsBoolean()
  isAlert?: boolean;

  @IsOptional()
  @Type(() => Date)
  @IsDate()
  expiresAt?: Date | null;

  /** Limit to one tower; omit for the whole society. */
  @IsOptional()
  @IsString()
  towerId?: string | null;
}

export interface NoticeView {
  id: string;
  title: string;
  body: string;
  category: string | null;
  isAlert: boolean;
  scheduledAt: Date | null;
  expiresAt: Date | null;
  towerName: string | null;
  createdAt: Date;
}

@Controller('notices')
export class NoticesController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  @Get()
  async list(@Auth() auth: AuthContext, @Query() query: LimitQuery): Promise<NoticeView[]> {
    const notices = await this.prisma.notice.findMany({
      where: { societyId: auth.societyId, ...(await towerScope(this.prisma, auth)) },
      include: { tower: { select: { name: true } } },
      orderBy: { createdAt: 'desc' },
      take: query.limit ?? 50,
    });
    return notices.map(toView);
  }

  @Roles(Role.ADMIN)
  @Post()
  async create(@Auth() auth: AuthContext, @Body() body: NoticeDto): Promise<NoticeView> {
    await this.assertTower(auth, body.towerId);
    const notice = await this.prisma.notice.create({
      data: { ...data(body), societyId: auth.societyId, createdById: auth.userId },
      include: { tower: { select: { name: true } } },
    });
    await this.notifications.notify(
      auth.societyId,
      await this.notifications.activeMemberIds(auth.societyId, { towerId: notice.towerId }),
      {
        type: notice.isAlert ? 'alert' : 'notice',
        title: notice.title,
        body: notice.body.length > 140 ? `${notice.body.slice(0, 137)}…` : notice.body,
        data: { noticeId: notice.id },
      },
      auth.userId,
    );
    return toView(notice);
  }

  @Roles(Role.ADMIN)
  @Patch(':id')
  async update(@Auth() auth: AuthContext, @Param('id') id: string, @Body() body: NoticeDto): Promise<NoticeView> {
    await this.assertTower(auth, body.towerId);
    const { count } = await this.prisma.notice.updateMany({ where: { id, societyId: auth.societyId }, data: data(body) });
    if (count === 0) throw ApiError.notFound('Notice not found');
    return toView(
      await this.prisma.notice.findUniqueOrThrow({ where: { id }, include: { tower: { select: { name: true } } } }),
    );
  }

  @Roles(Role.ADMIN)
  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(@Auth() auth: AuthContext, @Param('id') id: string): Promise<void> {
    const { count } = await this.prisma.notice.deleteMany({ where: { id, societyId: auth.societyId } });
    if (count === 0) throw ApiError.notFound('Notice not found');
  }

  private async assertTower(auth: AuthContext, towerId?: string | null) {
    if (!towerId) return;
    const tower = await this.prisma.tower.findFirst({ where: { id: towerId, societyId: auth.societyId } });
    if (!tower) throw ApiError.notFound('Tower not found');
  }
}

function data(body: NoticeDto) {
  const isAlert = body.isAlert ?? false;
  // Alerts need an end; default to a day after the event (or now).
  const expiresAt =
    body.expiresAt ?? (isAlert ? new Date((body.scheduledAt ?? new Date()).getTime() + 86_400_000) : null);
  return {
    title: body.title.trim(),
    body: body.body.trim(),
    category: body.category?.trim() || null,
    scheduledAt: body.scheduledAt ?? null,
    isAlert,
    expiresAt,
    towerId: body.towerId || null,
  };
}

function toView(n: {
  id: string;
  title: string;
  body: string;
  category: string | null;
  isAlert: boolean;
  scheduledAt: Date | null;
  expiresAt: Date | null;
  createdAt: Date;
  tower: { name: string } | null;
}): NoticeView {
  return {
    id: n.id,
    title: n.title,
    body: n.body,
    category: n.category,
    isAlert: n.isAlert,
    scheduledAt: n.scheduledAt,
    expiresAt: n.expiresAt,
    towerName: n.tower?.name ?? null,
    createdAt: n.createdAt,
  };
}
