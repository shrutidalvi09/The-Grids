import { createFixture, createTestApp, login, resetDatabase, type TestApp } from './helpers.js';

let t: TestApp;
let fx: Awaited<ReturnType<typeof createFixture>>;

beforeAll(async () => {
  t = await createTestApp();
});
afterAll(async () => {
  await t.app.close();
});
beforeEach(async () => {
  await resetDatabase(t.prisma);
  t.sms.sent.length = 0;
  fx = await createFixture(t.prisma);
});

const requestOtp = (body: object) => t.http().post('/v1/auth/otp/request').send(body);
const verifyOtp = (body: object) => t.http().post('/v1/auth/otp/verify').send(body);

describe('GET /v1/societies', () => {
  it('is public and searchable, hiding inactive societies', async () => {
    await t.prisma.society.create({ data: { name: 'Closed Towers', isActive: false } });
    const all = await t.http().get('/v1/societies').expect(200);
    expect(all.body).toEqual([{ id: fx.society.id, name: 'Test Heights', city: 'Pune' }]);

    const none = await t.http().get('/v1/societies?search=zzz').expect(200);
    expect(none.body).toEqual([]);
  });
});

describe('POST /v1/auth/otp/request', () => {
  it('sends a 6-digit code to a registered number, accepting any common format', async () => {
    const res = await requestOtp({ phone: '+91 98000-00002', societyId: fx.society.id, role: 'OWNER' }).expect(200);
    expect(res.body).toMatchObject({ expiresInSeconds: 300, resendInSeconds: 30 });
    expect(res.body.devCode).toBeUndefined(); // never echoed outside dev
    expect(t.sms.lastCodeFor('+919800000002')).toMatch(/^\d{6}$/);
  });

  it.each([
    ['an unknown number', { phone: '9876543210', role: 'OWNER' }],
    ['the wrong role for a known number', { phone: '9800000002', role: 'TENANT' }],
    ['a different society', { phone: '9800000002', role: 'OWNER', societyId: 'other' }],
  ])('rejects %s as NOT_REGISTERED', async (_, body) => {
    const res = await requestOtp({ societyId: fx.society.id, ...body }).expect(404);
    expect(res.body.error.code).toBe('NOT_REGISTERED');
    expect(t.sms.sent).toHaveLength(0);
  });

  it('rejects removed members and inactive societies', async () => {
    await t.prisma.membership.update({ where: { id: fx.owner.membership.id }, data: { status: 'REMOVED' } });
    await requestOtp({ phone: fx.owner.phone, societyId: fx.society.id, role: 'OWNER' }).expect(404);

    await t.prisma.society.update({ where: { id: fx.society.id }, data: { isActive: false } });
    await requestOtp({ phone: fx.tenant.phone, societyId: fx.society.id, role: 'TENANT' }).expect(404);
  });

  it('rejects malformed numbers and unknown roles', async () => {
    const bad = await requestOtp({ phone: '12345 67890', societyId: fx.society.id, role: 'OWNER' }).expect(400);
    expect(bad.body.error.code).toBe('VALIDATION_FAILED');
    await requestOtp({ phone: '9800000002', societyId: fx.society.id, role: 'SUPERUSER' }).expect(400);
  });

  it('enforces a 30 s resend cooldown and 5 codes per hour', async () => {
    const body = { phone: fx.owner.phone, societyId: fx.society.id, role: 'OWNER' };
    await requestOtp(body).expect(200);

    const tooSoon = await requestOtp(body).expect(429);
    expect(tooSoon.body.error.code).toBe('OTP_COOLDOWN');
    expect(tooSoon.body.error.details.retryAfterSeconds).toBeGreaterThan(25);

    // Age earlier codes by a minute before each request: past the cooldown,
    // still inside the hour. Codes 2–5 succeed; the 6th hits the hourly cap.
    const ageOneMinute = () => t.prisma.$executeRaw`UPDATE OtpChallenge SET createdAt = DATE_SUB(createdAt, INTERVAL 1 MINUTE)`;
    for (let i = 0; i < 4; i++) {
      await ageOneMinute();
      await requestOtp(body).expect(200);
    }
    await ageOneMinute();
    const limited = await requestOtp(body).expect(429);
    expect(limited.body.error.code).toBe('OTP_LIMIT_REACHED');
  });
});

describe('POST /v1/auth/otp/verify', () => {
  it('signs in, returning tokens and the profile with the correct role and flat', async () => {
    const session = await login(t, fx.society.id, fx.tenant.phone, 'TENANT');
    expect(session.accessToken).toBeTruthy();
    expect(session.refreshToken).toBeTruthy();
    expect(session.me.user.name).toBe('Tara Tenant');
    expect(session.me.membership).toMatchObject({ role: 'TENANT', flatLabel: 'Tower-A, 102' });
  });

  it('activates an invited membership on first sign-in', async () => {
    const invited = await t.prisma.user.create({ data: { name: 'New Owner', phone: '+919800000009' } });
    const m = await t.prisma.membership.create({
      data: { userId: invited.id, societyId: fx.society.id, role: 'OWNER', flatId: fx.flat101.id, status: 'INVITED' },
    });
    await login(t, fx.society.id, '+919800000009', 'OWNER');
    expect((await t.prisma.membership.findUniqueOrThrow({ where: { id: m.id } })).status).toBe('ACTIVE');
  });

  it('counts down wrong attempts, then expires the code after 5', async () => {
    const { body } = await requestOtp({ phone: fx.owner.phone, societyId: fx.society.id, role: 'OWNER' });
    const right = t.sms.lastCodeFor(fx.owner.phone);
    const wrong = right === '000000' ? '111111' : '000000';

    for (const attemptsLeft of [4, 3, 2, 1]) {
      const res = await verifyOtp({ challengeId: body.challengeId, code: wrong }).expect(400);
      expect(res.body.error).toMatchObject({ code: 'OTP_INVALID', details: { attemptsLeft } });
    }
    await verifyOtp({ challengeId: body.challengeId, code: wrong }).expect(410);
    // Even the right code is useless now.
    const res = await verifyOtp({ challengeId: body.challengeId, code: right }).expect(410);
    expect(res.body.error.code).toBe('OTP_EXPIRED');
  });

  it('rejects expired and already-used codes', async () => {
    const { body } = await requestOtp({ phone: fx.owner.phone, societyId: fx.society.id, role: 'OWNER' });
    const code = t.sms.lastCodeFor(fx.owner.phone);
    await verifyOtp({ challengeId: body.challengeId, code }).expect(200);
    await verifyOtp({ challengeId: body.challengeId, code }).expect(410);

    await t.prisma.$executeRaw`UPDATE OtpChallenge SET createdAt = DATE_SUB(createdAt, INTERVAL 1 MINUTE)`;
    const again = await requestOtp({ phone: fx.owner.phone, societyId: fx.society.id, role: 'OWNER' }).expect(200);
    await t.prisma.otpChallenge.update({ where: { id: again.body.challengeId }, data: { expiresAt: new Date(Date.now() - 1000) } });
    await verifyOtp({ challengeId: again.body.challengeId, code: t.sms.lastCodeFor(fx.owner.phone) }).expect(410);
  });

  it('stores only a hash of the code', async () => {
    const { body } = await requestOtp({ phone: fx.owner.phone, societyId: fx.society.id, role: 'OWNER' });
    const stored = await t.prisma.otpChallenge.findUniqueOrThrow({ where: { id: body.challengeId } });
    expect(stored.codeHash).not.toContain(t.sms.lastCodeFor(fx.owner.phone));
    expect(stored.codeHash).toMatch(/^[0-9a-f]{64}$/);
  });
});

describe('sessions', () => {
  it('protects /me and serves it with a valid token', async () => {
    const noToken = await t.http().get('/v1/me').expect(401);
    expect(noToken.body.error.code).toBe('UNAUTHENTICATED');
    await t.http().get('/v1/me').set('authorization', 'Bearer not-a-jwt').expect(401);

    const s = await login(t, fx.society.id, fx.owner.phone, 'OWNER');
    const me = await t.http().get('/v1/me').set('authorization', `Bearer ${s.accessToken}`).expect(200);
    expect(me.body.membership.role).toBe('OWNER');
  });

  it('cuts off a removed member immediately, even with an unexpired token', async () => {
    const s = await login(t, fx.society.id, fx.owner.phone, 'OWNER');
    await t.prisma.membership.update({ where: { id: fx.owner.membership.id }, data: { status: 'REMOVED' } });
    await t.http().get('/v1/me').set('authorization', `Bearer ${s.accessToken}`).expect(401);
    await t.http().post('/v1/auth/refresh').send({ refreshToken: s.refreshToken }).expect(401);
  });

  it('rotates refresh tokens and revokes the family when an old one is replayed', async () => {
    const s = await login(t, fx.society.id, fx.owner.phone, 'OWNER');
    const r1 = await t.http().post('/v1/auth/refresh').send({ refreshToken: s.refreshToken }).expect(200);
    expect(r1.body.refreshToken).not.toBe(s.refreshToken);
    expect(r1.body.me.membership.role).toBe('OWNER');

    const replay = await t.http().post('/v1/auth/refresh').send({ refreshToken: s.refreshToken }).expect(401);
    expect(replay.body.error.code).toBe('INVALID_REFRESH_TOKEN');
    // The legitimate newer token died with the family.
    await t.http().post('/v1/auth/refresh').send({ refreshToken: r1.body.refreshToken }).expect(401);
  });

  it('logout revokes the refresh token', async () => {
    const s = await login(t, fx.society.id, fx.owner.phone, 'OWNER');
    await t.http().post('/v1/auth/logout').send({ refreshToken: s.refreshToken }).expect(204);
    await t.http().post('/v1/auth/refresh').send({ refreshToken: s.refreshToken }).expect(401);
  });

  it('lets a person switch between their own memberships only', async () => {
    const s = await login(t, fx.society.id, fx.admin.phone, 'ADMIN');
    expect(s.me.memberships.map((m) => m.role).sort()).toEqual(['ADMIN', 'OWNER']);

    const switched = await t
      .http()
      .post('/v1/auth/switch')
      .set('authorization', `Bearer ${s.accessToken}`)
      .send({ membershipId: fx.adminAsOwner.id, refreshToken: s.refreshToken })
      .expect(200);
    expect(switched.body.me.membership).toMatchObject({ role: 'OWNER', flatLabel: 'Tower-A, 101' });
    // The old session's refresh token is revoked by the switch.
    await t.http().post('/v1/auth/refresh').send({ refreshToken: s.refreshToken }).expect(401);

    // Someone else's membership is off limits.
    await t
      .http()
      .post('/v1/auth/switch')
      .set('authorization', `Bearer ${switched.body.accessToken}`)
      .send({ membershipId: fx.tenant.membership.id, refreshToken: switched.body.refreshToken })
      .expect(404);
  });
});

describe('POST /v1/memberships/invites (role guards)', () => {
  const invite = (token: string, body: object) =>
    t.http().post('/v1/memberships/invites').set('authorization', `Bearer ${token}`).send(body);

  it('forbids tenants', async () => {
    const s = await login(t, fx.society.id, fx.tenant.phone, 'TENANT');
    const res = await invite(s.accessToken, { phone: '9811111111', name: 'Test Person', role: 'TENANT' }).expect(403);
    expect(res.body.error.code).toBe('FORBIDDEN');
  });

  it('lets an owner invite a tenant for their own flat only', async () => {
    const s = await login(t, fx.society.id, fx.owner.phone, 'OWNER');
    const ok = await invite(s.accessToken, { phone: '98111 11111', name: 'Second Tenant', role: 'TENANT' }).expect(201);
    expect(ok.body).toMatchObject({ role: 'TENANT', flatId: fx.flat102.id, status: 'INVITED' });

    await invite(s.accessToken, { phone: '9822222222', name: 'Test Person', role: 'OWNER', flatId: fx.flat102.id }).expect(403);
    await invite(s.accessToken, { phone: '9833333333', name: 'Test Person', role: 'TENANT', flatId: fx.flat101.id }).expect(403);
  });

  it('lets an admin invite an owner, who can then sign in', async () => {
    const s = await login(t, fx.society.id, fx.admin.phone, 'ADMIN');
    await invite(s.accessToken, { phone: '9844444444', name: 'Neha New', role: 'OWNER' }).expect(400); // flat required
    await invite(s.accessToken, { phone: '9844444444', name: 'Neha New', role: 'OWNER', flatId: fx.flat101.id }).expect(201);

    const dup = await invite(s.accessToken, { phone: '+919844444444', name: 'Neha New', role: 'OWNER', flatId: fx.flat101.id }).expect(409);
    expect(dup.body.error.code).toBe('ALREADY_MEMBER');

    const neha = await login(t, fx.society.id, '9844444444', 'OWNER');
    expect(neha.me.membership.flatLabel).toBe('Tower-A, 101');
  });

  it('cannot reach flats in another society', async () => {
    const other = await t.prisma.society.create({ data: { name: 'Elsewhere' } });
    const tower = await t.prisma.tower.create({ data: { societyId: other.id, name: 'Test Person', floors: 1 } });
    const foreignFlat = await t.prisma.flat.create({ data: { societyId: other.id, towerId: tower.id, number: '1', floor: 1 } });
    const s = await login(t, fx.society.id, fx.admin.phone, 'ADMIN');
    await invite(s.accessToken, { phone: '9855555555', name: 'Test Person', role: 'OWNER', flatId: foreignFlat.id }).expect(404);
  });
});
