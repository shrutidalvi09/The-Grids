import { addDays, localDate, minutesOf, offsetMinutes, zonedToUtc } from './zoned-time.js';

describe('zoned time', () => {
  it('converts India wall-clock time to UTC', () => {
    expect(zonedToUtc('2026-10-27', '17:30', 'Asia/Kolkata').toISOString()).toBe('2026-10-27T12:00:00.000Z');
    expect(zonedToUtc('2026-10-27', '00:00', 'Asia/Kolkata').toISOString()).toBe('2026-10-26T18:30:00.000Z');
    expect(offsetMinutes(new Date('2026-10-27T00:00:00Z'), 'Asia/Kolkata')).toBe(330);
  });

  it('handles zones with daylight saving', () => {
    // London: BST (+60) on 2026-10-24, GMT (0) on 2026-10-26.
    expect(zonedToUtc('2026-10-24', '09:00', 'Europe/London').toISOString()).toBe('2026-10-24T08:00:00.000Z');
    expect(zonedToUtc('2026-10-26', '09:00', 'Europe/London').toISOString()).toBe('2026-10-26T09:00:00.000Z');
  });

  it('finds the local calendar date', () => {
    // 20:00 UTC is already the next day in India.
    expect(localDate(new Date('2026-10-27T20:00:00Z'), 'Asia/Kolkata')).toBe('2026-10-28');
    expect(localDate(new Date('2026-10-27T10:00:00Z'), 'Asia/Kolkata')).toBe('2026-10-27');
  });

  it('does date and time arithmetic', () => {
    expect(addDays('2026-12-31', 1)).toBe('2027-01-01');
    expect(addDays('2026-03-01', -1)).toBe('2026-02-28');
    expect(minutesOf('06:30')).toBe(390);
  });
});
