import { LANGUAGES, type Message, renderMessage } from './messages.js';

const samples: Message[] = [
  { key: 'poll_new', question: 'Which activity for Sunday?' },
  { key: 'due', dueType: 'MAINTENANCE', amountPaise: 250000, period: '2026-10', dueDate: new Date('2026-10-10T04:30:00Z'), timezone: 'Asia/Kolkata' },
  { key: 'due', dueType: 'RENT', amountPaise: 1500000, period: '2026-10', dueDate: new Date('2026-10-05T04:30:00Z'), timezone: 'Asia/Kolkata' },
  { key: 'due_reminder', amountPaise: 500000, periods: ['2026-09', '2026-10'] },
  { key: 'payment', dueType: 'MAINTENANCE', amountPaise: 250000, period: '2026-10', receiptNo: 'MNT/2026/10/0007' },
  { key: 'tenancy', owner: 'Shruti', flat: 'Tower-C, 502', amountPaise: 1500000 },
  { key: 'complaint', title: 'Lift stuck', status: 'RESOLVED' },
  { key: 'visitor_arrived', name: 'Rekha' },
  { key: 'visitor_at_gate', name: 'Amazon' },
  { key: 'event_new', title: 'Yoga', startsAt: new Date('2026-10-29T01:30:00Z'), timezone: 'Asia/Kolkata' },
];

describe('notification messages', () => {
  it('writes English with Indian formatting and the society time zone', () => {
    expect(renderMessage(samples[1], 'en')).toEqual({
      title: 'Maintenance due',
      body: '₹2,500 for October 2026 is due on 10 Oct.',
    });
    expect(renderMessage(samples[3], 'en').body).toContain('September 2026 and October 2026');
    expect(renderMessage(samples[6], 'en').body).toBe('"Lift stuck" is resolved.');
    // 01:30 UTC is 7:00 AM in India.
    expect(renderMessage(samples[9], 'en').body).toMatch(/Yoga on Thu, 29 Oct, 7:00\s?am/i);
  });

  it('has every message in every language, keeping names, amounts and receipt numbers', () => {
    for (const message of samples) {
      const english = renderMessage(message, 'en');
      for (const lang of LANGUAGES) {
        const { title, body } = renderMessage(message, lang);
        expect(title, `${message.key}/${lang}`).toBeTruthy();
        expect(body, `${message.key}/${lang}`).toBeTruthy();
        if (lang !== 'en') expect(title, `${message.key}/${lang} is translated`).not.toBe(english.title);
        if ('amountPaise' in message) expect(body).toMatch(/₹[\d,]+/);
        if (message.key === 'payment') expect(body).toContain('MNT/2026/10/0007');
        if (message.key === 'visitor_arrived') expect(body).toContain('Rekha');
      }
    }
  });

  it('uses the month name in the reader’s language', () => {
    expect(renderMessage(samples[1], 'hi').body).toContain('अक्टूबर 2026');
    expect(renderMessage(samples[1], 'ta').body).toContain('2026');
  });

  it('falls back to English for an unknown language', () => {
    expect(renderMessage(samples[0], 'fr')).toEqual(renderMessage(samples[0], 'en'));
  });
});
