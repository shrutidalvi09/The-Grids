import { addDays, localDate, zonedToUtc } from '../src/common/zoned-time.js';
import { WeatherService } from '../src/weather/weather.service.js';
import { createFixture, createTestApp, login, resetDatabase, type TestApp } from './helpers.js';

let t: TestApp;
let fx: Awaited<ReturnType<typeof createFixture>>;
let admin: string;
let owner: string;
let tenant: string;

const TZ = 'Asia/Kolkata';
const tomorrow = () => addDays(localDate(new Date(), TZ), 1);

beforeAll(async () => {
  t = await createTestApp();
  // Deterministic weather instead of calling Open-Meteo.
  t.app.get(WeatherService).fetch = async () => ({
    ok: true,
    json: async () => ({ current: { temperature_2m: 29.6, weather_code: 2 } }),
  });
});
afterAll(async () => {
  await t.app.close();
});
beforeEach(async () => {
  await resetDatabase(t.prisma);
  fx = await createFixture(t.prisma);
  await t.prisma.society.update({ where: { id: fx.society.id }, data: { latitude: 18.52, longitude: 73.85 } });
  admin = (await login(t, fx.society.id, fx.admin.phone, 'ADMIN')).accessToken;
  owner = (await login(t, fx.society.id, fx.owner.phone, 'OWNER')).accessToken;
  tenant = (await login(t, fx.society.id, fx.tenant.phone, 'TENANT')).accessToken;
});

const get = (token: string, path: string) => t.http().get(`/v1${path}`).set('authorization', `Bearer ${token}`);
const post = (token: string, path: string, body: object) =>
  t.http().post(`/v1${path}`).set('authorization', `Bearer ${token}`).send(body);

describe('GET /v1/home', () => {
  it('gives admins society stats, recent complaints, events and weather', async () => {
    await t.prisma.due.create({
      data: {
        societyId: fx.society.id,
        flatId: fx.flat102.id,
        type: 'MAINTENANCE',
        period: '2026-10',
        amountPaise: 250000,
        breakdown: [],
        dueDate: new Date(),
      },
    });
    await post(owner, '/complaints', { title: 'Lift stuck', description: 'Stuck on floor 2' }).expect(201);
    await t.prisma.event.create({
      data: { societyId: fx.society.id, title: 'Yoga', location: 'Terrace', startsAt: new Date(Date.now() + 86_400_000) },
    });

    const res = await get(admin, '/home').expect(200);
    // 2 owner memberships: Asha (also admin) for 101 and Omkar for 102.
    expect(res.body.stats).toEqual({ towers: 1, flats: 2, owners: 2, tenants: 1, pendingDues: 1 });
    expect(res.body.recentComplaints[0]).toMatchObject({ title: 'Lift stuck', status: 'OPEN', flatLabel: 'Tower-A, 102' });
    expect(res.body.upcomingEvents[0].title).toBe('Yoga');
    expect(res.body.weather).toEqual({ temperatureC: 30, code: 2 });
    expect(res.body.checklist).toBeUndefined();
  });

  it("builds the resident checklist from today's visitors and the right kind of due", async () => {
    await t.prisma.visitor.createMany({
      data: [
        { societyId: fx.society.id, flatId: fx.flat102.id, name: 'Rekha', purpose: 'Maid', type: 'SERVICE', status: 'EXPECTED' },
        { societyId: fx.society.id, flatId: fx.flat102.id, name: 'Amazon', type: 'DELIVERY', status: 'HELD_AT_GATE', inTime: new Date() },
        { societyId: fx.society.id, flatId: fx.flat101.id, name: 'Other flat', type: 'SERVICE', status: 'CHECKED_IN', inTime: new Date() },
      ],
    });
    await t.prisma.due.create({
      data: {
        societyId: fx.society.id,
        flatId: fx.flat102.id,
        type: 'RENT',
        period: '2026-10',
        amountPaise: 1500000,
        breakdown: [],
        dueDate: new Date(Date.now() - 86_400_000),
      },
    });

    const ownerHome = await get(owner, '/home').expect(200);
    expect(ownerHome.body.stats).toBeUndefined();
    expect(ownerHome.body.checklist).toEqual([
      expect.objectContaining({ kind: 'help', status: 'expected', name: 'Rekha' }),
      expect.objectContaining({ kind: 'parcel', from: 'Amazon' }),
      { kind: 'bills_clear' }, // the pending due is rent, which the tenant pays
    ]);

    const tenantHome = await get(tenant, '/home').expect(200);
    expect(tenantHome.body.checklist.at(-1)).toMatchObject({
      kind: 'bill',
      status: 'overdue',
      dueType: 'RENT',
      amountPaise: 1500000,
    });
  });

  it('shows the latest unexpired alert and hides the weather when it is unavailable', async () => {
    await t.prisma.notice.createMany({
      data: [
        { societyId: fx.society.id, title: 'Old alert', body: 'x', isAlert: true, expiresAt: new Date(Date.now() - 1000), createdById: fx.admin.user.id },
        { societyId: fx.society.id, title: 'Water off 2–4 PM', body: 'y', isAlert: true, createdById: fx.admin.user.id },
      ],
    });
    await t.prisma.society.update({ where: { id: fx.society.id }, data: { latitude: null } });
    const res = await get(owner, '/home').expect(200);
    expect(res.body.alert.title).toBe('Water off 2–4 PM');
    expect(res.body.weather).toBeNull();
  });
});

describe('notices', () => {
  it('only admins can post; alerts get a default expiry', async () => {
    await post(owner, '/notices', { title: 'Hello', body: 'World' }).expect(403);
    const created = await post(admin, '/notices', { title: 'Lift maintenance', body: 'Use stairs', isAlert: true }).expect(201);
    expect(new Date(created.body.expiresAt).getTime()).toBeGreaterThan(Date.now() + 23 * 3_600_000);

    await t.http().patch(`/v1/notices/${created.body.id}`).set('authorization', `Bearer ${admin}`)
      .send({ title: 'Lift maintenance (updated)', body: 'Use stairs' }).expect(200);
    await t.http().delete(`/v1/notices/${created.body.id}`).set('authorization', `Bearer ${owner}`).expect(403);
    await t.http().delete(`/v1/notices/${created.body.id}`).set('authorization', `Bearer ${admin}`).expect(204);
  });

  it("residents see society-wide notices and their own tower's, not other towers'", async () => {
    const otherTower = await t.prisma.tower.create({ data: { societyId: fx.society.id, name: 'Tower-B', floors: 2 } });
    for (const [title, towerId] of [['Everyone', null], ['Tower-A only', fx.tower.id], ['Tower-B only', otherTower.id]] as const) {
      await post(admin, '/notices', { title, body: 'b', towerId }).expect(201);
    }
    const residentTitles = (await get(owner, '/notices').expect(200)).body.map((n: { title: string }) => n.title).sort();
    expect(residentTitles).toEqual(['Everyone', 'Tower-A only']);
    expect((await get(admin, '/notices').expect(200)).body).toHaveLength(3);
  });
});

describe('visitors and neighbours', () => {
  it("residents see only their flat's visitors; admins see everyone's", async () => {
    await t.prisma.visitor.createMany({
      data: [
        { societyId: fx.society.id, flatId: fx.flat102.id, name: 'Mine', type: 'GUEST', status: 'CHECKED_IN', inTime: new Date() },
        { societyId: fx.society.id, flatId: fx.flat101.id, name: 'Theirs', type: 'GUEST', status: 'CHECKED_IN', inTime: new Date() },
      ],
    });
    expect((await get(tenant, '/visitors').expect(200)).body.map((v: { name: string }) => v.name)).toEqual(['Mine']);
    expect((await get(admin, '/visitors').expect(200)).body).toHaveLength(2);
  });

  it('lists occupied flats grouped by tower, with names but no phone numbers', async () => {
    const res = await get(tenant, '/neighbours').expect(200);
    expect(res.body).toEqual([
      {
        towerName: 'Tower-A',
        flats: [
          { flatId: fx.flat101.id, number: '101', residents: [{ name: 'Asha Admin', role: 'OWNER', photoUrl: null }] },
          {
            flatId: fx.flat102.id,
            number: '102',
            residents: [
              { name: 'Omkar Owner', role: 'OWNER', photoUrl: null },
              { name: 'Tara Tenant', role: 'TENANT', photoUrl: null },
            ],
          },
        ],
      },
    ]);
    expect(JSON.stringify(res.body)).not.toContain('+91');
  });
});

describe('complaints', () => {
  it('residents post for their flat and see only their flat; admins manage status', async () => {
    const mine = await post(tenant, '/complaints', { title: 'Leaking tap', category: 'Plumbing', description: 'Kitchen tap leaks' }).expect(201);
    expect(mine.body).toMatchObject({ flatLabel: 'Tower-A, 102', raisedBy: 'Tara Tenant', status: 'OPEN' });
    await t.prisma.complaint.create({
      data: { societyId: fx.society.id, flatId: fx.flat101.id, raisedById: fx.admin.user.id, title: 'Other', description: 'Other flat' },
    });

    // The owner of the same flat sees the tenant's complaint, not flat 101's.
    expect((await get(owner, '/complaints').expect(200)).body.map((c: { title: string }) => c.title)).toEqual(['Leaking tap']);
    expect((await get(admin, '/complaints').expect(200)).body).toHaveLength(2);

    await t.http().patch(`/v1/complaints/${mine.body.id}/status`).set('authorization', `Bearer ${tenant}`)
      .send({ status: 'RESOLVED' }).expect(403);
    const resolved = await t.http().patch(`/v1/complaints/${mine.body.id}/status`).set('authorization', `Bearer ${admin}`)
      .send({ status: 'RESOLVED' }).expect(200);
    expect(resolved.body.resolvedAt).toBeTruthy();
    expect((await get(admin, '/complaints?status=OPEN').expect(200)).body).toHaveLength(1);
  });
});

describe('facilities and bookings', () => {
  let courtId: string;
  const tenAm = () => zonedToUtc(tomorrow(), '10:00', TZ).toISOString();

  beforeEach(async () => {
    const court = await post(admin, '/facilities', {
      name: 'Badminton Court',
      openTime: '06:00',
      closeTime: '22:00',
      maxDurationMins: 60,
      capacity: 1,
    }).expect(201);
    courtId = court.body.id;
  });

  it('only admins manage facilities, and hours must fit a booking', async () => {
    await post(owner, '/facilities', { name: 'Gym', openTime: '06:00', closeTime: '22:00', maxDurationMins: 60 }).expect(403);
    const bad = await post(admin, '/facilities', { name: 'Gym', openTime: '06:00', closeTime: '06:30', maxDurationMins: 60 }).expect(400);
    expect(bad.body.error.code).toBe('VALIDATION_FAILED');
    await post(admin, '/facilities', { name: 'Gym', openTime: '25:00', closeTime: '22:00', maxDurationMins: 60 }).expect(400);
  });

  it('lists facilities with a live status', async () => {
    const [court] = (await get(tenant, '/facilities').expect(200)).body;
    expect(court.name).toBe('Badminton Court');
    expect(['open', 'full', 'closed']).toContain(court.status.status);
  });

  it('books a slot, blocks double-booking and full slots, and frees it on cancel', async () => {
    const booked = await post(owner, `/facilities/${courtId}/bookings`, { startsAt: tenAm() }).expect(201);
    expect(booked.body.facilityName).toBe('Badminton Court');

    const again = await post(owner, `/facilities/${courtId}/bookings`, { startsAt: tenAm() }).expect(409);
    expect(again.body.error.code).toBe('ALREADY_BOOKED');
    const full = await post(tenant, `/facilities/${courtId}/bookings`, { startsAt: tenAm() }).expect(409);
    expect(full.body.error.code).toBe('SLOT_FULL');

    const slots = (await get(tenant, `/facilities/${courtId}/slots?date=${tomorrow()}`).expect(200)).body;
    expect(slots).toHaveLength(16); // 06:00–22:00 in 1-hour slots
    expect(slots.find((s: { startsAt: string }) => s.startsAt === tenAm())).toMatchObject({ available: false, remaining: 0, mine: false });

    expect((await get(owner, '/bookings/mine').expect(200)).body).toHaveLength(1);
    await t.http().delete(`/v1/bookings/${booked.body.id}`).set('authorization', `Bearer ${tenant}`).expect(404); // not theirs
    await t.http().delete(`/v1/bookings/${booked.body.id}`).set('authorization', `Bearer ${owner}`).expect(204);
    await post(tenant, `/facilities/${courtId}/bookings`, { startsAt: tenAm() }).expect(201);
  });

  it('rejects starts that are not slot boundaries, in the past, or beyond 7 days', async () => {
    const misaligned = zonedToUtc(tomorrow(), '10:15', TZ).toISOString();
    expect((await post(owner, `/facilities/${courtId}/bookings`, { startsAt: misaligned }).expect(400)).body.error.code).toBe('SLOT_INVALID');
    const yesterday = zonedToUtc(addDays(localDate(new Date(), TZ), -1), '10:00', TZ).toISOString();
    await post(owner, `/facilities/${courtId}/bookings`, { startsAt: yesterday }).expect(400);
    const far = zonedToUtc(addDays(localDate(new Date(), TZ), 8), '10:00', TZ).toISOString();
    await post(owner, `/facilities/${courtId}/bookings`, { startsAt: far }).expect(400);
    await get(owner, `/facilities/${courtId}/slots?date=${addDays(localDate(new Date(), TZ), 9)}`).expect(400);
  });

  it('gives the last place to exactly one of two simultaneous requests', async () => {
    const results = await Promise.all([
      post(owner, `/facilities/${courtId}/bookings`, { startsAt: tenAm() }),
      post(tenant, `/facilities/${courtId}/bookings`, { startsAt: tenAm() }),
    ]);
    expect(results.map((r) => r.status).sort((a, b) => a - b)).toEqual([201, 409]);
  });
});

describe('POST /v1/uploads', () => {
  const png = Buffer.from(
    '89504e470d0a1a0a0000000d4948445200000001000000010806000000' + '1f15c4890000000d4944415478da63f8ffff3f0005fe02fea7d6a4c50000000049454e44ae426082',
    'hex',
  );

  it('stores real images and serves them back', async () => {
    const res = await t.http().post('/v1/uploads').set('authorization', `Bearer ${admin}`)
      .attach('file', png, { filename: 'photo.png', contentType: 'image/png' }).expect(201);
    expect(res.body.url).toMatch(/^\/uploads\/[0-9a-f]{32}\.png$/);
    const served = await t.http().get(res.body.url).expect(200);
    expect(Buffer.compare(served.body as Buffer, png)).toBe(0);
  });

  it('rejects files that are not images, whatever they claim to be', async () => {
    const res = await t.http().post('/v1/uploads').set('authorization', `Bearer ${admin}`)
      .attach('file', Buffer.from('<?php echo 1; ?>'), { filename: 'evil.png', contentType: 'image/png' }).expect(400);
    expect(res.body.error.code).toBe('UNSUPPORTED_FILE');
  });

  it('requires sign-in', async () => {
    await t.http().post('/v1/uploads').attach('file', png, 'photo.png').expect(401);
  });
});
