import { HttpStatus, Injectable, Logger } from '@nestjs/common';
import type { AuthContext } from '../auth/auth-context.js';
import { ApiError } from '../common/api-error.js';
import { inr } from '../common/money.js';
import { flatLabel, flatLabelSelect } from '../common/queries.js';
import { localDate, zonedToUtc } from '../common/zoned-time.js';
import type { BillStatus, DueStatus, DueType } from '../generated/prisma/enums.js';
import { periodLabel } from '../payments/receipt-pdf.js';
import type { BreakdownItem } from '../payments/payments.service.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import { PrismaService } from '../prisma/prisma.service.js';

export interface DueView {
  id: string;
  type: DueType;
  period: string;
  amountPaise: number;
  breakdown: BreakdownItem[];
  dueDate: Date;
  status: DueStatus;
  overdue: boolean;
  flatLabel: string | null;
}

export interface MaintenanceConfigView {
  items: (BreakdownItem & { id: string })[];
  totalPaise: number;
  dueDay: number;
}

export interface DefaulterView {
  flatId: string;
  flatLabel: string;
  owners: string[];
  dues: number;
  amountPaise: number;
  oldestDueDate: Date;
  lastRemindedAt: Date | null;
}

export interface SocietyBillView {
  id: string;
  vendor: string;
  category: string | null;
  amountPaise: number;
  dueDate: Date;
  status: BillStatus;
  paidAt: Date | null;
}

const REMIND_INTERVAL_MS = 24 * 3_600_000;

@Injectable()
export class DuesService {
  private readonly logger = new Logger(DuesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  /** Unpaid dues the caller should pay: maintenance for owners, rent for tenants. */
  async mine(auth: AuthContext, now = new Date()): Promise<DueView[]> {
    const type: DueType | null = auth.role === 'OWNER' ? 'MAINTENANCE' : auth.role === 'TENANT' ? 'RENT' : null;
    if (!type || !auth.flatId) return [];
    const dues = await this.prisma.due.findMany({
      where: { societyId: auth.societyId, flatId: auth.flatId, type, status: 'PENDING' },
      include: { flat: { select: flatLabelSelect } },
      orderBy: { dueDate: 'asc' },
    });
    return dues.map((d) => ({
      id: d.id,
      type: d.type,
      period: d.period,
      amountPaise: d.amountPaise,
      breakdown: d.breakdown as unknown as BreakdownItem[],
      dueDate: d.dueDate,
      status: d.status,
      overdue: d.dueDate < now,
      flatLabel: flatLabel(d.flat),
    }));
  }

  async config(societyId: string): Promise<MaintenanceConfigView> {
    const [society, items] = await Promise.all([
      this.prisma.society.findUniqueOrThrow({ where: { id: societyId }, select: { maintenanceDueDay: true } }),
      this.prisma.maintenanceItem.findMany({ where: { societyId }, orderBy: { sortOrder: 'asc' } }),
    ]);
    return {
      items: items.map((i) => ({ id: i.id, label: i.label, amountPaise: i.amountPaise })),
      totalPaise: items.reduce((sum, i) => sum + i.amountPaise, 0),
      dueDay: society.maintenanceDueDay,
    };
  }

  /** Replaces the line items. Bills already issued keep their own breakdown. */
  async updateConfig(societyId: string, input: { items: BreakdownItem[]; dueDay: number }): Promise<MaintenanceConfigView> {
    await this.prisma.$transaction([
      this.prisma.maintenanceItem.deleteMany({ where: { societyId } }),
      this.prisma.maintenanceItem.createMany({
        data: input.items.map((item, sortOrder) => ({ societyId, label: item.label.trim(), amountPaise: item.amountPaise, sortOrder })),
      }),
      this.prisma.society.update({ where: { id: societyId }, data: { maintenanceDueDay: input.dueDay } }),
    ]);
    return this.config(societyId);
  }

  /**
   * Issues a month's dues: maintenance for every occupied flat and rent for
   * every active tenancy. Idempotent (one due per flat, type and month), so
   * the daily job and a manual run can't double-bill.
   */
  async generate(societyId: string, period?: string, now = new Date()): Promise<{ period: string; created: number }> {
    const society = await this.prisma.society.findUniqueOrThrow({ where: { id: societyId } });
    const month = period ?? localDate(now, society.timezone).slice(0, 7);
    const [year, monthNo] = month.split('-').map(Number);
    const daysInMonth = new Date(Date.UTC(year, monthNo, 0)).getUTCDate();
    const dueOn = (day: number) =>
      zonedToUtc(`${month}-${String(Math.min(day, daysInMonth)).padStart(2, '0')}`, '10:00', society.timezone);
    const monthStart = zonedToUtc(`${month}-01`, '00:00', society.timezone);
    const monthEnd = zonedToUtc(`${month}-${String(daysInMonth).padStart(2, '0')}`, '23:59', society.timezone);

    const items = await this.prisma.maintenanceItem.findMany({ where: { societyId }, orderBy: { sortOrder: 'asc' } });
    const breakdown = items.map((i) => ({ label: i.label, amountPaise: i.amountPaise }));
    const total = breakdown.reduce((sum, i) => sum + i.amountPaise, 0);

    const occupied = await this.prisma.flat.findMany({
      where: { societyId, memberships: { some: { role: 'OWNER', status: { in: ['ACTIVE', 'INVITED'] } } } },
      select: { id: true },
    });
    const tenancies = await this.prisma.tenancy.findMany({
      where: { societyId, startDate: { lte: monthEnd }, OR: [{ endDate: null }, { endDate: { gte: monthStart } }] },
    });

    const rows = [
      ...(total > 0
        ? occupied.map((f) => ({
            societyId,
            flatId: f.id,
            type: 'MAINTENANCE' as const,
            period: month,
            amountPaise: total,
            breakdown,
            dueDate: dueOn(society.maintenanceDueDay),
          }))
        : []),
      ...tenancies.map((t) => ({
        societyId,
        flatId: t.flatId,
        type: 'RENT' as const,
        period: month,
        amountPaise: t.monthlyRentPaise,
        breakdown: t.rentBreakdown as object,
        dueDate: dueOn(t.rentDueDay),
      })),
    ];
    const existing = await this.prisma.due.findMany({ where: { societyId, period: month }, select: { flatId: true, type: true } });
    const already = new Set(existing.map((d) => `${d.flatId}:${d.type}`));
    const { count } = await this.prisma.due.createMany({ data: rows, skipDuplicates: true });
    if (count) {
      this.logger.log(`Issued ${count} dues for ${society.name} (${month})`);
      // Owners hear about maintenance, tenants about rent.
      for (const row of rows.filter((r) => !already.has(`${r.flatId}:${r.type}`))) {
        const isRent = row.type === 'RENT';
        await this.notifications.notify(
          societyId,
          await this.notifications.flatResidentIds(societyId, row.flatId, [isRent ? 'TENANT' : 'OWNER']),
          {
            type: 'due',
            title: isRent ? 'Rent due' : 'Maintenance due',
            body: `${inr(row.amountPaise)} for ${periodLabel(month)} is due on ${localDate(row.dueDate, society.timezone)}.`,
            data: { period: month, dueType: row.type },
          },
        );
      }
    }
    return { period: month, created: count };
  }

  async summary(societyId: string, now = new Date()) {
    const society = await this.prisma.society.findUniqueOrThrow({ where: { id: societyId }, select: { timezone: true } });
    const today = localDate(now, society.timezone);
    const monthStart = zonedToUtc(`${today.slice(0, 7)}-01`, '00:00', society.timezone);
    const [pending, collected] = await Promise.all([
      this.prisma.due.findMany({
        where: { societyId, type: 'MAINTENANCE', status: 'PENDING' },
        select: { flatId: true, amountPaise: true },
      }),
      this.prisma.payment.aggregate({
        where: { societyId, status: 'SUCCEEDED', paidAt: { gte: monthStart }, due: { type: 'MAINTENANCE' } },
        _sum: { amountPaise: true },
      }),
    ]);
    return {
      pendingFlats: new Set(pending.map((d) => d.flatId)).size,
      pendingAmountPaise: pending.reduce((sum, d) => sum + d.amountPaise, 0),
      collectedThisMonthPaise: collected._sum.amountPaise ?? 0,
    };
  }

  /** Flats with unpaid maintenance, most overdue first. */
  async defaulters(societyId: string): Promise<DefaulterView[]> {
    const dues = await this.prisma.due.findMany({
      where: { societyId, type: 'MAINTENANCE', status: 'PENDING' },
      include: {
        flat: {
          select: {
            ...flatLabelSelect,
            memberships: {
              where: { role: 'OWNER', status: { in: ['ACTIVE', 'INVITED'] } },
              select: { user: { select: { name: true } } },
            },
          },
        },
      },
      orderBy: { dueDate: 'asc' },
    });
    const byFlat = new Map<string, DefaulterView>();
    for (const d of dues) {
      const existing = byFlat.get(d.flatId);
      if (existing) {
        existing.dues += 1;
        existing.amountPaise += d.amountPaise;
        if (d.lastRemindedAt && (!existing.lastRemindedAt || d.lastRemindedAt > existing.lastRemindedAt)) {
          existing.lastRemindedAt = d.lastRemindedAt;
        }
      } else {
        byFlat.set(d.flatId, {
          flatId: d.flatId,
          flatLabel: flatLabel(d.flat)!,
          owners: d.flat.memberships.map((m) => m.user.name),
          dues: 1,
          amountPaise: d.amountPaise,
          oldestDueDate: d.dueDate,
          lastRemindedAt: d.lastRemindedAt,
        });
      }
    }
    return [...byFlat.values()];
  }

  /** In-app reminder to a flat's owners; at most once a day per flat. */
  async remind(societyId: string, flatId: string, now = new Date()): Promise<{ notified: number }> {
    const dues = await this.prisma.due.findMany({
      where: { societyId, flatId, type: 'MAINTENANCE', status: 'PENDING' },
      orderBy: { dueDate: 'asc' },
    });
    if (!dues.length) throw ApiError.notFound('No pending maintenance for this flat');
    if (dues.some((d) => d.lastRemindedAt && now.getTime() - d.lastRemindedAt.getTime() < REMIND_INTERVAL_MS)) {
      throw new ApiError(HttpStatus.TOO_MANY_REQUESTS, 'ALREADY_REMINDED', 'This flat was already reminded today');
    }
    const owners = await this.prisma.membership.findMany({
      where: { societyId, flatId, role: 'OWNER', status: { in: ['ACTIVE', 'INVITED'] } },
      select: { userId: true },
    });
    const total = dues.reduce((sum, d) => sum + d.amountPaise, 0);
    const periods = dues.map((d) => periodLabel(d.period)).join(', ');
    await this.prisma.due.updateMany({ where: { id: { in: dues.map((d) => d.id) } }, data: { lastRemindedAt: now } });
    const notified = await this.notifications.notify(
      societyId,
      owners.map((o) => o.userId),
      {
        type: 'due_reminder',
        title: 'Maintenance reminder',
        body: `Your maintenance of ${inr(total)} for ${periods} is pending. Please pay from the Maintenance tab.`,
        data: { flatId },
      },
    );
    return { notified };
  }

  async bills(societyId: string, status?: BillStatus): Promise<SocietyBillView[]> {
    const bills = await this.prisma.societyBill.findMany({
      where: { societyId, ...(status ? { status } : {}) },
      orderBy: [{ status: 'asc' }, { dueDate: 'asc' }],
    });
    return bills.map(({ id, vendor, category, amountPaise, dueDate, status: s, paidAt }) => ({
      id,
      vendor,
      category,
      amountPaise,
      dueDate,
      status: s,
      paidAt,
    }));
  }

  async addBill(societyId: string, input: { vendor: string; category?: string; amountPaise: number; dueDate: Date }) {
    const bill = await this.prisma.societyBill.create({
      data: { societyId, vendor: input.vendor.trim(), category: input.category?.trim() || null, amountPaise: input.amountPaise, dueDate: input.dueDate },
    });
    return { id: bill.id };
  }

  async markBillPaid(societyId: string, billId: string): Promise<void> {
    const { count } = await this.prisma.societyBill.updateMany({
      where: { id: billId, societyId, status: 'DUE' },
      data: { status: 'PAID', paidAt: new Date() },
    });
    if (count === 0) throw ApiError.notFound('Unpaid bill not found');
  }
}
