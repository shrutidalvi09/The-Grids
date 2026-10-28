import path from 'node:path';
import PDFDocument from 'pdfkit';

export interface ReceiptData {
  receiptNo: string;
  paidAt: Date;
  societyName: string;
  societyAddress: string | null;
  payerName: string;
  flatLabel: string | null;
  /** "Maintenance – October 2026" */
  towards: string;
  items: { label: string; amountPaise: number }[];
  totalPaise: number;
  method: string | null;
  transactionId: string | null;
}

const GREEN = '#2E7D32';
const SLATE = '#455A64';
const FONTS = path.resolve('assets/fonts');

const inr = (paise: number) =>
  `₹${new Intl.NumberFormat('en-IN', { minimumFractionDigits: paise % 100 ? 2 : 0 }).format(paise / 100)}`;

const METHOD_LABELS: Record<string, string> = {
  upi: 'UPI',
  card: 'Debit / Credit card',
  netbanking: 'Net banking',
  wallet: 'Wallet',
  emi: 'EMI',
};

export const methodLabel = (method: string | null) => (method ? (METHOD_LABELS[method] ?? method) : '—');

/** "MNT/2026/10/0007" */
export function formatReceiptNo(prefix: 'MNT' | 'RNT', paidAt: Date, sequence: number, timeZone = 'Asia/Kolkata'): string {
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit' }).formatToParts(paidAt);
  const year = parts.find((p) => p.type === 'year')!.value;
  const month = parts.find((p) => p.type === 'month')!.value;
  return `${prefix}/${year}/${month}/${String(sequence).padStart(4, '0')}`;
}

/** "2026-10" → "October 2026" */
export function periodLabel(period: string): string {
  const [y, m] = period.split('-').map(Number);
  return new Intl.DateTimeFormat('en-IN', { month: 'long', year: 'numeric', timeZone: 'UTC' }).format(Date.UTC(y, m - 1, 1));
}

/** A one-page A4 receipt. Roboto is bundled because the built-in PDF fonts have no ₹ glyph. */
export function buildReceiptPdf(data: ReceiptData): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({
      size: 'A4',
      margin: 50,
      info: { Title: `Receipt ${data.receiptNo}`, Author: data.societyName, Creator: 'The Grids' },
    });
    const chunks: Buffer[] = [];
    doc.on('data', (chunk: Buffer) => chunks.push(chunk));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    doc.registerFont('regular', path.join(FONTS, 'Roboto-Regular.ttf'));
    doc.registerFont('bold', path.join(FONTS, 'Roboto-Bold.ttf'));
    const width = doc.page.width - 100;

    // Header band
    doc.rect(0, 0, doc.page.width, 110).fill(GREEN);
    doc.fillColor('white').font('bold').fontSize(22).text(data.societyName, 50, 32, { width });
    doc.font('regular').fontSize(10).text(data.societyAddress ?? '', 50, 62, { width });
    doc.text('Managed with The Grids', 50, 78, { width });

    // Title row
    doc.fillColor('black').font('bold').fontSize(18).text('Payment Receipt', 50, 140);
    doc.font('regular').fontSize(11).fillColor(SLATE).text(data.receiptNo, 50, 145, { width, align: 'right' });

    // Details
    const paidOn = new Intl.DateTimeFormat('en-IN', {
      dateStyle: 'medium',
      timeStyle: 'short',
      timeZone: 'Asia/Kolkata',
    }).format(data.paidAt);
    const rows: [string, string][] = [
      ['Receipt no.', data.receiptNo],
      ['Paid on', paidOn],
      ['Received from', data.payerName],
      ['Flat', data.flatLabel ?? '—'],
      ['Towards', data.towards],
      ['Payment method', methodLabel(data.method)],
      ['Transaction ID', data.transactionId ?? '—'],
    ];
    let y = 190;
    for (const [label, value] of rows) {
      doc.font('regular').fontSize(11).fillColor(SLATE).text(label, 50, y, { width: 150 });
      doc.fillColor('black').text(value, 200, y, { width: width - 150 });
      y += 22;
    }

    // Breakdown table
    y += 16;
    doc.rect(50, y, width, 26).fill('#EEF1F2');
    doc.fillColor(SLATE).font('bold').fontSize(11).text('Item', 62, y + 7).text('Amount', 50, y + 7, { width: width - 12, align: 'right' });
    y += 34;
    doc.font('regular').fillColor('black');
    for (const item of data.items) {
      doc.text(item.label, 62, y).text(inr(item.amountPaise), 50, y, { width: width - 12, align: 'right' });
      y += 22;
    }
    doc.moveTo(50, y + 2).lineTo(50 + width, y + 2).strokeColor('#D5DBDE').stroke();
    y += 12;
    doc.font('bold').fontSize(13).text('Total paid', 62, y).text(inr(data.totalPaise), 50, y, { width: width - 12, align: 'right' });

    // Footer
    doc
      .font('regular')
      .fontSize(9)
      .fillColor(SLATE)
      .text('This is a computer-generated receipt and does not need a signature.', 50, doc.page.height - 90, {
        width,
        align: 'center',
      });

    doc.end();
  });
}
