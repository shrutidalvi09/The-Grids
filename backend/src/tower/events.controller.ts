import { Body, Controller, Delete, HttpCode, HttpStatus, Param, Patch, Post } from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsDate, IsOptional, IsString, Length, Matches, MaxLength, ValidateIf } from 'class-validator';
import { Auth, type AuthContext, Roles } from '../auth/auth-context.js';
import { ApiError } from '../common/api-error.js';
import { Role } from '../generated/prisma/enums.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { type EventView, eventView } from './residents.controller.js';

class EventDto {
  @IsString()
  @Length(3, 100)
  title!: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string | null;

  @IsString()
  @Length(2, 80)
  location!: string;

  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsString()
  @Matches(/^\/uploads\/[\w-]+\.(jpg|png|webp)$/, { message: 'imageUrl must come from /v1/uploads' })
  imageUrl?: string | null;

  @Type(() => Date)
  @IsDate()
  startsAt!: Date;

  @IsOptional()
  @Type(() => Date)
  @IsDate()
  endsAt?: Date | null;
}

/** Admin: society events (Yoga, Movie Night…). Everyone is told about new ones. */
@Roles(Role.ADMIN)
@Controller('events')
export class EventsController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  @Post()
  async create(@Auth() auth: AuthContext, @Body() body: EventDto): Promise<EventView> {
    const event = await this.prisma.event.create({
      data: { ...data(body), societyId: auth.societyId, createdById: auth.userId },
    });
    const society = await this.prisma.society.findUniqueOrThrow({ where: { id: auth.societyId }, select: { timezone: true } });
    await this.notifications.notify(
      auth.societyId,
      await this.notifications.activeMemberIds(auth.societyId),
      {
        type: 'event',
        message: { key: 'event_new', title: event.title, startsAt: event.startsAt, timezone: society.timezone },
        data: { eventId: event.id },
      },
      auth.userId,
    );
    return eventView(event);
  }

  @Patch(':id')
  async update(@Auth() auth: AuthContext, @Param('id') id: string, @Body() body: EventDto): Promise<EventView> {
    const { count } = await this.prisma.event.updateMany({ where: { id, societyId: auth.societyId }, data: data(body) });
    if (count === 0) throw ApiError.notFound('Event not found');
    return eventView(await this.prisma.event.findUniqueOrThrow({ where: { id } }));
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(@Auth() auth: AuthContext, @Param('id') id: string): Promise<void> {
    const { count } = await this.prisma.event.deleteMany({ where: { id, societyId: auth.societyId } });
    if (count === 0) throw ApiError.notFound('Event not found');
  }
}

function data(body: EventDto) {
  if (body.endsAt && body.endsAt <= body.startsAt) {
    throw new ApiError(HttpStatus.BAD_REQUEST, 'VALIDATION_FAILED', 'endsAt must be after startsAt');
  }
  return {
    title: body.title.trim(),
    description: body.description?.trim() || null,
    location: body.location.trim(),
    imageUrl: body.imageUrl ?? null,
    startsAt: body.startsAt,
    endsAt: body.endsAt ?? null,
  };
}
