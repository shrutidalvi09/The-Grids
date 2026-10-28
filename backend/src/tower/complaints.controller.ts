import { Body, Controller, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { IsEnum, IsOptional, IsString, Length, Matches, MaxLength } from 'class-validator';
import { Auth, type AuthContext, Roles } from '../auth/auth-context.js';
import { ApiError } from '../common/api-error.js';
import { flatLabel, flatLabelSelect, LimitQuery } from '../common/queries.js';
import { ComplaintStatus, Role } from '../generated/prisma/enums.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import { PrismaService } from '../prisma/prisma.service.js';

class ComplaintsQuery extends LimitQuery {
  @IsOptional()
  @IsEnum(ComplaintStatus)
  status?: ComplaintStatus;
}

class PostComplaintDto {
  @IsString()
  @Length(3, 120)
  title!: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  category?: string;

  @IsString()
  @Length(5, 2000)
  description!: string;

  @IsOptional()
  @Matches(/^\/uploads\/[\w-]+\.(jpg|png|webp)$/, { message: 'photoUrl must come from /v1/uploads' })
  photoUrl?: string;
}

class UpdateStatusDto {
  @IsEnum(ComplaintStatus)
  status!: ComplaintStatus;
}

export interface ComplaintView {
  id: string;
  title: string;
  category: string | null;
  description: string;
  photoUrl: string | null;
  status: ComplaintStatus;
  flatLabel: string | null;
  raisedBy: string;
  createdAt: Date;
  resolvedAt: Date | null;
}

const include = {
  flat: { select: flatLabelSelect },
  raisedBy: { select: { name: true } },
} as const;

/** Admins see and manage every complaint; residents see their flat's. */
@Controller('complaints')
export class ComplaintsController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  @Get()
  async list(@Auth() auth: AuthContext, @Query() query: ComplaintsQuery): Promise<ComplaintView[]> {
    if (auth.role !== 'ADMIN' && !auth.flatId) return [];
    const complaints = await this.prisma.complaint.findMany({
      where: {
        societyId: auth.societyId,
        ...(auth.role === 'ADMIN' ? {} : { flatId: auth.flatId }),
        ...(query.status ? { status: query.status } : {}),
      },
      include,
      orderBy: { createdAt: 'desc' },
      take: query.limit ?? 50,
    });
    return complaints.map(toView);
  }

  @Post()
  async create(@Auth() auth: AuthContext, @Body() body: PostComplaintDto): Promise<ComplaintView> {
    const complaint = await this.prisma.complaint.create({
      data: {
        societyId: auth.societyId,
        flatId: auth.flatId,
        raisedById: auth.userId,
        title: body.title.trim(),
        category: body.category?.trim() || null,
        description: body.description.trim(),
        photoUrl: body.photoUrl ?? null,
      },
      include,
    });
    return toView(complaint);
  }

  @Roles(Role.ADMIN)
  @Patch(':id/status')
  async updateStatus(
    @Auth() auth: AuthContext,
    @Param('id') id: string,
    @Body() body: UpdateStatusDto,
  ): Promise<ComplaintView> {
    const { count } = await this.prisma.complaint.updateMany({
      where: { id, societyId: auth.societyId },
      data: { status: body.status, resolvedAt: body.status === 'RESOLVED' ? new Date() : null },
    });
    if (count === 0) throw ApiError.notFound('Complaint not found');
    const complaint = await this.prisma.complaint.findUniqueOrThrow({ where: { id }, include });
    const statusText = { OPEN: 'reopened', IN_PROGRESS: 'in progress', RESOLVED: 'resolved' }[body.status];
    await this.notifications.notify(
      auth.societyId,
      [complaint.raisedById],
      { type: 'complaint', title: 'Complaint update', body: `"${complaint.title}" is ${statusText}.`, data: { complaintId: id } },
      auth.userId,
    );
    return toView(complaint);
  }
}

function toView(c: {
  id: string;
  title: string;
  category: string | null;
  description: string;
  photoUrl: string | null;
  status: ComplaintStatus;
  createdAt: Date;
  resolvedAt: Date | null;
  flat: { number: string; tower: { name: string } } | null;
  raisedBy: { name: string };
}): ComplaintView {
  return {
    id: c.id,
    title: c.title,
    category: c.category,
    description: c.description,
    photoUrl: c.photoUrl,
    status: c.status,
    flatLabel: flatLabel(c.flat),
    raisedBy: c.raisedBy.name,
    createdAt: c.createdAt,
    resolvedAt: c.resolvedAt,
  };
}
