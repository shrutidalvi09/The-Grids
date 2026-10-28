import { PaymentGateway, SimulatedGateway } from '../src/payments/gateway.js';
import { checkoutSignature, webhookSignature } from '../src/payments/signatures.js';
import { createFixture, createTestApp, login, resetDatabase, type TestApp } from './helpers.js';

let t: TestApp;
let fx: Awaited<ReturnType<typeof createFixture>>;
let admin: string;
let owner: string;
let tenant: string;
let otherOwner: string; // Asha as owner of flat 101
let secret: string;

const PERIOD = '2026-10';

beforeAll(async () => {
  t = await createTestApp();
  const gateway = t.app.get(PaymentGateway);
  if (!(gateway instanceof SimulatedGateway)) throw new Error('Tests expect the simulated gateway (no Razorpay keys)');
  secret = gateway.secret;
});
afterAll(async () => {
  await t.app.close();
});
beforeEach(async () => {
  await resetDatabase(t.prisma);
  fx = await createFixture(t.prisma);
  await t.prisma.society.update({ where: { id: fx.society.id }, data: { maintenanceDueDay: 10 } });
  await t.prisma.maintenanceItem.createMany({
    data: [
      { societyId: fx.society.id, label: 'Cleaning', amountPaise: 50000, sortOrder: 0 },
      { societyId: fx.society.id, label: 'Security', amountPaise: 200000, sortOrder: 1 },
    ],
  });
  await t.prisma.tenancy.create({
    data: {
      societyId: fx.society.id,
      flatId: fx.flat102.id,
      ownerId: fx.owner.user.id,
      tenantId: fx.tenant.user.id,
      monthlyRentPaise: 1500000,
      depositPaise: 6000000,
      rentDueDay: 5,
      rentBreakdown: [{ label: 'Rent', amountPaise: 1500000 }],
      startDate: new Date('2026-01-01T00:00:00Z'),
    },
  });
  // One sign-in per phone (a second within 30 s would hit the OTP cooldown);
  // Asha's admin access token stays valid after she switches to owner.
  const asha = await login(t, fx.society.id, fx.admin.phone, 'ADMIN');
  admin = asha.accessToken;
  owner = (await login(t, fx.society.id, fx.owner.phone, 'OWNER')).accessToken;
  tenant = (await login(t, fx.society.id, fx.tenant.phone, 'TENANT')).accessToken;
  otherOwner = (
    await t
      .http()
      .post('/v1/auth/switch')
      .set('authorization', `Bearer ${asha.accessToken}`)
      .send({ membershipId: fx.adminAsOwner.id, refreshToken: asha.refreshToken })
  ).body.accessToken;
  await post(admin, '/maintenance/dues/generate', { period: PERIOD }).expect(200);
});

const get = (token: string, path: string) => t.http().get(`/v1${path}`).set('authorization', `Bearer ${token}`);
const post = (token: string, path: string, body: object = {}) =>
  t.http().post(`/v1${path}`).set('authorization', `Bearer ${token}`).send(body);

async function myDue(token: string) {
  const res = await get(token, '/dues/mine').expect(200);
  return res.body[0] as { id: string; amountPaise: number; type: string };
}

/** The whole happy path a phone goes through with the simulated checkout. */
async function pay(token: string, dueId: string) {
  const order = (await post(token, '/payments/orders', { dueId }).expect(201)).body;
  const sim = (await post(token, `/payments/${order.paymentId}/simulate`, { outcome: 'success' }).expect(200)).body;
  const verified = await post(token, '/payments/verify', {
    paymentId: order.paymentId,
    orderId: sim.orderId,
    gatewayPaymentId: sim.gatewayPaymentId,
    signature: sim.signature,
    method: 'card',
  }).expect(200);
  return verified.body;
}

describe('dues', () => {
  it('issues maintenance for occupied flats and rent for tenancies, once per month', async () => {
    const dues = await t.prisma.due.findMany({ where: { period: PERIOD }, orderBy: [{ type: 'asc' }, { flatId: 'asc' }] });
    expect(dues.map((d) => [d.type, d.amountPaise])).toEqual(
      expect.arrayContaining([
        ['MAINTENANCE', 250000],
        ['MAINTENANCE', 250000],
        ['RENT', 1500000],
      ]),
    );
    expect(dues).toHaveLength(3);
    const rent = dues.find((d) => d.type === 'RENT')!;
    expect(rent.dueDate.toISOString()).toBe('2026-10-05T04:30:00.000Z'); // 10:00 IST on the 5th

    const again = await post(admin, '/maintenance/dues/generate', { period: PERIOD }).expect(200);
    expect(again.body).toEqual({ period: PERIOD, created: 0 });
    await post(owner, '/maintenance/dues/generate', { period: PERIOD }).expect(403);
  });

  it('owners see maintenance, tenants see rent, admins see none', async () => {
    expect((await get(owner, '/dues/mine')).body.map((d: { type: string }) => d.type)).toEqual(['MAINTENANCE']);
    expect((await get(tenant, '/dues/mine')).body.map((d: { type: string }) => d.type)).toEqual(['RENT']);
    expect((await get(admin, '/dues/mine')).body).toEqual([]);
  });

  it('only admins change the maintenance charge, which applies to new bills only', async () => {
    const body = { items: [{ label: 'Cleaning', amountPaise: 60000 }, { label: 'Lift AMC', amountPaise: 40000 }], dueDay: 7 };
    await t.http().put('/v1/maintenance/config').set('authorization', `Bearer ${owner}`).send(body).expect(403);
    await t.http().put('/v1/maintenance/config').set('authorization', `Bearer ${admin}`).send({ items: [], dueDay: 7 }).expect(400);
    const updated = await t.http().put('/v1/maintenance/config').set('authorization', `Bearer ${admin}`).send(body).expect(200);
    expect(updated.body).toMatchObject({ totalPaise: 100000, dueDay: 7 });

    expect((await myDue(owner)).amountPaise).toBe(250000); // already issued: unchanged
    await post(admin, '/maintenance/dues/generate', { period: '2026-11' }).expect(200);
    const nov = await t.prisma.due.findFirstOrThrow({ where: { period: '2026-11', type: 'MAINTENANCE', flatId: fx.flat102.id } });
    expect(nov.amountPaise).toBe(100000);
  });
});

describe('paying a due', () => {
  it('verifies the checkout, settles the due and issues a numbered receipt', async () => {
    const due = await myDue(owner);
    const order = (await post(owner, '/payments/orders', { dueId: due.id }).expect(201)).body;
    expect(order).toMatchObject({ gateway: 'simulated', amountPaise: 250000, currency: 'INR', description: 'Maintenance – October 2026' });
    // Retrying reuses the same order.
    expect((await post(owner, '/payments/orders', { dueId: due.id }).expect(201)).body.orderId).toBe(order.orderId);

    const paid = await pay(owner, due.id);
    expect(paid).toMatchObject({ status: 'SUCCEEDED', method: 'card', amountPaise: 250000, flatLabel: 'Tower-A, 102' });
    expect(paid.receiptNo).toMatch(/^MNT\/\d{4}\/\d{2}\/0001$/);
    expect((await get(owner, '/dues/mine')).body).toEqual([]);

    const again = await post(owner, '/payments/orders', { dueId: due.id }).expect(409);
    expect(again.body.error.code).toBe('DUE_NOT_PENDING');
    expect((await get(owner, '/payments/mine')).body.map((p: { id: string }) => p.id)).toEqual([paid.id]);
  });

  it('tenants pay rent but cannot pay maintenance, and nobody pays another flat', async () => {
    const maintenance = await myDue(owner);
    await post(tenant, '/payments/orders', { dueId: maintenance.id }).expect(404);
    await post(otherOwner, '/payments/orders', { dueId: maintenance.id }).expect(404);
    await post(admin, '/payments/orders', { dueId: maintenance.id }).expect(403);

    const rent = await myDue(tenant);
    const paid = await pay(tenant, rent.id);
    expect(paid.receiptNo).toMatch(/^RNT\//);
    expect(paid.due.breakdown).toEqual([{ label: 'Rent', amountPaise: 1500000 }]);
  });

  it('rejects a forged signature and leaves the due unpaid', async () => {
    const due = await myDue(owner);
    const order = (await post(owner, '/payments/orders', { dueId: due.id }).expect(201)).body;
    const forged = checkoutSignature('not-the-secret', order.orderId, 'pay_forged');
    const res = await post(owner, '/payments/verify', {
      paymentId: order.paymentId,
      orderId: order.orderId,
      gatewayPaymentId: 'pay_forged',
      signature: forged,
    }).expect(400);
    expect(res.body.error.code).toBe('PAYMENT_VERIFICATION_FAILED');
    expect((await get(owner, '/dues/mine')).body).toHaveLength(1);
  });

  it('numbers receipts sequentially within a month', async () => {
    await post(admin, '/maintenance/dues/generate', { period: '2026-11' }).expect(200);
    const [oct, nov] = (await get(owner, '/dues/mine')).body;
    const first = await pay(owner, oct.id);
    const second = await pay(owner, nov.id);
    expect([first.receiptNo.slice(-4), second.receiptNo.slice(-4)]).toEqual(['0001', '0002']);
  });
});

describe('Razorpay webhooks', () => {
  function sendWebhook(body: object, signWith = secret) {
    const raw = JSON.stringify(body);
    return t
      .http()
      .post('/v1/payments/webhook')
      .set('content-type', 'application/json')
      .set('x-razorpay-signature', webhookSignature(signWith, raw))
      .send(raw);
  }

  it('settles a payment the app never confirmed, exactly once', async () => {
    const due = await myDue(owner);
    const order = (await post(owner, '/payments/orders', { dueId: due.id }).expect(201)).body;
    const event = {
      event: 'payment.captured',
      payload: { payment: { entity: { id: 'pay_webhook_1', order_id: order.orderId, method: 'upi' } } },
    };
    await sendWebhook(event).expect(200);
    await sendWebhook(event).expect(200); // Razorpay retries deliveries

    const payment = await t.prisma.payment.findUniqueOrThrow({ where: { id: order.paymentId } });
    expect(payment).toMatchObject({ status: 'SUCCEEDED', method: 'upi', razorpayPaymentId: 'pay_webhook_1' });
    expect(payment.receiptNo).toMatch(/\/0001$/);
    const counter = await t.prisma.receiptCounter.findFirstOrThrow();
    expect(counter.value).toBe(1);
    expect((await get(owner, '/dues/mine')).body).toEqual([]);
  });

  it('rejects unsigned or tampered deliveries', async () => {
    const due = await myDue(owner);
    const order = (await post(owner, '/payments/orders', { dueId: due.id }).expect(201)).body;
    const event = { event: 'payment.captured', payload: { payment: { entity: { id: 'p', order_id: order.orderId } } } };
    await sendWebhook(event, 'wrong-secret').expect(400);
    await t.http().post('/v1/payments/webhook').send(event).expect(400);
    expect((await get(owner, '/dues/mine')).body).toHaveLength(1);
  });

  it('records failures, and a retry can still succeed on the same order', async () => {
    const due = await myDue(owner);
    const order = (await post(owner, '/payments/orders', { dueId: due.id }).expect(201)).body;
    await sendWebhook({
      event: 'payment.failed',
      payload: { payment: { entity: { id: 'pay_f', order_id: order.orderId, error_description: 'Insufficient funds' } } },
    }).expect(200);
    expect((await get(owner, `/payments/${order.paymentId}`)).body).toMatchObject({
      status: 'FAILED',
      failureReason: 'Insufficient funds',
    });
    const retry = (await post(owner, '/payments/orders', { dueId: due.id }).expect(201)).body;
    expect(retry.orderId).toBe(order.orderId);
    expect((await pay(owner, due.id)).status).toBe('SUCCEEDED');
  });
});

describe('receipts', () => {
  it('serves the PDF to the flat and admins only', async () => {
    const paid = await pay(owner, (await myDue(owner)).id);
    const res = await get(owner, `/payments/${paid.id}/receipt`)
      .buffer(true)
      .parse((r, cb) => {
        const chunks: Buffer[] = [];
        r.on('data', (c: Buffer) => chunks.push(c));
        r.on('end', () => cb(null, Buffer.concat(chunks)));
      })
      .expect(200);
    expect(res.headers['content-type']).toBe('application/pdf');
    expect(res.headers['content-disposition']).toContain('receipt-MNT-');
    expect((res.body as Buffer).subarray(0, 5).toString()).toBe('%PDF-');

    await get(tenant, `/payments/${paid.id}/receipt`).expect(200); // same flat
    await get(admin, `/payments/${paid.id}/receipt`).expect(200);
    await get(otherOwner, `/payments/${paid.id}/receipt`).expect(404);
  });
});

describe('admin: defaulters, reminders and society bills', () => {
  it('lists unpaid flats and reminds their owners once a day', async () => {
    const defaulters = (await get(admin, '/maintenance/defaulters').expect(200)).body;
    expect(defaulters.map((d: { flatLabel: string }) => d.flatLabel).sort()).toEqual(['Tower-A, 101', 'Tower-A, 102']);
    await get(owner, '/maintenance/defaulters').expect(403);

    const remind = await post(admin, `/maintenance/defaulters/${fx.flat102.id}/remind`).expect(200);
    expect(remind.body).toEqual({ notified: 1 });
    const note = await t.prisma.notification.findFirstOrThrow({ where: { userId: fx.owner.user.id } });
    expect(note.body).toContain('₹2,500');
    expect((await post(admin, `/maintenance/defaulters/${fx.flat102.id}/remind`).expect(429)).body.error.code).toBe('ALREADY_REMINDED');

    expect((await get(admin, '/maintenance/summary').expect(200)).body).toMatchObject({ pendingFlats: 2, pendingAmountPaise: 500000 });
  });

  it('tracks what the society owes vendors', async () => {
    await post(owner, '/society-bills', { vendor: 'Lift AMC', amountPaise: 1800000, dueDate: '2026-11-10' }).expect(403);
    const bill = (await post(admin, '/society-bills', { vendor: 'Lift AMC', amountPaise: 1800000, dueDate: '2026-11-10' }).expect(201)).body;
    expect((await get(admin, '/society-bills?status=DUE')).body).toHaveLength(1);
    await t.http().patch(`/v1/society-bills/${bill.id}/paid`).set('authorization', `Bearer ${admin}`).expect(204);
    expect((await get(admin, '/society-bills?status=PAID')).body[0]).toMatchObject({ vendor: 'Lift AMC', status: 'PAID' });
  });
});
