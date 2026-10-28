import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Post, Put, Query } from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsDate, IsIn, IsOptional, IsString, Length } from 'class-validator';
import { Auth, type AuthContext } from '../auth/auth-context.js';
import { ApiError } from '../common/api-error.js';
import { LimitQuery } from '../common/queries.js';
import { PrismaService } from '../prisma/prisma.service.js';

class NotificationListQuery extends LimitQuery {
  /** Older than this (for paging back). */
  @IsOptional()
  @Type(() => Date)
  @IsDate()
  before?: Date;
}

class DeviceDto {
  @IsString()
  @Length(20, 512)
  token!: string;

  @IsIn(['android', 'ios'])
  platform!: 'android' | 'ios';
}

export interface NotificationView {
  id: string;
  type: string;
  title: string;
  body: string;
  data: Record<string, string> | null;
  read: boolean;
  createdAt: Date;
}

/** The bell: your notifications in the society you're signed in to. */
@Controller()
export class NotificationsController {
  constructor(private readonly prisma: PrismaService) {}

  @Get('notifications')
  async list(@Auth() auth: AuthContext, @Query() query: NotificationListQuery): Promise<NotificationView[]> {
    const rows = await this.prisma.notification.findMany({
      where: { userId: auth.userId, societyId: auth.societyId, ...(query.before ? { createdAt: { lt: query.before } } : {}) },
      orderBy: { createdAt: 'desc' },
      take: query.limit ?? 50,
    });
    return rows.map((n) => ({
      id: n.id,
      type: n.type,
      title: n.title,
      body: n.body,
      data: (n.data as Record<string, string> | null) ?? null,
      read: n.readAt !== null,
      createdAt: n.createdAt,
    }));
  }

  @Get('notifications/unread-count')
  async unreadCount(@Auth() auth: AuthContext): Promise<{ count: number }> {
    const count = await this.prisma.notification.count({
      where: { userId: auth.userId, societyId: auth.societyId, readAt: null },
    });
    return { count };
  }

  @Post('notifications/:id/read')
  @HttpCode(HttpStatus.NO_CONTENT)
  async markRead(@Auth() auth: AuthContext, @Param('id') id: string): Promise<void> {
    const { count } = await this.prisma.notification.updateMany({
      where: { id, userId: auth.userId, readAt: null },
      data: { readAt: new Date() },
    });
    if (count === 0) {
      const exists = await this.prisma.notification.count({ where: { id, userId: auth.userId } });
      if (!exists) throw ApiError.notFound('Notification not found');
    }
  }

  @Post('notifications/read-all')
  async markAllRead(@Auth() auth: AuthContext): Promise<{ updated: number }> {
    const { count } = await this.prisma.notification.updateMany({
      where: { userId: auth.userId, societyId: auth.societyId, readAt: null },
      data: { readAt: new Date() },
    });
    return { updated: count };
  }

  /** Registers this phone for push. A token moves to whoever signed in last. */
  @Put('devices')
  @HttpCode(HttpStatus.NO_CONTENT)
  async register(@Auth() auth: AuthContext, @Body() body: DeviceDto): Promise<void> {
    await this.prisma.deviceToken.upsert({
      where: { token: body.token },
      update: { userId: auth.userId, platform: body.platform },
      create: { token: body.token, userId: auth.userId, platform: body.platform },
    });
  }

  /** Called on sign-out so the phone stops getting this person's pushes. */
  @Delete('devices/:token')
  @HttpCode(HttpStatus.NO_CONTENT)
  async unregister(@Auth() auth: AuthContext, @Param('token') token: string): Promise<void> {
    await this.prisma.deviceToken.deleteMany({ where: { token, userId: auth.userId } });
  }
}
