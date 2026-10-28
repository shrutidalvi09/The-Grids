import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Patch, Post } from '@nestjs/common';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsDate,
  IsOptional,
  IsString,
  Length,
  Matches,
  MaxLength,
} from 'class-validator';
import { Auth, type AuthContext, Roles } from '../auth/auth-context.js';
import { ApiError } from '../common/api-error.js';
import { flatLabel, flatLabelSelect } from '../common/queries.js';
import { Prisma } from '../generated/prisma/client.js';
import { Role } from '../generated/prisma/enums.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import { PrismaService } from '../prisma/prisma.service.js';

class CommunityDto {
  @IsString()
  @Length(2, 60)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string | null;

  @IsOptional()
  @IsString()
  @Matches(/^\/uploads\/[\w-]+\.(jpg|png|webp)$/, { message: 'photoUrl must come from /v1/uploads' })
  photoUrl?: string | null;

  /** The full member list; replaces the current one on update. */
  @IsArray()
  @ArrayMaxSize(500)
  @IsString({ each: true })
  memberIds!: string[];
}

class AnnouncementDto {
  @IsString()
  @Length(3, 120)
  title!: string;

  @IsString()
  @Length(1, 2000)
  body!: string;

  @IsOptional()
  @Type(() => Date)
  @IsDate()
  eventAt?: Date | null;

  @IsOptional()
  @Type(() => Date)
  @IsDate()
  endsAt?: Date | null;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  venue?: string | null;
}

export interface AnnouncementView {
  id: string;
  communityId: string;
  title: string;
  body: string;
  eventAt: Date | null;
  endsAt: Date | null;
  venue: string | null;
  authorName: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface CommunitySummary {
  id: string;
  name: string;
  description: string | null;
  photoUrl: string | null;
  memberCount: number;
  isMember: boolean;
  latestAnnouncement: AnnouncementView | null;
}

export interface CommunityMemberView {
  userId: string;
  name: string;
  flatLabel: string | null;
}

export interface CommunityDetail extends CommunitySummary {
  members: CommunityMemberView[];
  announcements: AnnouncementView[];
}

const announcementInclude = { author: { select: { name: true } } } as const;
type AnnouncementRow = Prisma.AnnouncementGetPayload<{ include: typeof announcementInclude }>;

/** Clubs (Yoga Club, Book Readers…) and their announcements. */
@Controller()
export class CommunitiesController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  @Get('communities')
  async list(@Auth() auth: AuthContext): Promise<CommunitySummary[]> {
    const communities = await this.prisma.community.findMany({
      where: { societyId: auth.societyId },
      include: {
        _count: { select: { members: true } },
        members: { where: { userId: auth.userId }, select: { userId: true } },
        announcements: { include: announcementInclude, orderBy: { createdAt: 'desc' }, take: 1 },
      },
      orderBy: { name: 'asc' },
    });
    return communities.map((c) => ({
      id: c.id,
      name: c.name,
      description: c.description,
      photoUrl: c.photoUrl,
      memberCount: c._count.members,
      isMember: c.members.length > 0,
      latestAnnouncement: c.announcements[0] ? announcementView(c.announcements[0]) : null,
    }));
  }

  /** Admin: residents to pick from when creating or editing a club. */
  @Roles(Role.ADMIN)
  @Get('communities/candidates')
  async candidates(@Auth() auth: AuthContext): Promise<CommunityMemberView[]> {
    const memberships = await this.prisma.membership.findMany({
      where: { societyId: auth.societyId, status: 'ACTIVE' },
      include: { user: { select: { name: true } }, flat: { select: flatLabelSelect } },
    });
    return sortByFlat(dedupeByUser(memberships));
  }

  @Get('communities/:id')
  async get(@Auth() auth: AuthContext, @Param('id') id: string): Promise<CommunityDetail> {
    const community = await this.prisma.community.findFirst({
      where: { id, societyId: auth.societyId },
      include: {
        members: { select: { userId: true } },
        announcements: { include: announcementInclude, orderBy: { createdAt: 'desc' } },
      },
    });
    if (!community) throw ApiError.notFound('Community not found');
    const memberIds = community.members.map((m) => m.userId);
    const memberships = await this.prisma.membership.findMany({
      where: { societyId: auth.societyId, userId: { in: memberIds } },
      include: { user: { select: { name: true } }, flat: { select: flatLabelSelect } },
    });
    const announcements = community.announcements.map(announcementView);
    return {
      id: community.id,
      name: community.name,
      description: community.description,
      photoUrl: community.photoUrl,
      memberCount: memberIds.length,
      isMember: memberIds.includes(auth.userId),
      latestAnnouncement: announcements[0] ?? null,
      members: sortByFlat(dedupeByUser(memberships)),
      announcements,
    };
  }

  @Roles(Role.ADMIN)
  @Post('communities')
  async create(@Auth() auth: AuthContext, @Body() body: CommunityDto): Promise<CommunityDetail> {
    const memberIds = await this.assertMembers(auth, body.memberIds);
    const community = await this.uniqueName(() =>
      this.prisma.community.create({
        data: {
          ...communityData(body),
          societyId: auth.societyId,
          createdById: auth.userId,
          members: { create: memberIds.map((userId) => ({ userId })) },
        },
      }),
    );
    return this.get(auth, community.id);
  }

  @Roles(Role.ADMIN)
  @Patch('communities/:id')
  async update(@Auth() auth: AuthContext, @Param('id') id: string, @Body() body: CommunityDto): Promise<CommunityDetail> {
    await this.findCommunity(auth, id);
    const memberIds = await this.assertMembers(auth, body.memberIds);
    await this.uniqueName(() =>
      this.prisma.$transaction([
        this.prisma.community.update({ where: { id }, data: communityData(body) }),
        this.prisma.communityMember.deleteMany({ where: { communityId: id, userId: { notIn: memberIds } } }),
        this.prisma.communityMember.createMany({
          data: memberIds.map((userId) => ({ communityId: id, userId })),
          skipDuplicates: true,
        }),
      ]),
    );
    return this.get(auth, id);
  }

  @Roles(Role.ADMIN)
  @Delete('communities/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(@Auth() auth: AuthContext, @Param('id') id: string): Promise<void> {
    const { count } = await this.prisma.community.deleteMany({ where: { id, societyId: auth.societyId } });
    if (count === 0) throw ApiError.notFound('Community not found');
  }

  /** Anyone in the society may join or leave a club. */
  @Post('communities/:id/join')
  async join(@Auth() auth: AuthContext, @Param('id') id: string): Promise<CommunityDetail> {
    await this.findCommunity(auth, id);
    await this.prisma.communityMember.createMany({ data: [{ communityId: id, userId: auth.userId }], skipDuplicates: true });
    return this.get(auth, id);
  }

  @Post('communities/:id/leave')
  async leave(@Auth() auth: AuthContext, @Param('id') id: string): Promise<CommunityDetail> {
    await this.findCommunity(auth, id);
    await this.prisma.communityMember.deleteMany({ where: { communityId: id, userId: auth.userId } });
    return this.get(auth, id);
  }

  @Roles(Role.ADMIN)
  @Post('communities/:id/announcements')
  async announce(@Auth() auth: AuthContext, @Param('id') id: string, @Body() body: AnnouncementDto): Promise<AnnouncementView> {
    const community = await this.findCommunity(auth, id);
    const announcement = await this.prisma.announcement.create({
      data: { ...announcementData(body), communityId: id, authorId: auth.userId },
      include: announcementInclude,
    });
    const members = await this.prisma.communityMember.findMany({ where: { communityId: id }, select: { userId: true } });
    await this.notifications.notify(
      auth.societyId,
      members.map((m) => m.userId),
      {
        type: 'announcement',
        title: community.name,
        body: announcement.title,
        data: { communityId: id, announcementId: announcement.id },
      },
      auth.userId,
    );
    return announcementView(announcement);
  }

  @Roles(Role.ADMIN)
  @Patch('announcements/:id')
  async updateAnnouncement(
    @Auth() auth: AuthContext,
    @Param('id') id: string,
    @Body() body: AnnouncementDto,
  ): Promise<AnnouncementView> {
    await this.findAnnouncement(auth, id);
    return announcementView(
      await this.prisma.announcement.update({ where: { id }, data: announcementData(body), include: announcementInclude }),
    );
  }

  @Roles(Role.ADMIN)
  @Delete('announcements/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async removeAnnouncement(@Auth() auth: AuthContext, @Param('id') id: string): Promise<void> {
    await this.findAnnouncement(auth, id);
    await this.prisma.announcement.delete({ where: { id } });
  }

  private async findCommunity(auth: AuthContext, id: string) {
    const community = await this.prisma.community.findFirst({ where: { id, societyId: auth.societyId } });
    if (!community) throw ApiError.notFound('Community not found');
    return community;
  }

  private async findAnnouncement(auth: AuthContext, id: string) {
    const announcement = await this.prisma.announcement.findFirst({
      where: { id, community: { societyId: auth.societyId } },
    });
    if (!announcement) throw ApiError.notFound('Announcement not found');
    return announcement;
  }

  /** Only active members of this society can be added to its clubs. */
  private async assertMembers(auth: AuthContext, ids: string[]): Promise<string[]> {
    const unique = [...new Set(ids)];
    if (!unique.length) return [];
    const found = await this.prisma.membership.findMany({
      where: { societyId: auth.societyId, status: 'ACTIVE', userId: { in: unique } },
      select: { userId: true },
      distinct: ['userId'],
    });
    if (found.length !== unique.length) throw ApiError.notFound('Some members are not part of this society');
    return unique;
  }

  private async uniqueName<T>(write: () => Promise<T>): Promise<T> {
    try {
      return await write();
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new ApiError(HttpStatus.CONFLICT, 'COMMUNITY_EXISTS', 'A community with this name already exists');
      }
      throw e;
    }
  }
}

function communityData(body: CommunityDto) {
  return {
    name: body.name.trim(),
    description: body.description?.trim() || null,
    photoUrl: body.photoUrl || null,
  };
}

function announcementData(body: AnnouncementDto) {
  if (body.endsAt && (!body.eventAt || body.endsAt <= body.eventAt)) {
    throw new ApiError(HttpStatus.BAD_REQUEST, 'VALIDATION_FAILED', 'endsAt must be after eventAt');
  }
  return {
    title: body.title.trim(),
    body: body.body.trim(),
    eventAt: body.eventAt ?? null,
    endsAt: body.endsAt ?? null,
    venue: body.venue?.trim() || null,
  };
}

function announcementView(a: AnnouncementRow): AnnouncementView {
  return {
    id: a.id,
    communityId: a.communityId,
    title: a.title,
    body: a.body,
    eventAt: a.eventAt,
    endsAt: a.endsAt,
    venue: a.venue,
    authorName: a.author.name,
    createdAt: a.createdAt,
    updatedAt: a.updatedAt,
  };
}

type MembershipRow = {
  userId: string;
  user: { name: string };
  flat: { number: string; tower: { name: string } } | null;
};

/** One row per person, preferring a membership that has a flat. */
function dedupeByUser(memberships: MembershipRow[]): CommunityMemberView[] {
  const byUser = new Map<string, CommunityMemberView>();
  for (const m of memberships) {
    const existing = byUser.get(m.userId);
    if (!existing || (!existing.flatLabel && m.flat)) {
      byUser.set(m.userId, { userId: m.userId, name: m.user.name, flatLabel: flatLabel(m.flat) });
    }
  }
  return [...byUser.values()];
}

function sortByFlat(members: CommunityMemberView[]): CommunityMemberView[] {
  return members.sort(
    (a, b) =>
      (a.flatLabel ?? '~').localeCompare(b.flatLabel ?? '~', 'en', { numeric: true }) || a.name.localeCompare(b.name),
  );
}
