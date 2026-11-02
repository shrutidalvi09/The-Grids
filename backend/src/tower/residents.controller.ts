import { Controller, Get, Query } from '@nestjs/common';
import { Auth, type AuthContext, Everyone } from '../auth/auth-context.js';
import { isGate } from '../common/member.js';
import { flatLabel, flatLabelSelect, LimitQuery } from '../common/queries.js';
import type { Role, VisitorStatus, VisitorType } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';

export interface VisitorView {
  id: string;
  name: string;
  purpose: string | null;
  type: VisitorType;
  status: VisitorStatus;
  phone: string | null;
  expectedAt: Date | null;
  inTime: Date | null;
  outTime: Date | null;
  flatId: string;
  flatLabel: string | null;
  /** Pre-approved by a resident (vs logged at the gate). */
  preApproved: boolean;
  /** One-time gate pass; only shown to the flat, never in the gate's list. */
  passCode: string | null;
  vehicleNumber: string | null;
  photoUrl: string | null;
}

export function visitorView(v: {
  id: string;
  name: string;
  purpose: string | null;
  type: VisitorType;
  status: VisitorStatus;
  phone: string | null;
  expectedAt: Date | null;
  inTime: Date | null;
  outTime: Date | null;
  createdById: string | null;
  passCode: string | null;
  vehicleNumber: string | null;
  photoUrl: string | null;
  flatId: string;
  flat: { number: string; tower: { name: string } };
}, options: { showPass?: boolean } = {}): VisitorView {
  return {
    id: v.id,
    name: v.name,
    purpose: v.purpose,
    type: v.type,
    status: v.status,
    phone: v.phone,
    expectedAt: v.expectedAt,
    inTime: v.inTime,
    outTime: v.outTime,
    flatId: v.flatId,
    flatLabel: flatLabel(v.flat),
    preApproved: v.createdById !== null,
    passCode: options.showPass ? v.passCode : null,
    vehicleNumber: v.vehicleNumber,
    photoUrl: v.photoUrl,
  };
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

export function eventView(e: {
  id: string;
  title: string;
  description: string | null;
  location: string;
  imageUrl: string | null;
  startsAt: Date;
  endsAt: Date | null;
}): EventView {
  return {
    id: e.id,
    title: e.title,
    description: e.description,
    location: e.location,
    imageUrl: e.imageUrl,
    startsAt: e.startsAt,
    endsAt: e.endsAt,
  };
}

/** Visitor log, neighbours directory and events. */
@Controller()
export class ResidentsController {
  constructor(private readonly prisma: PrismaService) {}

  /** The gate (guards, admins) sees the whole society; residents see their own flat. */
  @Everyone()
  @Get('visitors')
  async visitors(@Auth() auth: AuthContext, @Query() query: LimitQuery): Promise<VisitorView[]> {
    const gate = isGate(auth);
    if (!gate && !auth.flatId) return [];
    const since = new Date(Date.now() - 7 * 86_400_000);
    const visitors = await this.prisma.visitor.findMany({
      where: {
        societyId: auth.societyId,
        ...(gate ? {} : { flatId: auth.flatId! }),
        OR: [
          { createdAt: { gte: since } },
          { status: { in: ['EXPECTED', 'CHECKED_IN', 'HELD_AT_GATE', 'PENDING_APPROVAL'] } },
        ],
      },
      include: { flat: { select: flatLabelSelect } },
      take: 200,
    });
    // Waiting for the flat's answer first, then people still expected, then most recent arrivals.
    const ordered = visitors.sort((a, b) => {
      const pending = Number(b.status === 'PENDING_APPROVAL') - Number(a.status === 'PENDING_APPROVAL');
      if (pending) return pending;
      if (!a.inTime || !b.inTime) return a.inTime ? 1 : b.inTime ? -1 : b.createdAt.getTime() - a.createdAt.getTime();
      return b.inTime.getTime() - a.inTime.getTime();
    });
    return ordered.slice(0, query.limit ?? 50).map((v) => visitorView(v, { showPass: !gate }));
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

  @Everyone()
  @Get('events')
  async events(@Auth() auth: AuthContext, @Query() query: LimitQuery): Promise<EventView[]> {
    const now = new Date();
    const events = await this.prisma.event.findMany({
      where: { societyId: auth.societyId, OR: [{ startsAt: { gte: now } }, { endsAt: { gte: now } }] },
      orderBy: { startsAt: 'asc' },
      take: query.limit ?? 50,
    });
    return events.map(eventView);
  }
}
