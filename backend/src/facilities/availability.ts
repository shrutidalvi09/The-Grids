import { addDays, localDate, minutesOf, zonedToUtc } from '../common/zoned-time.js';

/** Pure scheduling rules for facilities, kept free of I/O for unit tests. */

export interface FacilityHours {
  openTime: string; // "06:00"
  closeTime: string; // "22:00"
  maxDurationMins: number;
  capacity: number | null; // null = unlimited
}

export interface Interval {
  startsAt: Date;
  endsAt: Date;
}

export type FacilityStatus =
  | { status: 'open'; closesAt: Date; remaining: number | null }
  | { status: 'full'; closesAt: Date; nextFreeAt: Date | null }
  | { status: 'closed'; opensAt: Date };

export const BOOKING_WINDOW_DAYS = 7;

const overlaps = (a: Interval, b: Interval) => a.startsAt < b.endsAt && b.startsAt < a.endsAt;

export function countOverlapping(slot: Interval, bookings: Interval[]): number {
  return bookings.filter((b) => overlaps(slot, b)).length;
}

/** Bookable slots for [date] (wall-clock "YYYY-MM-DD" in [timeZone]). */
export function slotsFor(facility: FacilityHours, date: string, timeZone: string): Interval[] {
  const slots: Interval[] = [];
  const open = minutesOf(facility.openTime);
  const close = minutesOf(facility.closeTime);
  for (let start = open; start + facility.maxDurationMins <= close; start += facility.maxDurationMins) {
    const hh = String(Math.floor(start / 60)).padStart(2, '0');
    const mm = String(start % 60).padStart(2, '0');
    const startsAt = zonedToUtc(date, `${hh}:${mm}`, timeZone);
    slots.push({ startsAt, endsAt: new Date(startsAt.getTime() + facility.maxDurationMins * 60_000) });
  }
  return slots;
}

/** Is it open right now, and is there room? */
export function statusAt(
  facility: FacilityHours,
  now: Date,
  timeZone: string,
  bookings: Interval[],
): FacilityStatus {
  const today = localDate(now, timeZone);
  const opensToday = zonedToUtc(today, facility.openTime, timeZone);
  const closesToday = zonedToUtc(today, facility.closeTime, timeZone);

  if (now < opensToday) return { status: 'closed', opensAt: opensToday };
  if (now >= closesToday) return { status: 'closed', opensAt: zonedToUtc(addDays(today, 1), facility.openTime, timeZone) };

  const inUse = bookings.filter((b) => b.startsAt <= now && now < b.endsAt).length;
  if (facility.capacity != null && inUse >= facility.capacity) {
    const next = slotsFor(facility, today, timeZone).find(
      (s) => s.startsAt > now && countOverlapping(s, bookings) < facility.capacity!,
    );
    return { status: 'full', closesAt: closesToday, nextFreeAt: next?.startsAt ?? null };
  }
  return {
    status: 'open',
    closesAt: closesToday,
    remaining: facility.capacity == null ? null : facility.capacity - inUse,
  };
}

/** Why a requested booking start is not allowed, or null if it is. */
export function bookingProblem(
  facility: FacilityHours,
  startsAt: Date,
  now: Date,
  timeZone: string,
): 'NOT_A_SLOT' | 'IN_THE_PAST' | 'TOO_FAR_AHEAD' | null {
  const date = localDate(startsAt, timeZone);
  const isSlot = slotsFor(facility, date, timeZone).some((s) => s.startsAt.getTime() === startsAt.getTime());
  if (!isSlot) return 'NOT_A_SLOT';
  if (startsAt <= now) return 'IN_THE_PAST';
  if (date > addDays(localDate(now, timeZone), BOOKING_WINDOW_DAYS - 1)) return 'TOO_FAR_AHEAD';
  return null;
}
