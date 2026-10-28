import { bookingProblem, countOverlapping, slotsFor, statusAt } from './availability.js';

const TZ = 'Asia/Kolkata';
const court = { openTime: '06:00', closeTime: '09:00', maxDurationMins: 60, capacity: 1 };
const gym = { openTime: '05:00', closeTime: '22:00', maxDurationMins: 90, capacity: null };

// 2026-10-27 07:30 IST
const now = new Date('2026-10-27T02:00:00Z');

describe('slotsFor', () => {
  it('cuts the opening hours into back-to-back slots that fit', () => {
    const slots = slotsFor(court, '2026-10-27', TZ);
    expect(slots.map((s) => s.startsAt.toISOString())).toEqual([
      '2026-10-27T00:30:00.000Z', // 06:00 IST
      '2026-10-27T01:30:00.000Z', // 07:00 IST
      '2026-10-27T02:30:00.000Z', // 08:00 IST
    ]);
    // 90-minute slots from 05:00 to 22:00: the last that fits starts at 20:00.
    expect(slotsFor(gym, '2026-10-27', TZ)).toHaveLength(11);
  });
});

describe('statusAt', () => {
  it('is closed before opening and after closing, with the next opening time', () => {
    const early = statusAt(court, new Date('2026-10-27T00:00:00Z'), TZ, []); // 05:30 IST
    expect(early).toEqual({ status: 'closed', opensAt: new Date('2026-10-27T00:30:00Z') });

    const late = statusAt(court, new Date('2026-10-27T04:00:00Z'), TZ, []); // 09:30 IST
    expect(late).toEqual({ status: 'closed', opensAt: new Date('2026-10-28T00:30:00Z') });
  });

  it('is open with remaining capacity, or full with the next free slot', () => {
    expect(statusAt(court, now, TZ, [])).toMatchObject({ status: 'open', remaining: 1 });

    const booked = [{ startsAt: new Date('2026-10-27T01:30:00Z'), endsAt: new Date('2026-10-27T02:30:00Z') }];
    expect(statusAt(court, now, TZ, booked)).toMatchObject({
      status: 'full',
      nextFreeAt: new Date('2026-10-27T02:30:00Z'),
    });
  });

  it('never fills up without a capacity', () => {
    const many = Array.from({ length: 50 }, () => ({ startsAt: now, endsAt: new Date(now.getTime() + 3_600_000) }));
    expect(statusAt(gym, now, TZ, many)).toMatchObject({ status: 'open', remaining: null });
  });
});

describe('bookingProblem', () => {
  it('accepts a future slot inside the 7-day window', () => {
    expect(bookingProblem(court, new Date('2026-10-27T02:30:00Z'), now, TZ)).toBeNull();
    expect(bookingProblem(court, new Date('2026-11-02T00:30:00Z'), now, TZ)).toBeNull(); // day 7
  });

  it('rejects misaligned, past and too-distant starts', () => {
    expect(bookingProblem(court, new Date('2026-10-27T02:45:00Z'), now, TZ)).toBe('NOT_A_SLOT');
    expect(bookingProblem(court, new Date('2026-10-27T00:30:00Z'), now, TZ)).toBe('IN_THE_PAST');
    expect(bookingProblem(court, new Date('2026-11-03T00:30:00Z'), now, TZ)).toBe('TOO_FAR_AHEAD');
  });
});

it('counts overlapping bookings', () => {
  const slot = { startsAt: new Date('2026-10-27T01:00:00Z'), endsAt: new Date('2026-10-27T02:00:00Z') };
  expect(
    countOverlapping(slot, [
      { startsAt: new Date('2026-10-27T00:00:00Z'), endsAt: new Date('2026-10-27T01:00:00Z') }, // touches, no overlap
      { startsAt: new Date('2026-10-27T01:30:00Z'), endsAt: new Date('2026-10-27T02:30:00Z') },
    ]),
  ).toBe(1);
});
