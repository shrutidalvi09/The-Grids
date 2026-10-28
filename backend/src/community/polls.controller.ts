import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Post, Query } from '@nestjs/common';
import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsDate,
  IsIn,
  IsOptional,
  IsString,
  Length,
  MinDate,
} from 'class-validator';
import { Auth, type AuthContext, Roles } from '../auth/auth-context.js';
import { ApiError } from '../common/api-error.js';
import { LimitQuery } from '../common/queries.js';
import { Prisma } from '../generated/prisma/client.js';
import { Role } from '../generated/prisma/enums.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import { PrismaService } from '../prisma/prisma.service.js';

class PollDto {
  @IsString()
  @Length(5, 200)
  question!: string;

  @IsArray()
  @ArrayMinSize(2)
  @ArrayMaxSize(6)
  @IsString({ each: true })
  @Length(1, 60, { each: true })
  options!: string[];

  /** Omit for a poll that stays open until an admin closes it. */
  @IsOptional()
  @Type(() => Date)
  @IsDate()
  @MinDate(() => new Date())
  closesAt?: Date | null;
}

class VoteDto {
  @IsString()
  optionId!: string;
}

class PollListQuery extends LimitQuery {
  @IsOptional()
  @Transform(({ value }) => String(value).toLowerCase())
  @IsIn(['open', 'closed', 'all'])
  status?: 'open' | 'closed' | 'all';
}

export interface PollView {
  id: string;
  question: string;
  closesAt: Date | null;
  isOpen: boolean;
  createdAt: Date;
  totalVotes: number;
  /** The caller's choice, if they voted. Who voted for what is never shown. */
  myOptionId: string | null;
  /** Counts are hidden until you vote (or the poll closes) so early results don't sway anyone. Admins always see them. */
  resultsVisible: boolean;
  options: { id: string; label: string; votes: number | null }[];
}

const pollInclude = { options: { orderBy: { sortOrder: 'asc' } } } as const;
type PollWithOptions = Prisma.PollGetPayload<{ include: typeof pollInclude }>;

@Controller('polls')
export class PollsController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  /** Open polls first (newest first), then closed ones. */
  @Get()
  async list(@Auth() auth: AuthContext, @Query() query: PollListQuery): Promise<PollView[]> {
    const now = new Date();
    const open: Prisma.PollWhereInput = { OR: [{ closesAt: null }, { closesAt: { gt: now } }] };
    const closed: Prisma.PollWhereInput = { closesAt: { lte: now } };
    const status = query.status ?? 'all';
    const polls = await this.prisma.poll.findMany({
      where: { societyId: auth.societyId, ...(status === 'open' ? open : status === 'closed' ? closed : {}) },
      include: pollInclude,
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    const views = await this.views(auth, polls, now);
    views.sort((a, b) => Number(b.isOpen) - Number(a.isOpen));
    return views.slice(0, query.limit ?? 50);
  }

  @Get(':id')
  async get(@Auth() auth: AuthContext, @Param('id') id: string): Promise<PollView> {
    return this.view(auth, await this.find(auth, id));
  }

  @Roles(Role.ADMIN)
  @Post()
  async create(@Auth() auth: AuthContext, @Body() body: PollDto): Promise<PollView> {
    const labels = body.options.map((o) => o.trim());
    if (labels.some((l) => !l) || new Set(labels.map((l) => l.toLowerCase())).size !== labels.length) {
      throw new ApiError(HttpStatus.BAD_REQUEST, 'VALIDATION_FAILED', 'Options must be different and not empty');
    }
    const poll = await this.prisma.poll.create({
      data: {
        societyId: auth.societyId,
        question: body.question.trim(),
        closesAt: body.closesAt ?? null,
        createdById: auth.userId,
        options: { create: labels.map((label, sortOrder) => ({ label, sortOrder })) },
      },
      include: pollInclude,
    });
    await this.notifications.notify(
      auth.societyId,
      await this.notifications.activeMemberIds(auth.societyId),
      { type: 'poll', title: 'New poll', body: `${poll.question} Cast your vote.`, data: { pollId: poll.id } },
      auth.userId,
    );
    return this.view(auth, poll);
  }

  /** One vote per person per poll, whichever role they're signed in as. */
  @Post(':id/votes')
  async vote(@Auth() auth: AuthContext, @Param('id') id: string, @Body() body: VoteDto): Promise<PollView> {
    const poll = await this.find(auth, id);
    if (!isOpen(poll, new Date())) throw new ApiError(HttpStatus.CONFLICT, 'POLL_CLOSED', 'This poll has closed');
    if (!poll.options.some((o) => o.id === body.optionId)) throw ApiError.notFound('Option not found');
    try {
      await this.prisma.pollVote.create({ data: { pollId: id, optionId: body.optionId, userId: auth.userId } });
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new ApiError(HttpStatus.CONFLICT, 'ALREADY_VOTED', 'You have already voted in this poll');
      }
      throw e;
    }
    return this.view(auth, poll);
  }

  @Roles(Role.ADMIN)
  @Post(':id/close')
  async close(@Auth() auth: AuthContext, @Param('id') id: string): Promise<PollView> {
    const poll = await this.find(auth, id);
    const now = new Date();
    if (!isOpen(poll, now)) return this.view(auth, poll);
    const closed = await this.prisma.poll.update({ where: { id }, data: { closesAt: now }, include: pollInclude });
    return this.view(auth, closed);
  }

  @Roles(Role.ADMIN)
  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(@Auth() auth: AuthContext, @Param('id') id: string): Promise<void> {
    const { count } = await this.prisma.poll.deleteMany({ where: { id, societyId: auth.societyId } });
    if (count === 0) throw ApiError.notFound('Poll not found');
  }

  private async find(auth: AuthContext, id: string): Promise<PollWithOptions> {
    const poll = await this.prisma.poll.findFirst({ where: { id, societyId: auth.societyId }, include: pollInclude });
    if (!poll) throw ApiError.notFound('Poll not found');
    return poll;
  }

  private async view(auth: AuthContext, poll: PollWithOptions): Promise<PollView> {
    const [view] = await this.views(auth, [poll], new Date());
    return view;
  }

  private async views(auth: AuthContext, polls: PollWithOptions[], now: Date): Promise<PollView[]> {
    const pollIds = polls.map((p) => p.id);
    const [counts, mine] = await Promise.all([
      this.prisma.pollVote.groupBy({ by: ['optionId'], where: { pollId: { in: pollIds } }, _count: { _all: true } }),
      this.prisma.pollVote.findMany({ where: { pollId: { in: pollIds }, userId: auth.userId } }),
    ]);
    const countOf = new Map(counts.map((c) => [c.optionId, c._count._all]));
    const myVote = new Map(mine.map((v) => [v.pollId, v.optionId]));
    return polls.map((poll) => {
      const open = isOpen(poll, now);
      const myOptionId = myVote.get(poll.id) ?? null;
      const resultsVisible = auth.role === 'ADMIN' || myOptionId !== null || !open;
      return {
        id: poll.id,
        question: poll.question,
        closesAt: poll.closesAt,
        isOpen: open,
        createdAt: poll.createdAt,
        totalVotes: poll.options.reduce((sum, o) => sum + (countOf.get(o.id) ?? 0), 0),
        myOptionId,
        resultsVisible,
        options: poll.options.map((o) => ({
          id: o.id,
          label: o.label,
          votes: resultsVisible ? (countOf.get(o.id) ?? 0) : null,
        })),
      };
    });
  }
}

function isOpen(poll: { closesAt: Date | null }, now: Date): boolean {
  return poll.closesAt === null || poll.closesAt > now;
}
