import { createFixture, createTestApp, login, resetDatabase, type TestApp } from './helpers.js';

let t: TestApp;
let fx: Awaited<ReturnType<typeof createFixture>>;
let admin: string;
let owner: string;
let tenant: string;

beforeAll(async () => {
  t = await createTestApp();
});
afterAll(async () => {
  await t.app.close();
});
beforeEach(async () => {
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

describe('managing residents', () => {
  it('admins see flats with occupants, invite, list and remove members', async () => {
    const flats = (await get(admin, '/flats').expect(200)).body;
    expect(flats.map((f: { label: string }) => f.label)).toEqual(['Tower-A, 101', 'Tower-A, 102']);
    expect(flats[1].occupants.map((o: { role: string }) => o.role)).toEqual(['OWNER', 'TENANT']);

    await post(admin, '/memberships/invites', { phone: '98111 22222', name: 'Neha Shah', role: 'OWNER', flatId: fx.flat101.id }).expect(201);
    const members = (await get(admin, '/memberships').expect(200)).body;
    const neha = members.find((m: { name: string }) => m.name === 'Neha Shah');
    expect(neha).toMatchObject({ role: 'OWNER', status: 'INVITED', flatLabel: 'Tower-A, 101', phone: '+919811122222' });
    expect(members[0].role).toBe('ADMIN'); // admins listed first

    await del(admin, `/memberships/${neha.membershipId}`).expect(204);
    expect((await get(admin, '/memberships').expect(200)).body.some((m: { name: string }) => m.name === 'Neha Shah')).toBe(false);
  });

  it('removing a member signs them out; the last admin cannot be removed', async () => {
    const members = (await get(admin, '/memberships').expect(200)).body;
    const tenantMembership = members.find((m: { role: string }) => m.role === 'TENANT');
    await del(admin, `/memberships/${tenantMembership.membershipId}`).expect(204);
    await get(tenant, '/me').expect(401);

    const adminMembership = members.find((m: { role: string }) => m.role === 'ADMIN');
    const res = await del(admin, `/memberships/${adminMembership.membershipId}`).expect(409);
    expect(res.body.error.code).toBe('LAST_ADMIN_REMOVE');
  });
});

describe('pre-approved visitors', () => {
  it('residents add visitors for their own flat only; the gate checks them in and the flat is told', async () => {
    const created = (
      await post(owner, '/visitors', {
        name: 'Rekha',
        purpose: 'Maid',
        type: 'SERVICE',
        phone: '98765 43210',
        flatId: fx.flat101.id,
      }).expect(201)
    ).body;
    // flatId is ignored for residents: it's always their own flat.
    expect(created).toMatchObject({
      name: 'Rekha',
      status: 'EXPECTED',
      flatLabel: 'Tower-A, 102',
      phone: '+919876543210',
      preApproved: true,
    });
    expect((await get(tenant, '/visitors').expect(200)).body.map((v: { id: string }) => v.id)).toContain(created.id);

    await patch(owner, `/visitors/${created.id}/status`, { status: 'CHECKED_IN' }).expect(403);
    const inside = (await patch(admin, `/visitors/${created.id}/status`, { status: 'CHECKED_IN' }).expect(200)).body;
    expect(inside.status).toBe('CHECKED_IN');
    expect(inside.inTime).toBeTruthy();

    const notes = await t.prisma.notification.findMany({ where: { type: 'visitor' } });
    expect(notes.map((n) => n.userId).sort()).toEqual([fx.owner.user.id, fx.tenant.user.id].sort());
    expect(notes[0].body).toBe('Rekha has checked in at the gate.');

    const out = (await patch(admin, `/visitors/${created.id}/status`, { status: 'CHECKED_OUT' }).expect(200)).body;
    expect(out.outTime).toBeTruthy();
    // Can't cancel once they've arrived.
    expect((await del(owner, `/visitors/${created.id}`).expect(409)).body.error.code).toBe('VISITOR_ARRIVED');
  });

  it('parcels held at the gate notify the flat; expected visitors can be cancelled', async () => {
    const parcel = (await post(admin, '/visitors', { name: 'Amazon', type: 'DELIVERY', flatId: fx.flat102.id }).expect(201)).body;
    await patch(admin, `/visitors/${parcel.id}/status`, { status: 'HELD_AT_GATE' }).expect(200);
    expect(await t.prisma.notification.count({ where: { type: 'parcel' } })).toBe(2);

    const guest = (await post(tenant, '/visitors', { name: 'Kabir', type: 'GUEST' }).expect(201)).body;
    await del(owner, `/visitors/${guest.id}`).expect(204); // same flat
    await post(admin, '/visitors', { name: 'No flat', type: 'GUEST' }).expect(400);
    await post(owner, '/visitors', { name: 'Bad phone', type: 'GUEST', phone: '123' }).expect(400);
  });
});

describe('events', () => {
  it('admins create, edit and delete events; members are notified in their language', async () => {
    await patch(tenant, '/me', { language: 'hi' }).expect(200);
    const startsAt = new Date(Date.now() + 2 * 86_400_000);
    const body = { title: 'Diwali Mela', location: 'Clubhouse Lawn', startsAt };
    await post(owner, '/events', body).expect(403);
    await post(admin, '/events', { ...body, endsAt: new Date(startsAt.getTime() - 1000) }).expect(400);

    const event = (await post(admin, '/events', body).expect(201)).body;
    expect((await get(owner, '/events').expect(200)).body.map((e: { title: string }) => e.title)).toContain('Diwali Mela');

    const notes = await t.prisma.notification.findMany({ where: { type: 'event' } });
    expect(notes).toHaveLength(2); // owner + tenant, not the admin who posted it
    expect(notes.find((n) => n.userId === fx.owner.user.id)!.title).toBe('New event');
    expect(notes.find((n) => n.userId === fx.tenant.user.id)!.title).toBe('नया कार्यक्रम');

    const edited = (await patch(admin, `/events/${event.id}`, { ...body, title: 'Diwali Mela 2026' }).expect(200)).body;
    expect(edited.title).toBe('Diwali Mela 2026');
    await del(admin, `/events/${event.id}`).expect(204);
    expect((await get(owner, '/events').expect(200)).body).toEqual([]);
  });
});

describe('service ratings', () => {
  it('residents rate once (re-rating replaces it) and see the average', async () => {
    const service = (
      await post(admin, '/services', { category: 'Maid', name: 'Rekha', phone: '9876543210', rating: 3 }).expect(201)
    ).body;
    expect(service).toMatchObject({ rating: 3, ratingCount: 0, myRating: null }); // admin's starting rating

    await put(owner, `/services/${service.id}/rating`, { stars: 5 }).expect(200);
    await put(owner, `/services/${service.id}/rating`, { stars: 4 }).expect(200); // changed their mind
    const rated = (await put(tenant, `/services/${service.id}/rating`, { stars: 5 }).expect(200)).body;
    expect(rated).toMatchObject({ rating: 4.5, ratingCount: 2, myRating: 5 });

    const [listed] = (await get(owner, '/services').expect(200)).body;
    expect(listed).toMatchObject({ rating: 4.5, myRating: 4 });
    await put(owner, `/services/${service.id}/rating`, { stars: 6 }).expect(400);
  });
});
