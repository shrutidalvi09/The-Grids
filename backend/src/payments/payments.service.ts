import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { HttpStatus, Inject, Injectable, Logger } from '@nestjs/common';
import type { AuthContext } from '../auth/auth-context.js';
import { ApiError } from '../common/api-error.js';
import { inr } from '../common/money.js';
import { flatLabel, flatLabelSelect } from '../common/queries.js';
import { ENV, type Env } from '../config/env.js';
import type { DueType, PaymentStatus } from '../generated/prisma/enums.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { PaymentGateway, SimulatedGateway } from './gateway.js';
import { buildReceiptPdf, formatReceiptNo, periodLabel } from './receipt-pdf.js';

export interface BreakdownItem {
  label: string;
  amountPaise: number;
}

export interface CheckoutView {
  paymentId: string;
  gateway: 'razorpay' | 'simulated';
  /** Razorpay key id for Checkout; null for the simulator. */
  keyId: string | null;
  orderId: string;
  amountPaise: number;
  currency: 'INR';
  name: string;
  description: string;
  /** `method` pre-selects the payer's preferred option (Profile → Payment Settings). */
  prefill: { name: string; contact: string; email: string | null; method: string | null };
}

export interface PaymentView {
  id: string;
  status: PaymentStatus;
  amountPaise: number;
  method: string | null;
  gateway: string;
  receiptNo: string | null;
  paidAt: Date | null;
  transactionId: string | null;
  failureReason: string | null;
  due: { id: string; type: DueType; period: string; breakdown: BreakdownItem[] };
  payerName: string;
  flatLabel: string | null;
  societyName: string;
}

/** Owners pay maintenance; tenants pay rent. */
const dueTypeFor = (auth: AuthContext): DueType | null =>
  auth.role === 'OWNER' ? 'MAINTENANCE' : auth.role === 'TENANT' ? 'RENT' : null;

const ORDER_REUSE_MS = 30 * 60_000;

const paymentInclude = {
  due: { include: { flat: { select: flatLabelSelect } } },
  payer: { select: { name: true } },
  society: { select: { name: true, address: true, timezone: true } },
} as const;

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly gateway: PaymentGateway,
    private readonly notifications: NotificationsService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /** Start paying a due: creates (or reuses) a gateway order. */
  async createOrder(auth: AuthContext, dueId: string): Promise<CheckoutView> {
    const dueType = dueTypeFor(auth);
    const due = await this.prisma.due.findFirst({
      where: { id: dueId, societyId: auth.societyId, flatId: auth.flatId ?? '-', ...(dueType ? { type: dueType } : { id: '-' }) },
      include: { society: { select: { name: true } } },
    });
    if (!due) throw ApiError.notFound('Due not found');
    if (due.status !== 'PENDING') {
      throw new ApiError(HttpStatus.CONFLICT, 'DUE_NOT_PENDING', 'This due is already paid');
    }
    const payer = await this.prisma.user.findUniqueOrThrow({ where: { id: auth.userId } });

    // Retrying soon after an abandoned or failed checkout reuses the order,
    // so one due never accumulates a pile of open orders.
    const reusable = await this.prisma.payment.findFirst({
      where: {
        dueId,
        payerId: auth.userId,
        status: { in: ['CREATED', 'FAILED'] },
        gateway: this.gateway.name,
        razorpayOrderId: { not: null },
        createdAt: { gte: new Date(Date.now() - ORDER_REUSE_MS) },
      },
      orderBy: { createdAt: 'desc' },
    });

    let payment = reusable;
    if (!payment) {
      payment = await this.prisma.payment.create({
        data: {
          societyId: auth.societyId,
          dueId,
          payerId: auth.userId,
          amountPaise: due.amountPaise,
          gateway: this.gateway.name,
        },
      });
      const order = await this.gateway.createOrder({
        amountPaise: due.amountPaise,
        receipt: payment.id,
        notes: { dueId, flatId: due.flatId, period: due.period, type: due.type },
      });
      payment = await this.prisma.payment.update({
        where: { id: payment.id },
        data: { razorpayOrderId: order.orderId },
      });
    }

    return {
      paymentId: payment.id,
      gateway: this.gateway.name,
      keyId: this.gateway.publicKey,
      orderId: payment.razorpayOrderId!,
      amountPaise: payment.amountPaise,
      currency: 'INR',
      name: due.society.name,
      description: `${due.type === 'RENT' ? 'Rent' : 'Maintenance'} – ${periodLabel(due.period)}`,
      prefill: { name: payer.name, contact: payer.phone, email: payer.email, method: payer.paymentMethod },
    };
  }

  /** The app's checkout callback: verify Razorpay's signature, then settle. */
  async verify(
    auth: AuthContext,
    input: { paymentId: string; orderId: string; gatewayPaymentId: string; signature: string; method?: string },
  ): Promise<PaymentView> {
    const payment = await this.prisma.payment.findFirst({
      where: { id: input.paymentId, payerId: auth.userId, societyId: auth.societyId },
    });
    if (!payment || payment.razorpayOrderId !== input.orderId) throw ApiError.notFound('Payment not found');
    if (!this.gateway.verifyCheckout(input.orderId, input.gatewayPaymentId, input.signature)) {
      this.logger.warn(`Rejected checkout signature for payment ${payment.id}`);
      throw new ApiError(HttpStatus.BAD_REQUEST, 'PAYMENT_VERIFICATION_FAILED', 'Payment could not be verified');
    }
    const method =
      this.gateway.name === 'simulated' ? (input.method ?? 'upi') : await this.gateway.fetchMethod(input.gatewayPaymentId);
    await this.settle(payment.id, input.gatewayPaymentId, method);
    return this.view(auth, payment.id);
  }

  /**
   * Razorpay webhook. Settles payments even if the app never called back
   * (closed mid-payment, lost network). Safe to receive more than once.
   */
  async handleWebhook(rawBody: Buffer, signature: string | undefined): Promise<void> {
    if (!this.gateway.verifyWebhook(rawBody, signature)) {
      throw new ApiError(HttpStatus.BAD_REQUEST, 'PAYMENT_VERIFICATION_FAILED', 'Invalid webhook signature');
    }
    const event = JSON.parse(rawBody.toString('utf8')) as {
      event: string;
      payload?: { payment?: { entity?: { id: string; order_id: string; method?: string; error_description?: string } } };
    };
    const entity = event.payload?.payment?.entity;
    if (!entity?.order_id) return;
    const payment = await this.prisma.payment.findUnique({ where: { razorpayOrderId: entity.order_id } });
    if (!payment) {
      this.logger.warn(`Webhook for unknown order ${entity.order_id}`);
      return;
    }
    if (event.event === 'payment.captured' || event.event === 'order.paid') {
      await this.settle(payment.id, entity.id, entity.method ?? null);
    } else if (event.event === 'payment.failed' && payment.status !== 'SUCCEEDED') {
      await this.prisma.payment.update({
        where: { id: payment.id },
        data: { status: 'FAILED', failureReason: entity.error_description ?? 'Payment failed' },
      });
    }
  }

  /** Dev only: what Razorpay Checkout would return for the chosen outcome. */
  async simulate(auth: AuthContext, paymentId: string, outcome: 'success' | 'failure') {
    if (!(this.gateway instanceof SimulatedGateway)) throw ApiError.notFound();
    const payment = await this.prisma.payment.findFirst({ where: { id: paymentId, payerId: auth.userId } });
    if (!payment?.razorpayOrderId) throw ApiError.notFound('Payment not found');
    if (outcome === 'failure') {
      await this.prisma.payment.update({
        where: { id: payment.id },
        data: { status: 'FAILED', failureReason: 'Simulated failure: bank declined' },
      });
      return { failed: true as const, reason: 'Simulated failure: bank declined' };
    }
    const { gatewayPaymentId, signature } = this.gateway.completeCheckout(payment.razorpayOrderId);
    return { failed: false as const, orderId: payment.razorpayOrderId, gatewayPaymentId, signature };
  }

  async get(auth: AuthContext, paymentId: string): Promise<PaymentView> {
    return this.view(auth, paymentId);
  }

  /** Successful payments for the caller's flat (their kind of due). */
  async mine(auth: AuthContext, limit = 50): Promise<PaymentView[]> {
    const dueType = dueTypeFor(auth);
    if (!dueType || !auth.flatId) return [];
    const payments = await this.prisma.payment.findMany({
      where: { societyId: auth.societyId, status: 'SUCCEEDED', due: { flatId: auth.flatId, type: dueType } },
      include: paymentInclude,
      orderBy: { paidAt: 'desc' },
      take: limit,
    });
    return payments.map(toView);
  }

  /** The receipt PDF, generated on first request and stored. */
  async receiptPdf(auth: AuthContext, paymentId: string): Promise<{ fileName: string; pdf: Buffer }> {
    const payment = await this.accessible(auth, paymentId);
    if (payment.status !== 'SUCCEEDED' || !payment.receiptNo) throw ApiError.notFound('No receipt for this payment');

    const dir = path.resolve(this.env.receiptsDir, payment.societyId);
    const file = path.join(dir, `${payment.id}.pdf`);
    const fileName = `receipt-${payment.receiptNo.replaceAll('/', '-')}.pdf`;
    try {
      return { fileName, pdf: await readFile(file) };
    } catch {
      // Not generated yet (or storage was cleared): build it now.
    }
    const pdf = await buildReceiptPdf({
      receiptNo: payment.receiptNo,
      paidAt: payment.paidAt ?? payment.updatedAt,
      societyName: payment.society.name,
      societyAddress: payment.society.address,
      payerName: payment.payer.name,
      flatLabel: flatLabel(payment.due.flat),
      towards: `${payment.due.type === 'RENT' ? 'Rent' : 'Maintenance'} – ${periodLabel(payment.due.period)}`,
      items: payment.due.breakdown as unknown as BreakdownItem[],
      totalPaise: payment.amountPaise,
      method: payment.method,
      transactionId: payment.razorpayPaymentId,
    });
    await mkdir(dir, { recursive: true });
    await writeFile(file, pdf);
    await this.prisma.payment.update({ where: { id: payment.id }, data: { receiptUrl: `receipts/${payment.societyId}/${payment.id}.pdf` } });
    return { fileName, pdf };
  }

  /**
   * Marks the payment succeeded and the due paid, once. Locks the payment row
   * so a webhook and the app's verify call can't both settle it.
   */
  private async settle(paymentId: string, gatewayPaymentId: string, method: string | null): Promise<void> {
    const settled = await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM Payment WHERE id = ${paymentId} FOR UPDATE`;
      const payment = await tx.payment.findUniqueOrThrow({
        where: { id: paymentId },
        include: { due: true, society: { select: { timezone: true } } },
      });
      if (payment.status === 'SUCCEEDED') return null;

      const paidAt = new Date();
      const prefix = payment.due.type === 'RENT' ? 'RNT' : 'MNT';
      const provisional = formatReceiptNo(prefix, paidAt, 0, payment.society.timezone);
      const key = provisional.slice(0, provisional.lastIndexOf('/')).replaceAll('/', '-'); // "MNT-2026-10"
      await tx.$executeRaw`
        INSERT INTO ReceiptCounter (societyId, \`key\`, value) VALUES (${payment.societyId}, ${key}, 1)
        ON DUPLICATE KEY UPDATE value = value + 1`;
      const [{ value }] = await tx.$queryRaw<{ value: number }[]>`
        SELECT value FROM ReceiptCounter WHERE societyId = ${payment.societyId} AND \`key\` = ${key}`;

      const receiptNo = formatReceiptNo(prefix, paidAt, Number(value), payment.society.timezone);
      await tx.payment.update({
        where: { id: paymentId },
        data: {
          status: 'SUCCEEDED',
          razorpayPaymentId: gatewayPaymentId,
          method,
          paidAt,
          failureReason: null,
          receiptNo,
        },
      });
      if (payment.due.status === 'PENDING') {
        await tx.due.update({ where: { id: payment.dueId }, data: { status: 'PAID', paidAt } });
      } else {
        // Paid twice (e.g. two devices). Money was captured, so record it and flag for a refund.
        this.logger.warn(`Due ${payment.dueId} was already paid; payment ${paymentId} needs a refund`);
      }
      return { payment, receiptNo };
    });
    if (!settled) return;
    const { payment, receiptNo } = settled;
    await this.notifications.notify(payment.societyId, [payment.payerId], {
      type: 'payment',
      title: 'Payment received',
      body: `${inr(payment.amountPaise)} for ${payment.due.type === 'RENT' ? 'rent' : 'maintenance'}, ${periodLabel(payment.due.period)}. Receipt ${receiptNo}.`,
      data: { paymentId },
    });
  }

  /** Payers, anyone on the same flat, and the society's admins may see a payment. */
  private async accessible(auth: AuthContext, paymentId: string) {
    const payment = await this.prisma.payment.findFirst({
      where: { id: paymentId, societyId: auth.societyId },
      include: paymentInclude,
    });
    const allowed =
      payment &&
      (auth.role === 'ADMIN' || payment.payerId === auth.userId || (auth.flatId != null && payment.due.flatId === auth.flatId));
    if (!allowed) throw ApiError.notFound('Payment not found');
    return payment;
  }

  private async view(auth: AuthContext, paymentId: string): Promise<PaymentView> {
    return toView(await this.accessible(auth, paymentId));
  }
}

function toView(p: {
  id: string;
  status: PaymentStatus;
  amountPaise: number;
  method: string | null;
  gateway: string;
  receiptNo: string | null;
  paidAt: Date | null;
  razorpayPaymentId: string | null;
  failureReason: string | null;
  due: { id: string; type: DueType; period: string; breakdown: unknown; flat: { number: string; tower: { name: string } } };
  payer: { name: string };
  society: { name: string };
}): PaymentView {
  return {
    id: p.id,
    status: p.status,
    amountPaise: p.amountPaise,
    method: p.method,
    gateway: p.gateway,
    receiptNo: p.receiptNo,
    paidAt: p.paidAt,
    transactionId: p.razorpayPaymentId,
    failureReason: p.failureReason,
    due: { id: p.due.id, type: p.due.type, period: p.due.period, breakdown: p.due.breakdown as BreakdownItem[] },
    payerName: p.payer.name,
    flatLabel: flatLabel(p.due.flat),
    societyName: p.society.name,
  };
}
