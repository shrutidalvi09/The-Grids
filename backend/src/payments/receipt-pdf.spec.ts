import { buildReceiptPdf, formatReceiptNo, methodLabel, periodLabel } from './receipt-pdf.js';

describe('receipt helpers', () => {
  it('numbers receipts per month in India time', () => {
    // 2026-10-31 20:00 UTC is already 1 November in India.
    expect(formatReceiptNo('MNT', new Date('2026-10-31T20:00:00Z'), 7)).toBe('MNT/2026/11/0007');
    expect(formatReceiptNo('RNT', new Date('2026-10-05T06:00:00Z'), 123)).toBe('RNT/2026/10/0123');
  });

  it('labels periods and methods', () => {
    expect(periodLabel('2026-10')).toBe('October 2026');
    expect(methodLabel('upi')).toBe('UPI');
    expect(methodLabel('netbanking')).toBe('Net banking');
    expect(methodLabel(null)).toBe('—');
  });
});

describe('buildReceiptPdf', () => {
  it('produces a valid one-page PDF', async () => {
    const pdf = await buildReceiptPdf({
      receiptNo: 'MNT/2026/10/0001',
      paidAt: new Date('2026-10-28T06:00:00Z'),
      societyName: 'Sai Icon Co-operative Society',
      societyAddress: 'Ghodbunder Road, Thane West',
      payerName: 'Shruti Chetan Dalvi',
      flatLabel: 'Tower-C, 502',
      towards: 'Maintenance – October 2026',
      items: [
        { label: 'Cleaning', amountPaise: 50000 },
        { label: 'Gardening', amountPaise: 120000 },
      ],
      totalPaise: 170000,
      method: 'upi',
      transactionId: 'pay_123',
    });
    expect(pdf.subarray(0, 5).toString()).toBe('%PDF-');
    expect(pdf.subarray(-6).toString()).toContain('%%EOF');
    expect(pdf.toString('latin1').match(/\/Type \/Page\b/g)).toHaveLength(1);
    // Roboto is embedded (the ₹ sign needs it).
    expect(pdf.toString('latin1')).toContain('Roboto');
  });
});
