import { createFixture, createTestApp, login, resetDatabase, type TestApp } from './helpers.js';

let t: TestApp;
let fx: Awaited<ReturnType<typeof createFixture>>;
let admin: string;
let adminRefresh: string;
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
  // One sign-in per phone: a second within 30 s would hit the OTP cooldown.
  const asha = await login(t, fx.society.id, fx.admin.phone, 'ADMIN');
  admin = asha.accessToken;
  adminRefresh = asha.refreshToken;
  owner = (await login(t, fx.society.id, fx.owner.phone, 'OWNER')).accessToken;
  tenant = (await login(t, fx.society.id, fx.tenant.phone, 'TENANT')).accessToken;
});

const auth = (token: string) => ({ authorization: `Bearer ${token}` });
const get = (token: string, path: string) => t.http().get(`/v1${path}`).set(auth(token));
const post = (token: string, path: string, body: object = {}) => t.http().post(`/v1${path}`).set(auth(token)).send(body);
const patch = (token: string, path: string, body: object) => t.http().patch(`/v1${path}`).set(auth(token)).send(body);
const del = (token: string, path: string) => t.http().delete(`/v1${path}`).set(auth(token));

const sundayPoll = { question: 'Which activity for Sunday?', options: ['Movie Night', 'Karaoke', 'Sports Tournament'] };

describe('polls', () => {
  it('only admins create polls, and every active member is notified', async () => {
    await post(owner, '/polls', sundayPoll).expect(403);
    const res = await post(admin, '/polls', sundayPoll).expect(201);
    expect(res.body).toMatchObject({ question: sundayPoll.question, isOpen: true, totalVotes: 0, myOptionId: null });
    expect(res.body.options.map((o: { label: string }) => o.label)).toEqual(sundayPoll.options);

    const notified = await t.prisma.notification.findMany({ where: { type: 'poll' } });
    // Owner and tenant; the admin who posted it isn't notified.
    expect(notified.map((n) => n.userId).sort()).toEqual([fx.owner.user.id, fx.tenant.user.id].sort());
  });

  it('rejects duplicate or too few options and past closing times', async () => {
    await post(admin, '/polls', { question: 'Pick one please', options: ['Yes'] }).expect(400);
    await post(admin, '/polls', { question: 'Pick one please', options: ['Yes', ' yes '] }).expect(400);
    await post(admin, '/polls', { ...sundayPoll, closesAt: new Date(Date.now() - 60_000) }).expect(400);
  });

  it('allows one vote per person and hides counts until you vote', async () => {
    const poll = (await post(admin, '/polls', sundayPoll).expect(201)).body;
    const [movie, karaoke] = poll.options;

    // Before voting: total only, no per-option counts. Admins always see counts.
    await post(tenant, `/polls/${poll.id}/votes`, { optionId: movie.id }).expect(201);
    const before = (await get(owner, `/polls/${poll.id}`).expect(200)).body;
    expect(before).toMatchObject({ totalVotes: 1, resultsVisible: false, myOptionId: null });
    expect(before.options[0].votes).toBeNull();
    expect((await get(admin, `/polls/${poll.id}`).expect(200)).body.options[0].votes).toBe(1);

    const voted = (await post(owner, `/polls/${poll.id}/votes`, { optionId: karaoke.id }).expect(201)).body;
    expect(voted).toMatchObject({ totalVotes: 2, resultsVisible: true, myOptionId: karaoke.id });
    expect(voted.options.map((o: { votes: number }) => o.votes)).toEqual([1, 1, 0]);

    const again = await post(owner, `/polls/${poll.id}/votes`, { optionId: movie.id }).expect(409);
    expect(again.body.error.code).toBe('ALREADY_VOTED');
  });

  it('counts a person once even if they hold two roles', async () => {
    const poll = (await post(admin, '/polls', sundayPoll).expect(201)).body;
    await post(admin, `/polls/${poll.id}/votes`, { optionId: poll.options[0].id }).expect(201);
    // Asha is also the owner of 101; switching role doesn't give her a second vote.
    const switched = await t
      .http()
      .post('/v1/auth/switch')
      .set(auth(admin))
      .send({ membershipId: fx.adminAsOwner.id, refreshToken: adminRefresh })
      .expect(200);
    const res = await post(switched.body.accessToken, `/polls/${poll.id}/votes`, { optionId: poll.options[1].id }).expect(409);
    expect(res.body.error.code).toBe('ALREADY_VOTED');
  });

  it('closed polls reject votes and show results to everyone', async () => {
    const poll = (await post(admin, '/polls', sundayPoll).expect(201)).body;
    await post(owner, `/polls/${poll.id}/close`).expect(403);
    const closed = (await post(admin, `/polls/${poll.id}/close`).expect(201)).body;
    expect(closed.isOpen).toBe(false);

    const res = await post(tenant, `/polls/${poll.id}/votes`, { optionId: poll.options[0].id }).expect(409);
    expect(res.body.error.code).toBe('POLL_CLOSED');
    const seen = (await get(tenant, `/polls/${poll.id}`).expect(200)).body;
    expect(seen.resultsVisible).toBe(true);

    const open = (await post(admin, '/polls', { ...sundayPoll, question: 'Second poll here?' }).expect(201)).body;
    const list = (await get(tenant, '/polls').expect(200)).body;
    expect(list.map((p: { id: string }) => p.id)).toEqual([open.id, poll.id]); // open first
    expect((await get(tenant, '/polls?status=open').expect(200)).body).toHaveLength(1);
  });

  it("can't see or vote in another society's polls", async () => {
    const other = await t.prisma.society.create({ data: { name: 'Elsewhere', city: 'Pune' } });
    const poll = await t.prisma.poll.create({
      data: {
        societyId: other.id,
        question: 'Hidden?',
        createdById: fx.admin.user.id,
        options: { create: [{ label: 'A' }, { label: 'B' }] },
      },
      include: { options: true },
    });
    await get(owner, `/polls/${poll.id}`).expect(404);
    await post(owner, `/polls/${poll.id}/votes`, { optionId: poll.options[0].id }).expect(404);
    expect((await get(owner, '/polls').expect(200)).body).toEqual([]);
  });
});

describe('communities', () => {
  const yoga = () => ({
    name: 'Yoga Club',
    description: 'Morning yoga for all levels.',
    memberIds: [fx.owner.user.id],
  });

  it('admins create clubs with members; residents see them', async () => {
    await post(owner, '/communities', yoga()).expect(403);
    const created = (await post(admin, '/communities', yoga()).expect(201)).body;
    expect(created).toMatchObject({ name: 'Yoga Club', memberCount: 1, isMember: false });
    expect(created.members).toEqual([{ userId: fx.owner.user.id, name: 'Omkar Owner', flatLabel: 'Tower-A, 102' }]);

    const list = (await get(owner, '/communities').expect(200)).body;
    expect(list).toEqual([expect.objectContaining({ name: 'Yoga Club', isMember: true, latestAnnouncement: null })]);

    const dup = await post(admin, '/communities', yoga()).expect(409);
    expect(dup.body.error.code).toBe('COMMUNITY_EXISTS');
  });

  it('only lets admins add people from their own society', async () => {
    const outsider = await t.prisma.user.create({ data: { name: 'Outsider', phone: '+919811111111' } });
    await post(admin, '/communities', { ...yoga(), memberIds: [outsider.id] }).expect(404);

    const candidates = (await get(admin, '/communities/candidates').expect(200)).body;
    expect(candidates.map((c: { name: string }) => c.name)).toEqual(['Asha Admin', 'Omkar Owner', 'Tara Tenant']);
    await get(owner, '/communities/candidates').expect(403);
  });

  it('residents join and leave; admins replace the member list', async () => {
    const club = (await post(admin, '/communities', yoga()).expect(201)).body;
    const joined = (await post(tenant, `/communities/${club.id}/join`).expect(201)).body;
    expect(joined).toMatchObject({ isMember: true, memberCount: 2 });
    await post(tenant, `/communities/${club.id}/join`).expect(201); // idempotent
    const left = (await post(owner, `/communities/${club.id}/leave`).expect(201)).body;
    expect(left).toMatchObject({ isMember: false, memberCount: 1 });

    const edited = (
      await patch(admin, `/communities/${club.id}`, { ...yoga(), name: 'Sunrise Yoga', memberIds: [fx.admin.user.id] }).expect(200)
    ).body;
    expect(edited).toMatchObject({ name: 'Sunrise Yoga', memberCount: 1 });
    expect(edited.members[0].name).toBe('Asha Admin');
  });

  it('admins post, edit and delete announcements; members are notified', async () => {
    const club = (await post(admin, '/communities', yoga()).expect(201)).body;
    const eventAt = new Date(Date.now() + 86_400_000);
    const endsAt = new Date(eventAt.getTime() + 45 * 60_000);
    const body = { title: 'Breathing for Balance', body: 'Bring your mats.', eventAt, endsAt, venue: 'Terrace' };

    await post(owner, `/communities/${club.id}/announcements`, body).expect(403);
    await post(admin, `/communities/${club.id}/announcements`, { ...body, endsAt: eventAt }).expect(400);
    const created = (await post(admin, `/communities/${club.id}/announcements`, body).expect(201)).body;
    expect(created).toMatchObject({ title: 'Breathing for Balance', venue: 'Terrace', authorName: 'Asha Admin' });

    const notes = await t.prisma.notification.findMany({ where: { type: 'announcement' } });
    expect(notes.map((n) => [n.userId, n.title])).toEqual([[fx.owner.user.id, 'Yoga Club']]);

    const detail = (await get(tenant, `/communities/${club.id}`).expect(200)).body;
    expect(detail.announcements).toHaveLength(1);
    expect(detail.latestAnnouncement.id).toBe(created.id);

    await patch(owner, `/announcements/${created.id}`, body).expect(403);
    const edited = (await patch(admin, `/announcements/${created.id}`, { ...body, title: 'Pranayama basics' }).expect(200)).body;
    expect(edited.title).toBe('Pranayama basics');
    await del(admin, `/announcements/${created.id}`).expect(204);
    expect((await get(owner, `/communities/${club.id}`).expect(200)).body.announcements).toEqual([]);
  });
});
