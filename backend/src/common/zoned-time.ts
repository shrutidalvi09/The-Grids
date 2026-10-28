/**
 * Wall-clock ↔ instant conversion for a society's IANA time zone, using only
 * Intl (no tz database dependency). Facility hours ("06:00"–"22:00") and
 * booking dates ("2026-10-27") are wall-clock values in the society's zone.
 */

const formatters = new Map<string, Intl.DateTimeFormat>();

function formatter(timeZone: string): Intl.DateTimeFormat {
  let f = formatters.get(timeZone);
  if (!f) {
    f = new Intl.DateTimeFormat('en-US', {
      timeZone,
      hourCycle: 'h23',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    });
    formatters.set(timeZone, f);
  }
  return f;
}

interface WallClock {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
}

function wallClock(instant: Date, timeZone: string): WallClock {
  const parts = Object.fromEntries(formatter(timeZone).formatToParts(instant).map((p) => [p.type, p.value]));
  return {
    year: Number(parts.year),
    month: Number(parts.month),
    day: Number(parts.day),
    hour: Number(parts.hour),
    minute: Number(parts.minute),
    second: Number(parts.second),
  };
}

/** Offset of [timeZone] from UTC at [instant], in minutes (IST = +330). */
export function offsetMinutes(instant: Date, timeZone: string): number {
  const w = wallClock(instant, timeZone);
  const asUtc = Date.UTC(w.year, w.month - 1, w.day, w.hour, w.minute, w.second);
  return Math.round((asUtc - Math.floor(instant.getTime() / 1000) * 1000) / 60_000);
}

/** "2026-10-27" + "17:30" in [timeZone] → the matching instant. */
export function zonedToUtc(date: string, time: string, timeZone: string): Date {
  const [y, m, d] = date.split('-').map(Number);
  const [hh, mm] = time.split(':').map(Number);
  const guess = Date.UTC(y, m - 1, d, hh, mm);
  const first = guess - offsetMinutes(new Date(guess), timeZone) * 60_000;
  // Second pass corrects guesses that straddle a DST change.
  return new Date(guess - offsetMinutes(new Date(first), timeZone) * 60_000);
}

/** The calendar date of [instant] in [timeZone], as "YYYY-MM-DD". */
export function localDate(instant: Date, timeZone: string): string {
  const w = wallClock(instant, timeZone);
  return `${w.year}-${String(w.month).padStart(2, '0')}-${String(w.day).padStart(2, '0')}`;
}

/** "YYYY-MM-DD" shifted by whole days. */
export function addDays(date: string, days: number): string {
  const [y, m, d] = date.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d + days)).toISOString().slice(0, 10);
}

export const TIME_OF_DAY = /^([01]\d|2[0-3]):[0-5]\d$/;
export const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

/** "06:30" → 390. */
export function minutesOf(time: string): number {
  const [h, m] = time.split(':').map(Number);
  return h * 60 + m;
}
