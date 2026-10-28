import { PushSender, type PushMessage } from '../src/notifications/push-sender.js';
import { createFixture, createTestApp, login, resetDatabase, type TestApp } from './helpers.js';

let t: TestApp;
let fx: Awaited<ReturnType<typeof createFixture>>;
let admin: string;
let owner: string;
let tenant: string;
const pushes: { tokens: string[]; message: PushMessage }[] = [];

beforeAll(async () => {
  t = await createTestApp();
  // Capture pushes instead of logging them; one token is "dead".
  t.app.get(PushSender).send = async (tokens, message) => {
    pushes.push({ tokens, message });
    return { invalidTokens: tokens.filter((tk) => tk.startsWith('dead')) };
  };
});
afterAll(async () => {
  await t.app.close();
});
beforeEach(async () => {
  pushes.length = 0;
  await resetDatabase(t.prisma);
  fx = await createFixture(t.prisma);
  admin = (await login(t, fx.society.id, fx.admin.phone, 'ADMIN')).accessToken;
  owner = (await login(t, fx.society.id, fx.owner.phone, 'OWNER')).accessToken;
  tenant = (await login(t, fx.society.id, fx.tenant.phone, 'TENANT')).accessToken;
});

const auth = (token: string) => ({ authorization: `Bearer ${token}` });
const get = (token: string, path: string) => t.http().get(`/v1${path}`).set(auth(token));
const post = (token: string, path: string, body: object = {}) => t.http().post(`/v1${path}`).set(auth(token)).send(body);
const put = (token: string, path: string, body: object) => t.http().put(`/v1${path}`).set(auth(token)).send(body);
const patch = (token: string, path: string, body: object) => t.http().patch(`/v1${path}`).set(auth(token)).send(body);
const del = (token: string, path: string) => t.http().delete(`/v1${path}`).set(auth(token));

const poll = { question: 'Which activity for Sunday?', options: ['Movie Night', 'Karaoke'] };
const DEVICE = 'device-token-aaaaaaaaaaaaaaaaaaaaaaaa';

describe('account', () => {
  it('edits the profile and validates email, language and theme', async () => {
    const res = await patch(owner, '/me', { name: ' Omkar Patil ', email: 'Omkar@Example.com', language: 'mr', theme: 'dark' }).expect(200);
    expect(res.body.user).toMatchObject({ name: 'Omkar Patil', email: 'omkar@example.com', language: 'mr', theme: 'dark' });
    await patch(owner, '/me', { email: 'not-an-email' }).expect(400);
    await patch(owner, '/me', { language: 'ur' }).expect(400);
    await patch(owner, '/me', { photoUrl: 'https://evil.example/x.png' }).expect(400);
    expect((await patch(owner, '/me', { email: '' }).expect(200)).body.user.email).toBeNull();
  });

  it('saves notification and payment preferences, defaulting to all on', async () => {
    const initial = (await get(owner, '/me/preferences').expect(200)).body;
    expect(Object.values(initial.notifications).every(Boolean)).toBe(true);
    expect(initial.paymentMethod).toBeNull();

    const saved = (await put(owner, '/me/preferences', { notifications: { announcements: false }, paymentMethod: 'upi' }).expect(200)).body;
    expect(saved).toMatchObject({ paymentMethod: 'upi', notifications: { announcements: false, paymentReminder: true } });
    await put(owner, '/me/preferences', { notifications: { marketing: true } }).expect(400);
    await put(owner, '/me/preferences', { paymentMethod: 'bitcoin' }).expect(400);
  });

  it('refuses to delete the last admin, and erases a resident who leaves', async () => {
    const lastAdmin = await del(admin, '/me').expect(409);
    expect(lastAdmin.body.error.code).toBe('LAST_ADMIN');

    await put(tenant, '/devices', { token: DEVICE, platform: 'android' }).expect(204);
    await del(tenant, '/me').expect(204);
    await get(tenant, '/me').expect(401); // membership ended, even with a valid access token
    const user = await t.prisma.user.findUniqueOrThrow({ where: { id: fx.tenant.user.id } });
    expect(user).toMatchObject({ name: 'Deleted user', email: null, phone: `deleted:${fx.tenant.user.id}` });
    expect(await t.prisma.deviceToken.count()).toBe(0);
    // The number can't sign in any more.
    const res = await t.http().post('/v1/auth/otp/request').send({ phone: fx.tenant.phone, societyId: fx.society.id, role: 'TENANT' });
    expect(res.body.error.code).toBe('NOT_REGISTERED');
  });
});

describe('notifications', () => {
  it('lists, counts and marks notifications read, newest first', async () => {
    await post(admin, '/polls', poll).expect(201);
    await post(admin, '/notices', { title: 'Lift maintenance', body: 'Lift B is off on Sunday.' }).expect(201);

    const list = (await get(owner, '/notifications').expect(200)).body;
    expect(list.map((n: { type: string }) => n.type)).toEqual(['notice', 'poll']);
    expect((await get(owner, '/notifications/unread-count').expect(200)).body.count).toBe(2);

    await post(owner, `/notifications/${list[0].id}/read`).expect(204);
    expect((await get(owner, '/notifications/unread-count').expect(200)).body.count).toBe(1);
    await post(tenant, `/notifications/${list[1].id}/read`).expect(404); // not theirs
    expect((await post(owner, '/notifications/read-all').expect(201)).body.updated).toBe(1);
    expect((await get(owner, '/notifications/unread-count').expect(200)).body.count).toBe(0);
  });

  it('respects preferences and pushes to registered devices, dropping dead tokens', async () => {
    await put(owner, '/devices', { token: DEVICE, platform: 'android' }).expect(204);
    await put(tenant, '/devices', { token: `dead-${DEVICE}`, platform: 'ios' }).expect(204);
    await put(tenant, '/me/preferences', { notifications: { push: true } }).expect(200);

    await post(admin, '/polls', poll).expect(201);
    expect(pushes).toHaveLength(1);
    expect(pushes[0].tokens.sort()).toEqual([DEVICE, `dead-${DEVICE}`].sort());
    expect(pushes[0].message).toMatchObject({ title: 'New poll', data: { type: 'poll' } });
    expect(await t.prisma.deviceToken.findMany({ select: { token: true } })).toEqual([{ token: DEVICE }]);

    // Owner turns announcements off: no in-app row, no push. Tenant turns push off: in-app only.
    await put(owner, '/me/preferences', { notifications: { announcements: false } }).expect(200);
    await put(tenant, '/devices', { token: `tenant-${DEVICE}`, platform: 'ios' }).expect(204);
    await put(tenant, '/me/preferences', { notifications: { push: false } }).expect(200);
    pushes.length = 0;
    await post(admin, '/polls', { ...poll, question: 'Second poll please?' }).expect(201);
    expect(pushes).toEqual([]);
    expect(await t.prisma.notification.count({ where: { userId: fx.owner.user.id } })).toBe(1);
    expect(await t.prisma.notification.count({ where: { userId: fx.tenant.user.id } })).toBe(2);

    await del(owner, `/devices/${DEVICE}`).expect(204);
    expect(await t.prisma.deviceToken.count({ where: { userId: fx.owner.user.id } })).toBe(0);
  });

  it('tells the resident when their complaint changes status', async () => {
    const complaint = (await post(owner, '/complaints', { title: 'Lift stuck', description: 'Stuck on floor 2' }).expect(201)).body;
    await patch(admin, `/complaints/${complaint.id}/status`, { status: 'RESOLVED' }).expect(200);
    const [note] = (await get(owner, '/notifications').expect(200)).body;
    expect(note).toMatchObject({ type: 'complaint', body: '"Lift stuck" is resolved.', data: { complaintId: complaint.id } });
  });
});

describe('household', () => {
  it('is shared by the flat and private to it', async () => {
    const added = (await post(owner, '/household', { name: 'Pragati Patil', relation: 'Mother', phone: '98765 43210' }).expect(201)).body;
    expect(added).toMatchObject({ name: 'Pragati Patil', relation: 'Mother', phone: '+919876543210' });
    await post(owner, '/household', { name: 'Bad Phone', relation: 'Son', phone: '12345' }).expect(400);

    // Owner and tenant of 102 share the list; admin (no flat) can't use it.
    expect((await get(tenant, '/household').expect(200)).body).toHaveLength(1);
    await get(admin, '/household').expect(403);
    await patch(tenant, `/household/${added.id}`, { name: 'Pragati P.', relation: 'Mother' }).expect(200);

    // Another flat's resident can't touch it.
    const other = await t.prisma.householdMember.create({ data: { flatId: fx.flat101.id, name: 'Elsewhere', relation: 'Son' } });
    await del(owner, `/household/${other.id}`).expect(404);
    await del(owner, `/household/${added.id}`).expect(204);
  });
});

describe('society and services', () => {
  it('shows the office contacts and the services directory', async () => {
    const society = (await get(tenant, '/society').expect(200)).body;
    expect(society.office).toEqual([{ name: 'Asha Admin', phone: fx.admin.phone }]);

    await post(owner, '/services', { category: 'Maid', name: 'Rekha', phone: '9876543210' }).expect(403);
    await post(admin, '/services', { category: 'Maid', name: 'Rekha', phone: '9876543210', rating: 4.5 }).expect(201);
    const services = (await get(tenant, '/services').expect(200)).body;
    expect(services).toEqual([expect.objectContaining({ category: 'Maid', name: 'Rekha', phone: '+919876543210', rating: 4.5 })]);
  });
});

describe('tenancy', () => {
  const terms = () => ({
    rentBreakdown: [
      { label: 'Rent', amountPaise: 1_400_000 },
      { label: 'Parking', amountPaise: 100_000 },
    ],
    depositPaise: 6_000_000,
    rentDueDay: 5,
    startDate: new Date().toISOString(),
  });

  it('owners add a tenant by mobile; the tenant sees the owner and lease', async () => {
    await post(tenant, '/tenancy', { ...terms(), tenantName: 'X', tenantPhone: '9811111111' }).expect(403);
    await post(owner, '/tenancy', { ...terms(), tenantName: 'Neha Shah', tenantPhone: '98111 11111', endDate: new Date(Date.now() - 86_400_000) }).expect(400);

    const created = (await post(owner, '/tenancy', { ...terms(), tenantName: 'Neha Shah', tenantPhone: '98111 11111' }).expect(201)).body.tenancy;
    expect(created).toMatchObject({
      monthlyRentPaise: 1_500_000, // sum of the breakdown
      flatLabel: 'Tower-A, 102',
      tenant: { name: 'Neha Shah', phone: '+919811111111', status: 'INVITED' },
      owner: { name: 'Omkar Owner' },
    });
    const again = await post(owner, '/tenancy', { ...terms(), tenantName: 'Someone', tenantPhone: '9822222222' }).expect(409);
    expect(again.body.error.code).toBe('TENANCY_EXISTS');

    // The new tenant can now sign in and sees their owner's contact.
    const neha = (await login(t, fx.society.id, '9811111111', 'TENANT')).accessToken;
    const mine = (await get(neha, '/tenancy').expect(200)).body.tenancy;
    expect(mine).toMatchObject({ id: created.id, owner: { name: 'Omkar Owner', phone: fx.owner.phone }, tenant: { status: 'ACTIVE' } });
    expect((await get(neha, '/notifications').expect(200)).body[0].type).toBe('tenancy');

    // Fixture's other tenant on the flat has no lease with this owner.
    expect((await get(tenant, '/tenancy').expect(200)).body.tenancy).toBeNull();

    const updated = (await patch(owner, `/tenancy/${created.id}`, { ...terms(), rentBreakdown: [{ label: 'Rent', amountPaise: 1_600_000 }] }).expect(200)).body;
    expect(updated.tenancy.monthlyRentPaise).toBe(1_600_000);

    await post(owner, `/tenancy/${created.id}/end`).expect(201);
    await get(neha, '/me').expect(401);
    expect((await get(owner, '/tenancy').expect(200)).body.tenancy).toBeNull();
  });
});
