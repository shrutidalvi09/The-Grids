import { createFixture, createTestApp, login, resetDatabase, type TestApp } from './helpers.js';

let t: TestApp;
let fx: Awaited<ReturnType<typeof createFixture>>;
let admin: string;
let owner: string;
let tenant: string;
let guard: string;
let adminRefresh: string;

beforeAll(async () => {
  t = await createTestApp();
});
afterAll(async () => {
  await t.app.close();
});
beforeEach(async () => {
  await resetDatabase(t.prisma);
  fx = await createFixture(t.prisma);
  const adminLogin = await login(t, fx.society.id, fx.admin.phone, 'ADMIN');
  admin = adminLogin.accessToken;
  adminRefresh = adminLogin.refreshToken;
  owner = (await login(t, fx.society.id, fx.owner.phone, 'OWNER')).accessToken;
  tenant = (await login(t, fx.society.id, fx.tenant.phone, 'TENANT')).accessToken;
  guard = (await login(t, fx.society.id, fx.guard.phone, 'GUARD')).accessToken;
});

const auth = (token: string) => ({ authorization: `Bearer ${token}` });
const get = (token: string, path: string) => t.http().get(`/v1${path}`).set(auth(token));
const post = (token: string, path: string, body: object = {}) => t.http().post(`/v1${path}`).set(auth(token)).send(body);
const patch = (token: string, path: string, body: object) => t.http().patch(`/v1${path}`).set(auth(token)).send(body);
const del = (token: string, path: string) => t.http().delete(`/v1${path}`).set(auth(token));

/** The admin also owns flat 101: switch roles (a second OTP would hit the cooldown). */
async function asAdminOwner(): Promise<string> {
  const res = await post(admin, '/auth/switch', { membershipId: fx.adminAsOwner.id, refreshToken: adminRefresh }).expect(200);
  return res.body.accessToken;
}

const notificationsOf = (userId: string) => t.prisma.notification.findMany({ where: { userId }, orderBy: { createdAt: 'asc' } });

describe('guards', () => {
  it('sign in as Security Guard and only reach the gate and their own profile', async () => {
    const me = (await get(guard, '/me').expect(200)).body;
    expect(me.membership).toMatchObject({ role: 'GUARD', flatLabel: null });

    const home = (await get(guard, '/home').expect(200)).body;
    expect(home.gate).toEqual({ awaitingApproval: 0, expected: 0, inside: 0, parcels: 0, staffInside: 0 });
    expect(home.checklist).toBeUndefined();
    expect(home.stats).toBeUndefined();

    await get(guard, '/flats').expect(200);
    for (const path of ['/dues/mine', '/complaints', '/polls', '/household', '/maintenance/summary', '/neighbours']) {
      expect((await get(guard, path)).status, path).toBe(403);
    }
  });

  it('are invited by admins without a flat', async () => {
    await post(admin, '/memberships/invites', { phone: '98111 33333', name: 'Vikram Singh', role: 'GUARD', flatId: fx.flat101.id }).expect(201);
    const membership = await t.prisma.membership.findFirstOrThrow({ where: { role: 'GUARD', user: { phone: '+919811133333' } } });
    expect(membership.flatId).toBeNull();
    // Owners can't add guards.
    await post(owner, '/memberships/invites', { phone: '98111 44444', name: 'Xavier', role: 'GUARD' }).expect(403);
  });

  it("don't receive society-wide broadcasts like polls", async () => {
    await post(admin, '/polls', { question: 'Which day for the meeting?', options: ['Sat', 'Sun'] }).expect(201);
    expect(await notificationsOf(fx.guard.user.id)).toEqual([]);
  });
});

describe('approve at the gate', () => {
  it('a walk-in asks the flat; the first answer lets them in and tells the guard', async () => {
    await t.prisma.user.update({ where: { id: fx.tenant.user.id }, data: { notificationPrefs: { visitorArrival: false, push: false } } });
    const walkIn = (
      await post(guard, '/visitors', { name: 'Swiggy', type: 'DELIVERY', flatId: fx.flat102.id, arrival: 'ASK' }).expect(201)
    ).body;
    expect(walkIn).toMatchObject({ status: 'PENDING_APPROVAL', preApproved: false, flatLabel: 'Tower-A, 102' });

    // Both residents of 102 are asked, even with visitor notifications switched off.
    const asked = await t.prisma.notification.findMany({ where: { type: 'visitor_approval' } });
    expect(asked.map((n) => n.userId).sort()).toEqual([fx.owner.user.id, fx.tenant.user.id].sort());
    expect(asked[0]).toMatchObject({ title: 'Visitor at the gate', body: 'Swiggy is at the gate. Allow or deny?' });
    expect((await get(guard, '/home').expect(200)).body.gate.awaitingApproval).toBe(1);

    // Another flat can't answer.
    const other = await t.prisma.user.create({ data: { name: 'Neighbour', phone: '+919811155555' } });
    await t.prisma.membership.create({
      data: { userId: other.id, societyId: fx.society.id, role: 'OWNER', flatId: fx.flat101.id, status: 'ACTIVE' },
    });
    const neighbour = (await login(t, fx.society.id, '+919811155555', 'OWNER')).accessToken;
    await patch(neighbour, `/visitors/${walkIn.id}/decision`, { allow: true }).expect(404);
    await patch(guard, `/visitors/${walkIn.id}/decision`, { allow: true }).expect(403);

    const allowed = (await patch(tenant, `/visitors/${walkIn.id}/decision`, { allow: true }).expect(200)).body;
    expect(allowed.status).toBe('CHECKED_IN');
    expect(allowed.inTime).not.toBeNull();
    const second = await patch(owner, `/visitors/${walkIn.id}/decision`, { allow: false }).expect(409);
    expect(second.body.error.code).toBe('VISITOR_DECIDED');

    const told = (await notificationsOf(fx.guard.user.id)).filter((n) => n.type === 'visitor_decision');
    expect(told).toHaveLength(1);
    expect(told[0]).toMatchObject({ title: 'Visitor allowed', body: 'Tower-A, 102: Swiggy' });
    // Admins aren't bothered while the society has a guard.
    expect((await notificationsOf(fx.admin.user.id)).filter((n) => n.type === 'visitor_decision')).toEqual([]);
  });

  it('a denied visitor stays out; the guard can also let someone in straight away', async () => {
    const walkIn = (await post(guard, '/visitors', { name: 'Salesman', type: 'GUEST', flatId: fx.flat102.id, arrival: 'ASK' })).body;
    expect((await patch(owner, `/visitors/${walkIn.id}/decision`, { allow: false }).expect(200)).body.status).toBe('DENIED');

    const courier = (
      await post(guard, '/visitors', {
        name: 'BlueDart',
        type: 'DELIVERY',
        flatId: fx.flat102.id,
        arrival: 'CHECK_IN',
        photoUrl: '/uploads/abc123.jpg',
        vehicleNumber: 'mh 04 ab 1234',
      }).expect(201)
    ).body;
    expect(courier).toMatchObject({ status: 'CHECKED_IN', photoUrl: '/uploads/abc123.jpg', vehicleNumber: 'MH04AB1234' });
    expect((await notificationsOf(fx.owner.user.id)).map((n) => n.type)).toContain('visitor');

    await post(guard, '/visitors', { name: 'X', type: 'GUEST', flatId: fx.flat102.id, photoUrl: 'https://evil.example/x.jpg' }).expect(400);
  });
});

describe('guest passes', () => {
  it('residents get a one-time code; the guard verifies it and it stops working after check-in', async () => {
    const pass = (await post(owner, '/visitors', { name: 'Kavya', type: 'GUEST' }).expect(201)).body;
    expect(pass.passCode).toMatch(/^\d{6}$/);
    expect((await get(tenant, '/visitors').expect(200)).body[0].passCode).toBe(pass.passCode); // the household sees it
    expect((await get(guard, '/visitors').expect(200)).body[0].passCode).toBeNull(); // the gate's list doesn't

    const checked = (await post(guard, '/visitors/verify-pass', { code: `grids:pass:${pass.passCode}` }).expect(200)).body;
    expect(checked).toMatchObject({ kind: 'visitor', visitor: { id: pass.id, name: 'Kavya', flatLabel: 'Tower-A, 102' } });
    await post(owner, '/visitors/verify-pass', { code: pass.passCode }).expect(403);

    await patch(guard, `/visitors/${pass.id}/status`, { status: 'CHECKED_IN' }).expect(200);
    const again = await post(guard, '/visitors/verify-pass', { code: pass.passCode }).expect(404);
    expect(again.body.error.code).toBe('PASS_NOT_FOUND');
  });

  it("codes don't work in another society", async () => {
    const pass = (await post(owner, '/visitors', { name: 'Kavya', type: 'GUEST' })).body;
    const other = await t.prisma.society.create({ data: { name: 'Other Heights' } });
    await t.prisma.user.create({ data: { name: 'Other Guard', phone: '+919811166666' } }).then((u) =>
      t.prisma.membership.create({ data: { userId: u.id, societyId: other.id, role: 'GUARD', status: 'ACTIVE' } }),
    );
    const otherGuard = (await login(t, other.id, '+919811166666', 'GUARD')).accessToken;
    await post(otherGuard, '/visitors/verify-pass', { code: pass.passCode }).expect(404);
  });
});

describe('daily help', () => {
  it('residents add help to their flat; the gate marks attendance; the flat sees the month', async () => {
    const rekha = (await post(owner, '/daily-help', { name: 'Rekha', kind: 'Maid', phone: '93000 00001' }).expect(201)).body;
    expect(rekha.passCode).toMatch(/^\d{5}$/);
    expect(rekha).toMatchObject({ inside: false, daysThisMonth: 0, flatLabels: [] });

    // The same person working for flat 101 too: linked, not duplicated.
    const adminOwner = await asAdminOwner();
    const again = (await post(adminOwner, '/daily-help', { name: 'Rekha J', kind: 'Maid', phone: '+919300000001' }).expect(201)).body;
    expect(again.id).toBe(rekha.id);

    const staff = (await post(guard, '/visitors/verify-pass', { code: rekha.passCode }).expect(200)).body;
    expect(staff).toMatchObject({ kind: 'staff', staff: { id: rekha.id, inside: false } });
    expect(staff.staff.flatLabels.sort()).toEqual(['Tower-A, 101', 'Tower-A, 102']);

    const inside = (await post(guard, `/daily-help/${rekha.id}/attendance`).expect(200)).body;
    expect(inside).toMatchObject({ inside: true, daysThisMonth: 1, passCode: null }); // guards don't see codes
    const told = (await notificationsOf(fx.tenant.user.id)).filter((n) => n.type === 'staff');
    expect(told[0]).toMatchObject({ title: 'Daily help arrived' });

    const home = (await get(owner, '/home').expect(200)).body;
    expect(home.checklist[0]).toMatchObject({ kind: 'help', status: 'checked_in', name: 'Rekha', purpose: 'Maid' });

    expect((await post(guard, `/daily-help/${rekha.id}/attendance`).expect(200)).body.inside).toBe(false);
    const month = (await get(tenant, `/daily-help/${rekha.id}/attendance`).expect(200)).body;
    expect(month.days).toBe(1);
    expect(month.entries[0].outTime).not.toBeNull();
    await post(owner, `/daily-help/${rekha.id}/attendance`).expect(403);
  });

  it('removing help from the last flat deletes them; other flats cannot see them', async () => {
    const cook = (await post(owner, '/daily-help', { name: 'Anita', kind: 'Cook' })).body;
    const adminOwner = await asAdminOwner();
    expect((await get(adminOwner, '/daily-help').expect(200)).body).toEqual([]);
    await get(adminOwner, `/daily-help/${cook.id}/attendance`).expect(404);
    await del(adminOwner, `/daily-help/${cook.id}`).expect(404);

    await del(tenant, `/daily-help/${cook.id}`).expect(204);
    expect(await t.prisma.dailyHelp.count()).toBe(0);
  });
});

describe('SOS', () => {
  it('alerts guards, admins and the household; a double tap sends one alert; the gate resolves it', async () => {
    const alert = (await post(tenant, '/sos', { note: 'Medical' }).expect(201)).body;
    expect(alert).toMatchObject({ status: 'ACTIVE', flatLabel: 'Tower-A, 102', note: 'Medical', raisedBy: { name: 'Tara Tenant' } });
    expect((await post(tenant, '/sos').expect(201)).body.id).toBe(alert.id);

    const sent = await t.prisma.notification.findMany({ where: { type: 'sos' } });
    expect(sent.map((n) => n.userId).sort()).toEqual([fx.admin.user.id, fx.owner.user.id, fx.guard.user.id].sort());
    expect(sent[0]).toMatchObject({ title: 'SOS: emergency', body: 'Tara Tenant (Tower-A, 102) needs help now.' });

    expect((await get(guard, '/home').expect(200)).body.activeSos).toHaveLength(1);
    expect((await get(owner, '/sos').expect(200)).body.map((a: { id: string }) => a.id)).toEqual([alert.id]);
    await post(guard, '/sos').expect(403); // guards respond, they don't raise

    const adminOwner = await asAdminOwner();
    expect((await get(adminOwner, '/sos').expect(200)).body).toEqual([]); // another flat
    await post(adminOwner, `/sos/${alert.id}/resolve`).expect(404);

    const resolved = (await post(guard, `/sos/${alert.id}/resolve`).expect(200)).body;
    expect(resolved).toMatchObject({ status: 'RESOLVED', resolvedBy: 'Gopal Guard' });
    expect((await get(guard, '/home').expect(200)).body.activeSos).toEqual([]);
  });
});

describe('vehicles and parking', () => {
  it('residents register vehicles; admins assign slots; the gate finds the owner', async () => {
    const car = (await post(owner, '/vehicles', { number: 'mh-04 ab 1234', type: 'CAR', description: 'White Swift' }).expect(201)).body;
    expect(car).toMatchObject({ number: 'MH04AB1234', flatLabel: 'Tower-A, 102', parkingSlot: null });
    const dup = await post(tenant, '/vehicles', { number: 'MH04AB1234', type: 'CAR' }).expect(409);
    expect(dup.body.error.code).toBe('VEHICLE_EXISTS');
    await post(owner, '/vehicles', { number: '!!!!', type: 'CAR' }).expect(400);

    await patch(owner, `/vehicles/${car.id}`, { parkingSlot: 'B1-23' }).expect(403);
    expect((await patch(admin, `/vehicles/${car.id}`, { parkingSlot: 'B1-23' }).expect(200)).body.parkingSlot).toBe('B1-23');
    expect((await get(tenant, '/vehicles').expect(200)).body).toHaveLength(1);

    const found = (await get(guard, '/vehicles/search?q=ab 12').expect(200)).body;
    expect(found).toHaveLength(1);
    expect(found[0]).toMatchObject({ number: 'MH04AB1234', flatLabel: 'Tower-A, 102', parkingSlot: 'B1-23' });
    expect(found[0].contacts.map((c: { name: string }) => c.name).sort()).toEqual(['Omkar Owner', 'Tara Tenant']);
    await get(owner, '/vehicles/search?q=MH04').expect(403);

    const adminOwner = await asAdminOwner();
    await del(adminOwner, `/vehicles/${car.id}`).expect(404);
    await del(tenant, `/vehicles/${car.id}`).expect(204);
  });
});
