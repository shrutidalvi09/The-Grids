/**
 * The API's access rules, as an executable table (the equivalent of
 * Firestore security rules). Every route must be listed here, so a new
 * endpoint can't ship without deciding who may call it.
 */
import { createFixture, createTestApp, login, resetDatabase, type TestApp } from './helpers.js';

type Who = 'public' | 'signedIn' | 'admin' | 'owner' | 'tenant' | 'resident' | 'adminOrOwner';
type Role = 'ADMIN' | 'OWNER' | 'TENANT';

const allowed: Record<Who, Role[] | null> = {
  public: null,
  signedIn: ['ADMIN', 'OWNER', 'TENANT'],
  admin: ['ADMIN'],
  owner: ['OWNER'],
  tenant: ['TENANT'],
  resident: ['OWNER', 'TENANT'],
  adminOrOwner: ['ADMIN', 'OWNER'],
};

/** METHOD path → who may call it. Ownership/flat/society checks are tested separately. */
const RULES: Record<string, Who> = {
  'GET /health': 'public',
  'GET /v1/societies': 'public',
  'POST /v1/auth/otp/request': 'public',
  'POST /v1/auth/otp/verify': 'public',
  'POST /v1/auth/refresh': 'public',
  'POST /v1/auth/logout': 'public',
  'POST /v1/payments/webhook': 'public', // Razorpay signature instead of a token
  'POST /v1/auth/switch': 'signedIn',
  'POST /v1/memberships/invites': 'adminOrOwner',
  'GET /v1/me': 'signedIn',
  'PATCH /v1/me': 'signedIn',
  'DELETE /v1/me': 'signedIn',
  'GET /v1/me/preferences': 'signedIn',
  'PUT /v1/me/preferences': 'signedIn',
  'GET /v1/notifications': 'signedIn',
  'GET /v1/notifications/unread-count': 'signedIn',
  'POST /v1/notifications/:id/read': 'signedIn',
  'POST /v1/notifications/read-all': 'signedIn',
  'PUT /v1/devices': 'signedIn',
  'DELETE /v1/devices/:token': 'signedIn',
  'GET /v1/home': 'signedIn',
  'GET /v1/notices': 'signedIn',
  'POST /v1/notices': 'admin',
  'PATCH /v1/notices/:id': 'admin',
  'DELETE /v1/notices/:id': 'admin',
  'GET /v1/visitors': 'signedIn',
  'GET /v1/neighbours': 'signedIn',
  'GET /v1/events': 'signedIn',
  'GET /v1/complaints': 'signedIn',
  'POST /v1/complaints': 'signedIn',
  'PATCH /v1/complaints/:id/status': 'admin',
  'GET /v1/facilities': 'signedIn',
  'POST /v1/facilities': 'admin',
  'PATCH /v1/facilities/:id': 'admin',
  'GET /v1/facilities/:id/slots': 'signedIn',
  'POST /v1/facilities/:id/bookings': 'signedIn',
  'GET /v1/bookings/mine': 'signedIn',
  'DELETE /v1/bookings/:id': 'signedIn',
  'POST /v1/uploads': 'signedIn',
  'GET /v1/dues/mine': 'signedIn',
  'GET /v1/maintenance/config': 'signedIn',
  'PUT /v1/maintenance/config': 'admin',
  'POST /v1/maintenance/dues/generate': 'admin',
  'GET /v1/maintenance/summary': 'admin',
  'GET /v1/maintenance/defaulters': 'admin',
  'POST /v1/maintenance/defaulters/:flatId/remind': 'admin',
  'GET /v1/society-bills': 'admin',
  'POST /v1/society-bills': 'admin',
  'PATCH /v1/society-bills/:id/paid': 'admin',
  'POST /v1/payments/orders': 'resident',
  'POST /v1/payments/verify': 'signedIn', // only the payer's own payment verifies
  'POST /v1/payments/:id/simulate': 'signedIn', // dev gateway only; payer only
  'GET /v1/payments/mine': 'signedIn',
  'GET /v1/payments/:id': 'signedIn',
  'GET /v1/payments/:id/receipt': 'signedIn',
  'GET /v1/polls': 'signedIn',
  'GET /v1/polls/:id': 'signedIn',
  'POST /v1/polls': 'admin',
  'POST /v1/polls/:id/votes': 'signedIn',
  'POST /v1/polls/:id/close': 'admin',
  'DELETE /v1/polls/:id': 'admin',
  'GET /v1/communities': 'signedIn',
  'GET /v1/communities/candidates': 'admin',
  'GET /v1/communities/:id': 'signedIn',
  'POST /v1/communities': 'admin',
  'PATCH /v1/communities/:id': 'admin',
  'DELETE /v1/communities/:id': 'admin',
  'POST /v1/communities/:id/join': 'signedIn',
  'POST /v1/communities/:id/leave': 'signedIn',
  'POST /v1/communities/:id/announcements': 'admin',
  'PATCH /v1/announcements/:id': 'admin',
  'DELETE /v1/announcements/:id': 'admin',
  'GET /v1/household': 'resident',
  'POST /v1/household': 'resident',
  'PATCH /v1/household/:id': 'resident',
  'DELETE /v1/household/:id': 'resident',
  'GET /v1/society': 'signedIn',
  'GET /v1/services': 'signedIn',
  'POST /v1/services': 'admin',
  'DELETE /v1/services/:id': 'admin',
  'GET /v1/tenancy': 'resident',
  'POST /v1/tenancy': 'owner',
  'PATCH /v1/tenancy/:id': 'owner',
  'POST /v1/tenancy/:id/end': 'owner',
};

let t: TestApp;
let fx: Awaited<ReturnType<typeof createFixture>>;
const tokens = {} as Record<Role, string>;

beforeAll(async () => {
  t = await createTestApp();
  await resetDatabase(t.prisma);
  fx = await createFixture(t.prisma);
  tokens.ADMIN = (await login(t, fx.society.id, fx.admin.phone, 'ADMIN')).accessToken;
  tokens.OWNER = (await login(t, fx.society.id, fx.owner.phone, 'OWNER')).accessToken;
  tokens.TENANT = (await login(t, fx.society.id, fx.tenant.phone, 'TENANT')).accessToken;
});
afterAll(async () => {
  await t.app.close();
});

function registeredRoutes(): string[] {
  const express = t.app.getHttpAdapter().getInstance();
  const stack: { route?: { path: string; methods: Record<string, boolean> } }[] = (express.router ?? express._router).stack;
  return stack
    .filter((layer) => layer.route && Object.keys(layer.route.methods).length === 1)
    .map((layer) => `${Object.keys(layer.route!.methods)[0].toUpperCase()} ${layer.route!.path}`);
}

function send(route: string, token?: string) {
  const [method, path] = route.split(' ');
  const url = path.replace(/:\w+/g, 'some-id');
  const req = t.http()[method.toLowerCase() as 'get' | 'post' | 'put' | 'patch' | 'delete'](url);
  return token ? req.set('authorization', `Bearer ${token}`) : req;
}

describe('access rules', () => {
  it('cover every route the API serves', () => {
    const routes = registeredRoutes();
    expect(routes.filter((r) => !(r in RULES))).toEqual([]); // classify new endpoints in RULES
    expect(Object.keys(RULES).filter((r) => !routes.includes(r))).toEqual([]); // no stale rules
  });

  it.each(Object.entries(RULES).filter(([, who]) => who !== 'public'))(
    '%s needs a valid token',
    async (route) => {
      expect((await send(route)).status).toBe(401);
      expect((await send(route, 'not-a-jwt')).status).toBe(401);
    },
  );

  it.each(
    Object.entries(RULES).flatMap(([route, who]) => {
      const roles = allowed[who];
      return roles ? (['ADMIN', 'OWNER', 'TENANT'] as Role[]).filter((r) => !roles.includes(r)).map((r) => [route, r]) : [];
    }),
  )('%s refuses %s', async (route, role) => {
    const res = await send(route, tokens[role as Role]);
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('FORBIDDEN');
  });
});

describe('society isolation', () => {
  it("another society's admin can't see or change this society's records", async () => {
    const admin = tokens.ADMIN;
    const owner = tokens.OWNER;
    const post = (token: string, path: string, body: object = {}) =>
      t.http().post(`/v1${path}`).set('authorization', `Bearer ${token}`).send(body);

    // Records in society A.
    const notice = (await post(admin, '/notices', { title: 'Lift maintenance', body: 'Lift B off on Sunday.' }).expect(201)).body;
    const complaint = (await post(owner, '/complaints', { title: 'Leaking tap', description: 'Kitchen' }).expect(201)).body;
    const poll = (await post(admin, '/polls', { question: 'Which day for the meeting?', options: ['Sat', 'Sun'] }).expect(201)).body;
    const club = (await post(admin, '/communities', { name: 'Yoga Club', memberIds: [] }).expect(201)).body;
    const service = (await post(admin, '/services', { category: 'Maid', name: 'Rekha', phone: '9876543210' }).expect(201)).body;
    const member = (await post(owner, '/household', { name: 'Pragati', relation: 'Mother' }).expect(201)).body;

    // Society B with its own admin and owner.
    const other = await t.prisma.society.create({ data: { name: 'Other Heights', city: 'Pune' } });
    const tower = await t.prisma.tower.create({ data: { societyId: other.id, name: 'Tower-Z', floors: 1 } });
    const flat = await t.prisma.flat.create({ data: { societyId: other.id, towerId: tower.id, number: '1', floor: 1 } });
    const intruder = await t.prisma.user.create({ data: { name: 'Ivan Intruder', phone: '+919822222222' } });
    await t.prisma.membership.createMany({
      data: [
        { userId: intruder.id, societyId: other.id, role: 'ADMIN', status: 'ACTIVE' },
        { userId: intruder.id, societyId: other.id, role: 'OWNER', flatId: flat.id, status: 'ACTIVE' },
      ],
    });
    const login2 = await login(t, other.id, '+919822222222', 'ADMIN');
    const evil = login2.accessToken;
    const as = (method: 'get' | 'post' | 'patch' | 'delete', path: string, body: object = {}) =>
      t.http()[method](`/v1${path}`).set('authorization', `Bearer ${evil}`).send(body);

    // Nothing from A shows up in B's lists…
    for (const path of ['/notices', '/complaints', '/polls', '/communities', '/services', '/facilities']) {
      expect((await as('get', path).expect(200)).body, path).toEqual([]);
    }
    const neighbours = (await as('get', '/neighbours').expect(200)).body as { towerName: string }[];
    expect(neighbours.map((n) => n.towerName)).toEqual(['Tower-Z']); // only their own society
    expect((await as('get', '/maintenance/summary').expect(200)).body.pendingFlats).toBe(0);

    // …and A's records can't be read or changed by id.
    const attempts: [string, () => PromiseLike<{ status: number }>][] = [
      ['edit notice', () => as('patch', `/notices/${notice.id}`, { title: 'Hacked notice', body: 'x' })],
      ['delete notice', () => as('delete', `/notices/${notice.id}`)],
      ['complaint status', () => as('patch', `/complaints/${complaint.id}/status`, { status: 'RESOLVED' })],
      ['read poll', () => as('get', `/polls/${poll.id}`)],
      ['vote', () => as('post', `/polls/${poll.id}/votes`, { optionId: poll.options[0].id })],
      ['close poll', () => as('post', `/polls/${poll.id}/close`)],
      ['read club', () => as('get', `/communities/${club.id}`)],
      ['join club', () => as('post', `/communities/${club.id}/join`)],
      ['announce', () => as('post', `/communities/${club.id}/announcements`, { title: 'Hacked', body: 'x' })],
      ['delete service', () => as('delete', `/services/${service.id}`)],
      ['remind flat', () => as('post', `/maintenance/defaulters/${fx.flat102.id}/remind`)],
    ];
    for (const [label, attempt] of attempts) expect((await attempt()).status, label).toBe(404);

    // Household is per flat: B's owner of flat 1 can't touch A's flat-102 member.
    const switched = await t
      .http()
      .post('/v1/auth/switch')
      .set('authorization', `Bearer ${evil}`)
      .send({ membershipId: (await t.prisma.membership.findFirstOrThrow({ where: { userId: intruder.id, role: 'OWNER' } })).id, refreshToken: login2.refreshToken })
      .expect(200);
    const evilOwner = switched.body.accessToken;
    await t.http().delete(`/v1/household/${member.id}`).set('authorization', `Bearer ${evilOwner}`).expect(404);
    expect((await t.http().get('/v1/household').set('authorization', `Bearer ${evilOwner}`).expect(200)).body).toEqual([]);

    // Unchanged in A.
    expect(await t.prisma.notice.findUniqueOrThrow({ where: { id: notice.id } })).toMatchObject({ title: 'Lift maintenance' });
    expect(await t.prisma.complaint.findUniqueOrThrow({ where: { id: complaint.id } })).toMatchObject({ status: 'OPEN' });
    expect(await t.prisma.pollVote.count()).toBe(0);
  });
});
