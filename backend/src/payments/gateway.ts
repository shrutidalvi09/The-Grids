import { createHmac, randomBytes } from 'node:crypto';
import { Logger } from '@nestjs/common';
import type { Env } from '../config/env.js';
import { checkoutSignature, signaturesMatch, webhookSignature } from './signatures.js';

export interface GatewayOrder {
  orderId: string;
}

/** The payment provider. The app opens its checkout; the server verifies. */
export abstract class PaymentGateway {
  abstract readonly name: 'razorpay' | 'simulated';
  /** Public key the app passes to Checkout (null for the simulator). */
  abstract readonly publicKey: string | null;

  abstract createOrder(input: { amountPaise: number; receipt: string; notes: Record<string, string> }): Promise<GatewayOrder>;

  /** upi | card | netbanking | wallet …, or null if unknown. */
  abstract fetchMethod(gatewayPaymentId: string): Promise<string | null>;

  abstract verifyCheckout(orderId: string, gatewayPaymentId: string, signature: string): boolean;

  abstract verifyWebhook(rawBody: Buffer, signature: string | undefined): boolean;
}

/** Razorpay Orders + Payments REST API (no SDK needed). */
export class RazorpayGateway extends PaymentGateway {
  readonly name = 'razorpay' as const;
  private readonly logger = new Logger(RazorpayGateway.name);

  constructor(private readonly config: NonNullable<Env['razorpay']>) {
    super();
  }

  get publicKey(): string {
    return this.config.keyId;
  }

  private get authHeader(): string {
    return `Basic ${Buffer.from(`${this.config.keyId}:${this.config.keySecret}`).toString('base64')}`;
  }

  async createOrder(input: { amountPaise: number; receipt: string; notes: Record<string, string> }): Promise<GatewayOrder> {
    const res = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: { authorization: this.authHeader, 'content-type': 'application/json' },
      body: JSON.stringify({ amount: input.amountPaise, currency: 'INR', receipt: input.receipt, notes: input.notes }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) {
      this.logger.error(`Razorpay order failed: HTTP ${res.status} ${await res.text()}`);
      throw new Error('Could not create the payment order');
    }
    const order = (await res.json()) as { id: string };
    return { orderId: order.id };
  }

  async fetchMethod(gatewayPaymentId: string): Promise<string | null> {
    try {
      const res = await fetch(`https://api.razorpay.com/v1/payments/${encodeURIComponent(gatewayPaymentId)}`, {
        headers: { authorization: this.authHeader },
        signal: AbortSignal.timeout(10_000),
      });
      if (!res.ok) return null;
      return ((await res.json()) as { method?: string }).method ?? null;
    } catch {
      return null;
    }
  }

  verifyCheckout(orderId: string, gatewayPaymentId: string, signature: string): boolean {
    return signaturesMatch(checkoutSignature(this.config.keySecret, orderId, gatewayPaymentId), signature);
  }

  verifyWebhook(rawBody: Buffer, signature: string | undefined): boolean {
    if (!this.config.webhookSecret) return false;
    return signaturesMatch(webhookSignature(this.config.webhookSecret, rawBody), signature);
  }
}

/**
 * Development stand-in for Razorpay. It signs exactly like Razorpay does, so
 * the same verification code runs; only order creation is local. Refused in
 * production by env validation.
 */
export class SimulatedGateway extends PaymentGateway {
  readonly name = 'simulated' as const;
  readonly publicKey = null;
  /** Stable across restarts in one environment. */
  readonly secret: string;

  constructor(jwtSecret: string) {
    super();
    this.secret = createHmac('sha256', jwtSecret).update('simulated-razorpay').digest('hex');
  }

  async createOrder(): Promise<GatewayOrder> {
    return { orderId: `order_sim_${randomBytes(7).toString('hex')}` };
  }

  /** What Razorpay would hand the app after a successful checkout. */
  completeCheckout(orderId: string): { gatewayPaymentId: string; signature: string } {
    const gatewayPaymentId = `pay_sim_${randomBytes(7).toString('hex')}`;
    return { gatewayPaymentId, signature: checkoutSignature(this.secret, orderId, gatewayPaymentId) };
  }

  /** The method is chosen on the simulated checkout and passed through. */
  async fetchMethod(): Promise<string | null> {
    return null;
  }

  verifyCheckout(orderId: string, gatewayPaymentId: string, signature: string): boolean {
    return signaturesMatch(checkoutSignature(this.secret, orderId, gatewayPaymentId), signature);
  }

  verifyWebhook(rawBody: Buffer, signature: string | undefined): boolean {
    return signaturesMatch(webhookSignature(this.secret, rawBody), signature);
  }
}
