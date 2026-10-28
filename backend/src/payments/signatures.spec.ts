import { checkoutSignature, signaturesMatch, webhookSignature } from './signatures.js';
import { SimulatedGateway } from './gateway.js';

describe('Razorpay signatures', () => {
  it('computes the checkout signature over "order_id|payment_id"', () => {
    // Reference value from: printf 'order_123|pay_456' | openssl dgst -sha256 -hmac secret
    expect(checkoutSignature('secret', 'order_123', 'pay_456')).toBe(
      '18bfc0baafae8f6367711ee362f2201aaa3654274683100e5367bb9a2bd29cbe',
    );
  });

  it('accepts only the exact signature', () => {
    const good = checkoutSignature('secret', 'order_1', 'pay_1');
    expect(signaturesMatch(good, good)).toBe(true);
    expect(signaturesMatch(good, good.toUpperCase())).toBe(true); // hex is case-insensitive
    expect(signaturesMatch(good, checkoutSignature('other', 'order_1', 'pay_1'))).toBe(false);
    expect(signaturesMatch(good, good.slice(0, 62))).toBe(false);
    expect(signaturesMatch(good, 'not-hex')).toBe(false);
    expect(signaturesMatch(good, undefined)).toBe(false);
  });

  it('signs webhooks over the raw body, byte for byte', () => {
    const body = Buffer.from('{"event":"payment.captured"}');
    const sig = webhookSignature('whsec', body);
    expect(signaturesMatch(sig, webhookSignature('whsec', '{"event":"payment.captured"}'))).toBe(true);
    // Re-serialised JSON (extra space) must not verify.
    expect(signaturesMatch(sig, webhookSignature('whsec', '{"event": "payment.captured"}'))).toBe(false);
  });
});

describe('SimulatedGateway', () => {
  it('produces checkouts that pass the same verification as Razorpay', async () => {
    const gateway = new SimulatedGateway('jwt-secret-for-tests-only-32-chars!!');
    const { orderId } = await gateway.createOrder();
    const { gatewayPaymentId, signature } = gateway.completeCheckout(orderId);
    expect(gateway.verifyCheckout(orderId, gatewayPaymentId, signature)).toBe(true);
    expect(gateway.verifyCheckout(`${orderId}x`, gatewayPaymentId, signature)).toBe(false);
  });
});
