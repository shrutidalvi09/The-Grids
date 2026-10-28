import { Controller, Get, Query } from '@nestjs/common';
import { Auth, type AuthContext } from '../auth/auth-context.js';
import { flatLabel, flatLabelSelect, LimitQuery } from '../common/queries.js';
import type { Role, VisitorStatus, VisitorType } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';

export interface VisitorView {
  id: string;
  name: string;
  purpose: string | null;
  type: VisitorType;
  status: VisitorStatus;
  inTime: Date | null;
  outTime: Date | null;
  flatLabel: string | null;
}

export interface NeighbourFlat {
  flatId: string;
  number: string;
  residents: { name: string; role: Role; photoUrl: string | null }[];
}

export interface NeighbourTower {
  towerName: string;
  flats: NeighbourFlat[];
}

export interface EventView {
  id: string;
  title: string;
  description: string | null;
  location: string;
  imageUrl: string | null;
  startsAt: Date;
  endsAt: Date | null;
}

/** Visitor log, neighbours directory and events. */
@Controller()
export class ResidentsController {
  constructor(private readonly prisma: PrismaService) {}

  /** Admins see the whole society; residents see their own flat. */
  @Get('visitors')
  async visitors(@Auth() auth: AuthContext, @Query() query: LimitQuery): Promise<VisitorView[]> {
    if (auth.role !== 'ADMIN' && !auth.flatId) return [];
    const since = new Date(Date.now() - 7 * 86_400_000);
    const visitors = await this.prisma.visitor.findMany({
      where: {
        societyId: auth.societyId,
        ...(auth.role === 'ADMIN' ? {} : { flatId: auth.flatId! }),
        OR: [{ createdAt: { gte: since } }, { status: { in: ['EXPECTED', 'CHECKED_IN', 'HELD_AT_GATE'] } }],
      },
      include: { flat: { select: flatLabelSelect } },
      take: 200,
    });
    // People still expected first, then most recent arrivals.
    const ordered = visitors.sort((a, b) => {
      if (!a.inTime || !b.inTime) return a.inTime ? 1 : b.inTime ? -1 : 0;
      return b.inTime.getTime() - a.inTime.getTime();
    });
    return ordered.slice(0, query.limit ?? 50).map((v) => ({
      id: v.id,
      name: v.name,
      purpose: v.purpose,
      type: v.type,
      status: v.status,
      inTime: v.inTime,
      outTime: v.outTime,
      flatLabel: flatLabel(v.flat),
    }));
  }

  /** Occupied flats with their residents' names, grouped by tower. */
  @Get('neighbours')
  async neighbours(@Auth() auth: AuthContext): Promise<NeighbourTower[]> {
    const towers = await this.prisma.tower.findMany({
      where: { societyId: auth.societyId },
      orderBy: { name: 'asc' },
      include: {
        flats: {
          orderBy: { number: 'asc' },
          include: {
            memberships: {
              where: { status: { in: ['ACTIVE', 'INVITED'] }, role: { in: ['OWNER', 'TENANT'] } },
              include: { user: { select: { name: true, photoUrl: true } } },
              orderBy: { role: 'asc' },
            },
          },
        },
      },
    });
    return towers
      .map((t) => ({
        towerName: t.name,
        flats: t.flats
          .filter((f) => f.memberships.length > 0)
          .map((f) => ({
            flatId: f.id,
            number: f.number,
            residents: f.memberships.map((m) => ({ name: m.user.name, role: m.role, photoUrl: m.user.photoUrl })),
          })),
      }))
      .filter((t) => t.flats.length > 0);
  }

  @Get('events')
  async events(@Auth() auth: AuthContext, @Query() query: LimitQuery): Promise<EventView[]> {
    const now = new Date();
    const events = await this.prisma.event.findMany({
      where: { societyId: auth.societyId, OR: [{ startsAt: { gte: now } }, { endsAt: { gte: now } }] },
      orderBy: { startsAt: 'asc' },
      take: query.limit ?? 50,
    });
    return events.map((e) => ({
      id: e.id,
      title: e.title,
      description: e.description,
      location: e.location,
      imageUrl: e.imageUrl,
      startsAt: e.startsAt,
      endsAt: e.endsAt,
    }));
  }
}
