import { HttpStatus, Injectable } from '@nestjs/common';
import type { AuthContext } from '../auth/auth-context.js';
import { ApiError } from '../common/api-error.js';
import { towerScope } from '../common/member.js';
import { addDays, localDate, minutesOf, zonedToUtc } from '../common/zoned-time.js';
import { PrismaService } from '../prisma/prisma.service.js';
import {
  BOOKING_WINDOW_DAYS,
  bookingProblem,
  countOverlapping,
  type FacilityStatus,
  type Interval,
  slotsFor,
  statusAt,
} from './availability.js';

export interface FacilityView {
  id: string;
  name: string;
  description: string | null;
  photoUrl: string | null;
  openTime: string;
  closeTime: string;
  maxDurationMins: number;
  capacity: number | null;
  status: FacilityStatus;
}

export interface SlotView {
  startsAt: Date;
  endsAt: Date;
  available: boolean;
  remaining: number | null;
  mine: boolean;
}

export interface BookingView {
  id: string;
  facilityId: string;
  facilityName: string;
  startsAt: Date;
  endsAt: Date;
}

export interface FacilityInput {
  name: string;
  description?: string | null;
  photoUrl?: string | null;
  openTime: string;
  closeTime: string;
  maxDurationMins: number;
  capacity?: number | null;
}

@Injectable()
export class FacilitiesService {
  constructor(private readonly prisma: PrismaService) {}

  /** Every facility the caller can use, with live open/full/closed status. */
  async list(auth: AuthContext, now = new Date()): Promise<FacilityView[]> {
    const { timeZone } = await this.society(auth.societyId);
    const facilities = await this.prisma.facility.findMany({
      where: { societyId: auth.societyId, isActive: true, ...(await towerScope(this.prisma, auth)) },
      orderBy: { name: 'asc' },
    });
    const today = localDate(now, timeZone);
    const bookings = await this.prisma.facilityBooking.findMany({
      where: {
        facilityId: { in: facilities.map((f) => f.id) },
        status: 'CONFIRMED',
        startsAt: { lt: zonedToUtc(addDays(today, 1), '00:00', timeZone) },
        endsAt: { gt: zonedToUtc(today, '00:00', timeZone) },
      },
      select: { facilityId: true, startsAt: true, endsAt: true },
    });
    return facilities.map((f) => ({
      id: f.id,
      name: f.name,
      description: f.description,
      photoUrl: f.photoUrl,
      openTime: f.openTime,
      closeTime: f.closeTime,
      maxDurationMins: f.maxDurationMins,
      capacity: f.capacity,
      status: statusAt(f, now, timeZone, bookings.filter((b) => b.facilityId === f.id)),
    }));
  }

  /** Slots for one day, marking which are free and which are the caller's. */
  async slots(auth: AuthContext, facilityId: string, date: string, now = new Date()): Promise<SlotView[]> {
    const { timeZone } = await this.society(auth.societyId);
    const facility = await this.facilityFor(auth, facilityId);
    const today = localDate(now, timeZone);
    if (date < today || date > addDays(today, BOOKING_WINDOW_DAYS - 1)) {
      throw new ApiError(HttpStatus.BAD_REQUEST, 'SLOT_INVALID', `Bookings open ${BOOKING_WINDOW_DAYS} days ahead`);
    }
    const slots = slotsFor(facility, date, timeZone);
    const bookings = await this.bookingsBetween(facility.id, slots);
    return slots.map((slot) => {
      const taken = countOverlapping(slot, bookings);
      const remaining = facility.capacity == null ? null : Math.max(0, facility.capacity - taken);
      return {
        ...slot,
        available: slot.startsAt > now && (remaining == null || remaining > 0),
        remaining,
        mine: bookings.some((b) => b.userId === auth.userId && b.startsAt.getTime() === slot.startsAt.getTime()),
      };
    });
  }

  async book(auth: AuthContext, facilityId: string, startsAt: Date, now = new Date()): Promise<BookingView> {
    const { timeZone } = await this.society(auth.societyId);
    const facility = await this.facilityFor(auth, facilityId);

    const problem = bookingProblem(facility, startsAt, now, timeZone);
    if (problem) throw new ApiError(HttpStatus.BAD_REQUEST, 'SLOT_INVALID', `Cannot book this slot: ${problem}`);
    const endsAt = new Date(startsAt.getTime() + facility.maxDurationMins * 60_000);

    return this.prisma.$transaction(async (tx) => {
      // Serialise bookings per facility so two people can't take the last place.
      await tx.$queryRaw`SELECT id FROM Facility WHERE id = ${facility.id} FOR UPDATE`;

      const overlapping = await tx.facilityBooking.findMany({
        where: { facilityId: facility.id, status: 'CONFIRMED', startsAt: { lt: endsAt }, endsAt: { gt: startsAt } },
        select: { userId: true },
      });
      if (overlapping.some((b) => b.userId === auth.userId)) {
        throw new ApiError(HttpStatus.CONFLICT, 'ALREADY_BOOKED', 'You already have this slot');
      }
      if (facility.capacity != null && overlapping.length >= facility.capacity) {
        throw new ApiError(HttpStatus.CONFLICT, 'SLOT_FULL', 'This slot is full');
      }
      const booking = await tx.facilityBooking.create({
        data: { facilityId: facility.id, userId: auth.userId, startsAt, endsAt },
      });
      return { id: booking.id, facilityId: facility.id, facilityName: facility.name, startsAt, endsAt };
    });
  }

  async mine(auth: AuthContext, now = new Date()): Promise<BookingView[]> {
    const bookings = await this.prisma.facilityBooking.findMany({
      where: { userId: auth.userId, status: 'CONFIRMED', endsAt: { gt: now }, facility: { societyId: auth.societyId } },
      include: { facility: { select: { name: true } } },
      orderBy: { startsAt: 'asc' },
    });
    return bookings.map((b) => ({
      id: b.id,
      facilityId: b.facilityId,
      facilityName: b.facility.name,
      startsAt: b.startsAt,
      endsAt: b.endsAt,
    }));
  }

  async cancel(auth: AuthContext, bookingId: string, now = new Date()): Promise<void> {
    const { count } = await this.prisma.facilityBooking.updateMany({
      where: { id: bookingId, userId: auth.userId, status: 'CONFIRMED', startsAt: { gt: now } },
      data: { status: 'CANCELLED' },
    });
    if (count === 0) throw ApiError.notFound('Booking not found or already started');
  }

  async create(auth: AuthContext, input: FacilityInput): Promise<{ id: string }> {
    validateHours(input);
    const facility = await this.prisma.facility.create({
      data: { ...normalise(input), societyId: auth.societyId },
      select: { id: true },
    });
    return facility;
  }

  async update(auth: AuthContext, facilityId: string, input: FacilityInput): Promise<{ id: string }> {
    validateHours(input);
    const { count } = await this.prisma.facility.updateMany({
      where: { id: facilityId, societyId: auth.societyId },
      data: normalise(input),
    });
    if (count === 0) throw ApiError.notFound('Facility not found');
    return { id: facilityId };
  }

  private async facilityFor(auth: AuthContext, facilityId: string) {
    const facility = await this.prisma.facility.findFirst({
      where: { id: facilityId, societyId: auth.societyId, isActive: true, ...(await towerScope(this.prisma, auth)) },
    });
    if (!facility) throw ApiError.notFound('Facility not found');
    return facility;
  }

  private bookingsBetween(facilityId: string, slots: Interval[]) {
    if (!slots.length) return Promise.resolve([]);
    return this.prisma.facilityBooking.findMany({
      where: {
        facilityId,
        status: 'CONFIRMED',
        startsAt: { lt: slots[slots.length - 1].endsAt },
        endsAt: { gt: slots[0].startsAt },
      },
      select: { userId: true, startsAt: true, endsAt: true },
    });
  }

  private async society(id: string) {
    const society = await this.prisma.society.findUniqueOrThrow({ where: { id }, select: { timezone: true } });
    return { timeZone: society.timezone };
  }
}

function validateHours(input: FacilityInput) {
  const open = minutesOf(input.openTime);
  const close = minutesOf(input.closeTime);
  if (close - open < input.maxDurationMins) {
    throw new ApiError(HttpStatus.BAD_REQUEST, 'VALIDATION_FAILED', 'Opening hours must fit at least one booking', {
      fields: ['closeTime must be at least maxDurationMins after openTime'],
    });
  }
}

function normalise(input: FacilityInput) {
  return {
    name: input.name.trim(),
    description: input.description?.trim() || null,
    photoUrl: input.photoUrl || null,
    openTime: input.openTime,
    closeTime: input.closeTime,
    maxDurationMins: input.maxDurationMins,
    capacity: input.capacity ?? null,
  };
}
