import { Injectable } from '@nestjs/common';
import type { AuthContext } from '../auth/auth-context.js';
import { towerScope } from '../common/member.js';
import { flatLabel, flatLabelSelect } from '../common/queries.js';
import { localDate, zonedToUtc } from '../common/zoned-time.js';
import { FacilitiesService, type BookingView, type FacilityView } from '../facilities/facilities.service.js';
import type { ComplaintStatus, DueType } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { EventView } from '../tower/residents.controller.js';
import { type Weather, WeatherService } from '../weather/weather.service.js';

/**
 * One line of the resident's daily checklist. Structured (not text) so the
 * app can word it in the user's language.
 */
export type ChecklistItem =
  | { kind: 'help'; status: 'checked_in' | 'expected'; name: string; purpose: string | null; at: Date | null }
  | { kind: 'parcel'; from: string; at: Date | null }
  | { kind: 'bill'; status: 'due' | 'overdue'; dueType: DueType; amountPaise: number; dueDate: Date }
  | { kind: 'bills_clear' };

export interface HomeView {
  alert: { id: string; title: string; body: string } | null;
  weather: Weather | null;
  upcomingEvents: EventView[];
  /** Admin only. */
  stats?: { towers: number; flats: number; owners: number; tenants: number; pendingDues: number };
  recentComplaints?: {
    id: string;
    title: string;
    category: string | null;
    status: ComplaintStatus;
    flatLabel: string | null;
    createdAt: Date;
  }[];
  /** Guards: what's waiting at the gate. */
  gate?: { awaitingApproval: number; expected: number; inside: number; parcels: number; staffInside: number };
  /** Unresolved SOS alerts the caller should act on (gate, admins, the household). */
  activeSos?: { id: string; flatLabel: string | null; raisedBy: string | null; raisedByPhone: string | null; createdAt: Date }[];
  /** Owners and tenants. */
  checklist?: ChecklistItem[];
  myBookingsToday?: BookingView[];
  facilities?: FacilityView[];
}

@Injectable()
export class HomeService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly weather: WeatherService,
    private readonly facilities: FacilitiesService,
  ) {}

  async get(auth: AuthContext, now = new Date()): Promise<HomeView> {
    const society = await this.prisma.society.findUniqueOrThrow({ where: { id: auth.societyId } });
    const scope = await towerScope(this.prisma, auth);

    const [alert, weather, events] = await Promise.all([
      this.prisma.notice.findFirst({
        where: { societyId: auth.societyId, isAlert: true, ...scope, OR: [{ expiresAt: null }, { expiresAt: { gt: now } }] },
        orderBy: { createdAt: 'desc' },
        select: { id: true, title: true, body: true },
      }),
      this.weather.current(society.latitude, society.longitude),
      this.prisma.event.findMany({
        where: { societyId: auth.societyId, OR: [{ startsAt: { gte: now } }, { endsAt: { gte: now } }] },
        orderBy: { startsAt: 'asc' },
        take: 5,
      }),
    ]);

    const home: HomeView = {
      alert,
      weather,
      upcomingEvents: events.map((e) => ({
        id: e.id,
        title: e.title,
        description: e.description,
        location: e.location,
        imageUrl: e.imageUrl,
        startsAt: e.startsAt,
        endsAt: e.endsAt,
      })),
    };

    home.activeSos = await this.activeSos(auth);
    if (auth.role === 'GUARD') {
      home.gate = await this.gateSummary(auth, now);
    } else if (auth.role === 'ADMIN') {
      Object.assign(home, await this.adminSections(auth));
    } else {
      const startOfDay = zonedToUtc(localDate(now, society.timezone), '00:00', society.timezone);
      const [checklist, bookings, facilities] = await Promise.all([
        this.checklist(auth, startOfDay, now),
        this.facilities.mine(auth, now),
        this.facilities.list(auth, now),
      ]);
      const today = localDate(now, society.timezone);
      home.checklist = checklist;
      home.myBookingsToday = bookings.filter((b) => localDate(b.startsAt, society.timezone) === today);
      home.facilities = facilities;
    }
    return home;
  }

  private async activeSos(auth: AuthContext): Promise<NonNullable<HomeView['activeSos']>> {
    const gate = auth.role === 'ADMIN' || auth.role === 'GUARD';
    if (!gate && !auth.flatId) return [];
    const alerts = await this.prisma.sosAlert.findMany({
      where: { societyId: auth.societyId, status: 'ACTIVE', ...(gate ? {} : { flatId: auth.flatId }) },
      include: { flat: { select: flatLabelSelect }, raisedBy: { select: { name: true, phone: true } } },
      orderBy: { createdAt: 'desc' },
    });
    return alerts.map((a) => ({
      id: a.id,
      flatLabel: flatLabel(a.flat),
      raisedBy: a.raisedBy?.name ?? null,
      raisedByPhone: a.raisedBy?.phone ?? null,
      createdAt: a.createdAt,
    }));
  }

  private async gateSummary(auth: AuthContext, now: Date): Promise<NonNullable<HomeView['gate']>> {
    const societyId = auth.societyId;
    const dayAhead = new Date(now.getTime() + 86_400_000);
    const [awaitingApproval, expected, inside, parcels, staffInside] = await Promise.all([
      this.prisma.visitor.count({ where: { societyId, status: 'PENDING_APPROVAL' } }),
      this.prisma.visitor.count({
        where: { societyId, status: 'EXPECTED', OR: [{ expectedAt: null }, { expectedAt: { lte: dayAhead } }] },
      }),
      this.prisma.visitor.count({ where: { societyId, status: 'CHECKED_IN' } }),
      this.prisma.visitor.count({ where: { societyId, status: 'HELD_AT_GATE' } }),
      this.prisma.dailyHelpEntry.count({ where: { outTime: null, dailyHelp: { societyId } } }),
    ]);
    return { awaitingApproval, expected, inside, parcels, staffInside };
  }

  private async adminSections(auth: AuthContext) {
    const societyId = auth.societyId;
    const activeMember = { societyId, status: { in: ['ACTIVE' as const, 'INVITED' as const] } };
    const [towers, flats, owners, tenants, pendingDues, complaints] = await Promise.all([
      this.prisma.tower.count({ where: { societyId } }),
      this.prisma.flat.count({ where: { societyId } }),
      this.prisma.membership.count({ where: { ...activeMember, role: 'OWNER' } }),
      this.prisma.membership.count({ where: { ...activeMember, role: 'TENANT' } }),
      // Rent is between owner and tenant; the society tracks maintenance.
      this.prisma.due.count({ where: { societyId, type: 'MAINTENANCE', status: 'PENDING' } }),
      this.prisma.complaint.findMany({
        where: { societyId },
        orderBy: { createdAt: 'desc' },
        take: 3,
        include: { flat: { select: flatLabelSelect } },
      }),
    ]);
    return {
      stats: { towers, flats, owners, tenants, pendingDues },
      recentComplaints: complaints.map((c) => ({
        id: c.id,
        title: c.title,
        category: c.category,
        status: c.status,
        flatLabel: flatLabel(c.flat),
        createdAt: c.createdAt,
      })),
    };
  }

  /** Domestic help arrivals, parcels at the gate, and the next bill. */
  private async checklist(auth: AuthContext, startOfDay: Date, now: Date): Promise<ChecklistItem[]> {
    if (!auth.flatId) return [];
    const items: ChecklistItem[] = [];

    const visitors = await this.prisma.visitor.findMany({
      where: {
        flatId: auth.flatId,
        OR: [{ createdAt: { gte: startOfDay } }, { inTime: { gte: startOfDay } }, { status: 'HELD_AT_GATE' }],
      },
      orderBy: { createdAt: 'asc' },
    });
    for (const v of visitors) {
      if (v.type === 'SERVICE' && (v.status === 'EXPECTED' || v.status === 'CHECKED_IN')) {
        items.push({
          kind: 'help',
          status: v.status === 'CHECKED_IN' ? 'checked_in' : 'expected',
          name: v.name,
          purpose: v.purpose,
          at: v.inTime,
        });
      }
      if (v.status === 'HELD_AT_GATE') items.push({ kind: 'parcel', from: v.name, at: v.inTime });
    }
    // Daily help marked in at the gate today.
    const staff = await this.prisma.dailyHelpEntry.findMany({
      where: { inTime: { gte: startOfDay }, dailyHelp: { flats: { some: { flatId: auth.flatId } } } },
      include: { dailyHelp: { select: { name: true, kind: true } } },
      orderBy: { inTime: 'asc' },
    });
    const seen = new Set<string>();
    for (const e of staff) {
      if (seen.has(e.dailyHelpId)) continue;
      seen.add(e.dailyHelpId);
      items.push({ kind: 'help', status: 'checked_in', name: e.dailyHelp.name, purpose: e.dailyHelp.kind, at: e.inTime });
    }

    // Tenants see their rent; owners see maintenance.
    const dueType: DueType = auth.role === 'TENANT' ? 'RENT' : 'MAINTENANCE';
    const due = await this.prisma.due.findFirst({
      where: { flatId: auth.flatId, type: dueType, status: 'PENDING' },
      orderBy: { dueDate: 'asc' },
    });
    items.push(
      due
        ? {
            kind: 'bill',
            status: due.dueDate < now ? 'overdue' : 'due',
            dueType,
            amountPaise: due.amountPaise,
            dueDate: due.dueDate,
          }
        : { kind: 'bills_clear' },
    );
    return items;
  }
}
