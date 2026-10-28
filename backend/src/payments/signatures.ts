import { createHmac, timingSafeEqual } from 'node:crypto';

/**
 * Razorpay signature checks (https://razorpay.com/docs/payments/server-integration/):
 * - Checkout success: HMAC-SHA256(key_secret, `${order_id}|${payment_id}`), hex.
 * - Webhooks: HMAC-SHA256(webhook_secret, raw request body), hex.
 */
export function checkoutSignature(keySecret: string, orderId: string, paymentId: string): string {
  return createHmac('sha256', keySecret).update(`${orderId}|${paymentId}`).digest('hex');
}

export function webhookSignature(webhookSecret: string, rawBody: Buffer | string): string {
  return createHmac('sha256', webhookSecret).update(rawBody).digest('hex');
}

/** Constant-time comparison of two hex signatures. */
export function signaturesMatch(expectedHex: string, receivedHex: string | undefined): boolean {
  if (!receivedHex || !/^[0-9a-f]+$/i.test(receivedHex)) return false;
  const a = Buffer.from(expectedHex, 'hex');
  const b = Buffer.from(receivedHex, 'hex');
  return a.length === b.length && timingSafeEqual(a, b);
}
