/**
 * Demo data for The Grids: 1 fully populated society (3 towers, 30 flats,
 * 20 owners, 4 tenants) plus 3 empty societies for the society picker.
 *
 *   npm run db:seed            (wipes and re-creates all data)
 *
 * All dates are relative to "now" so the data always looks current.
 * Refuses to run when NODE_ENV=production.
 */
import 'dotenv/config';
import { Prisma, PrismaClient } from '../src/generated/prisma/client.js';
import type { Role } from '../src/generated/prisma/enums.js';
import { createAdapter } from '../src/prisma/adapter.js';

if (process.env.NODE_ENV === 'production') {
  console.error('Refusing to seed: NODE_ENV=production');
  process.exit(1);
}
const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error('DATABASE_URL is not set');

const prisma = new PrismaClient({ adapter: createAdapter(databaseUrl) });

// ───────────────────────────── helpers ─────────────────────────────

const rupees = (amount: number) => Math.round(amount * 100);
const now = new Date();

function at(daysFromToday: number, hour = 0, minute = 0): Date {
  const d = new Date(now);
  d.setDate(d.getDate() + daysFromToday);
  d.setHours(hour, minute, 0, 0);
  return d;
}

/** First day of the month `offset` months from now (0 = this month). */
function monthStart(offset: number): Date {
  return new Date(now.getFullYear(), now.getMonth() + offset, 1);
}

const period = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
const dayOf = (month: Date, day: number) => new Date(month.getFullYear(), month.getMonth(), day, 10, 0, 0);

const methods = ['upi', 'card', 'netbanking', 'upi', 'wallet'] as const;
/** Per-month sequences, saved to ReceiptCounter so live payments continue them. */
const receiptCounters = new Map<string, number>();
function receiptNo(prefix: 'MNT' | 'RNT', paidAt: Date): string {
  const key = `${prefix}-${paidAt.getFullYear()}-${String(paidAt.getMonth() + 1).padStart(2, '0')}`;
  const next = (receiptCounters.get(key) ?? 0) + 1;
  receiptCounters.set(key, next);
  return `${key.replaceAll('-', '/')}/${String(next).padStart(4, '0')}`;
}

// ───────────────────────────── people ─────────────────────────────

/** Demo phone numbers. The admin is also the owner of Tower-C 502. */
const OWNERS = [
  'Shruti Chetan Dalvi',
  'Riya Mehta',
  'Kiran Rathod',
  'Sneha Kulkarni',
  'Mehul Shah',
  'Dr. Neeta Deshmukh',
  'Arjun Nair',
  'Ramesh Patel',
  'Aman Kapoor',
  'Varun Agarwal',
  'Ravi Bansal',
  'Rajeev Iyer',
  "Leena D'Souza",
  'Abhay Sinha',
  'Karthik Rao',
  'Rohit Malhotra',
  'Sanskriti Kadam',
  'Meena Patil',
  'Kavita Jadhav',
  'Nikhil Joshi',
].map((name, i) => ({ name, phone: `+9190000000${String(i + 1).padStart(2, '0')}` }));

/** Each tenant rents the flat of the owner at `ownerIndex`. */
const TENANTS = [
  { name: 'Shreyas Kulkarni', phone: '+919100000001', ownerIndex: 4 },
  { name: 'Ananya Menon', phone: '+919100000002', ownerIndex: 8 },
  { name: 'Farhan Qureshi', phone: '+919100000003', ownerIndex: 12 },
  { name: 'Priya Reddy', phone: '+919100000004', ownerIndex: 16 },
];

/** The last owner has been invited but has never signed in. */
const INVITED_OWNER_INDEX = 19;

// ───────────────────────────── seed ─────────────────────────────

async function wipe() {
  // Children before parents. Order follows the foreign keys.
  await prisma.notification.deleteMany();
  await prisma.deviceToken.deleteMany();
  await prisma.announcement.deleteMany();
  await prisma.communityMember.deleteMany();
  await prisma.community.deleteMany();
  await prisma.pollVote.deleteMany();
  await prisma.pollOption.deleteMany();
  await prisma.poll.deleteMany();
  await prisma.payment.deleteMany();
  await prisma.due.deleteMany();
  await prisma.tenancy.deleteMany();
  await prisma.societyBill.deleteMany();
  await prisma.maintenanceItem.deleteMany();
  await prisma.complaint.deleteMany();
  await prisma.notice.deleteMany();
  await prisma.facilityBooking.deleteMany();
  await prisma.facility.deleteMany();
  await prisma.visitor.deleteMany();
  await prisma.householdMember.deleteMany();
  await prisma.serviceProvider.deleteMany();
  await prisma.event.deleteMany();
  await prisma.receiptCounter.deleteMany();
  await prisma.refreshToken.deleteMany();
  await prisma.otpChallenge.deleteMany();
  await prisma.membership.deleteMany();
  await prisma.user.deleteMany();
  await prisma.flat.deleteMany();
  await prisma.tower.deleteMany();
  await prisma.society.deleteMany();
}

async function main() {
  await wipe();

  // Societies -----------------------------------------------------------
  const society = await prisma.society.create({
    data: {
      name: 'Sai Icon Co-operative Society',
      address: 'Ghodbunder Road, Thane West',
      city: 'Thane',
      maintenanceDueDay: 10,
      latitude: 19.2183,
      longitude: 72.9781,
      timezone: 'Asia/Kolkata',
    },
  });
  await prisma.society.createMany({
    data: [
      { name: 'Stark Tower', city: 'Mumbai' },
      { name: 'Mohan Kheda Residency', city: 'Pune' },
      { name: 'Virat Rahul Residency', city: 'Bengaluru' },
    ],
  });
  const societyId = society.id;

  // Towers and flats: 3 towers × 5 floors × 2 flats = 30 -----------------
  const flats: { id: string; label: string }[] = [];
  for (const towerName of ['Tower-A', 'Tower-B', 'Tower-C']) {
    const tower = await prisma.tower.create({ data: { societyId, name: towerName, floors: 5 } });
    for (let floor = 1; floor <= 5; floor++) {
      for (let unit = 1; unit <= 2; unit++) {
        const number = `${floor}0${unit}`;
        const flat = await prisma.flat.create({ data: { societyId, towerId: tower.id, number, floor } });
        flats.push({ id: flat.id, label: `${towerName}, ${number}` });
      }
    }
  }
  // Owner i gets a flat; Shruti (owner 0) lives in Tower-C 502. 10 flats stay vacant.
  const shrutiFlat = flats.findIndex((f) => f.label === 'Tower-C, 502');
  const ownedFlatIndexes = [shrutiFlat, ...[0, 1, 2, 3, 4, 5, 6, 10, 11, 12, 13, 14, 15, 16, 20, 21, 22, 23, 24]];

  // Users and memberships -------------------------------------------------
  const owners = [];
  for (const [i, o] of OWNERS.entries()) {
    const user = await prisma.user.create({ data: { name: o.name, phone: o.phone } });
    const flat = flats[ownedFlatIndexes[i]];
    const status = i === INVITED_OWNER_INDEX ? 'INVITED' : 'ACTIVE';
    await prisma.membership.create({
      data: { userId: user.id, societyId, role: 'OWNER', flatId: flat.id, status },
    });
    owners.push({ ...user, flat });
  }
  const admin = owners[0];
  await prisma.membership.create({
    data: { userId: admin.id, societyId, role: 'ADMIN', status: 'ACTIVE' },
  });

  const tenants = [];
  for (const t of TENANTS) {
    const user = await prisma.user.create({ data: { name: t.name, phone: t.phone } });
    const owner = owners[t.ownerIndex];
    await prisma.membership.create({
      data: { userId: user.id, societyId, role: 'TENANT', flatId: owner.flat.id, status: 'ACTIVE', invitedById: owner.id },
    });
    tenants.push({ ...user, owner, flat: owner.flat });
  }

  // Household (Shruti's flat) ----------------------------------------------
  await prisma.householdMember.createMany({
    data: [
      { flatId: admin.flat.id, name: 'Chetan Dalvi', relation: 'Father' },
      { flatId: admin.flat.id, name: 'Pragati Dalvi', relation: 'Mother' },
      { flatId: admin.flat.id, name: 'Shreyas Dalvi', relation: 'Brother' },
    ],
  });

  // Maintenance config: ₹500 + ₹1,200 + ₹300 + ₹500 = ₹2,500 ---------------
  const maintenanceItems = [
    { label: 'Cleaning', amountPaise: rupees(500) },
    { label: 'Gardening', amountPaise: rupees(1200) },
    { label: 'Security', amountPaise: rupees(300) },
    { label: 'Water', amountPaise: rupees(500) },
  ];
  await prisma.maintenanceItem.createMany({
    data: maintenanceItems.map((item, sortOrder) => ({ ...item, societyId, sortOrder })),
  });
  const maintenanceTotal = maintenanceItems.reduce((sum, item) => sum + item.amountPaise, 0);

  // Tenancies (rent items only, not maintenance) -----------------------------
  const rentBreakdown = [
    { label: 'Rent', amountPaise: rupees(14000) },
    { label: 'Parking', amountPaise: rupees(1000) },
  ];
  const rentTotal = rentBreakdown.reduce((sum, item) => sum + item.amountPaise, 0); // ₹15,000
  for (const t of tenants) {
    await prisma.tenancy.create({
      data: {
        societyId,
        flatId: t.flat.id,
        ownerId: t.owner.id,
        tenantId: t.id,
        monthlyRentPaise: rentTotal,
        depositPaise: rupees(60000),
        rentDueDay: 5,
        rentBreakdown,
        startDate: monthStart(-8),
        endDate: monthStart(3),
      },
    });
  }

  // Dues and payments ---------------------------------------------------------
  // Maintenance: last 3 months paid by everyone; this month 10 of 20 flats unpaid.
  for (const [i, owner] of owners.entries()) {
    for (const offset of [-3, -2, -1, 0]) {
      const month = monthStart(offset);
      const unpaid = offset === 0 && i % 2 === 0;
      const dueDate = dayOf(month, society.maintenanceDueDay);
      const paidAt = unpaid ? null : dayOf(month, 3 + (i % 6));
      const due = await prisma.due.create({
        data: {
          societyId,
          flatId: owner.flat.id,
          type: 'MAINTENANCE',
          period: period(month),
          amountPaise: maintenanceTotal,
          breakdown: maintenanceItems,
          dueDate,
          status: unpaid ? 'PENDING' : 'PAID',
          paidAt,
        },
      });
      if (paidAt) {
        await prisma.payment.create({
          data: {
            societyId,
            dueId: due.id,
            payerId: owner.id, // owners pay maintenance, even for rented flats
            amountPaise: maintenanceTotal,
            method: methods[(i + offset + 3) % methods.length],
            status: 'SUCCEEDED',
            razorpayPaymentId: `pay_seed_${due.id}`,
            receiptNo: receiptNo('MNT', paidAt),
            paidAt,
          },
        });
      }
    }
  }
  // Rent: last 2 months paid; this month 2 of 4 tenants unpaid.
  for (const [i, t] of tenants.entries()) {
    for (const offset of [-2, -1, 0]) {
      const month = monthStart(offset);
      const unpaid = offset === 0 && i < 2;
      const paidAt = unpaid ? null : dayOf(month, 2 + i);
      const due = await prisma.due.create({
        data: {
          societyId,
          flatId: t.flat.id,
          type: 'RENT',
          period: period(month),
          amountPaise: rentTotal,
          breakdown: rentBreakdown,
          dueDate: dayOf(month, 5),
          status: unpaid ? 'PENDING' : 'PAID',
          paidAt,
        },
      });
      if (paidAt) {
        await prisma.payment.create({
          data: {
            societyId,
            dueId: due.id,
            payerId: t.id,
            amountPaise: rentTotal,
            method: methods[(i + offset + 2) % methods.length],
            status: 'SUCCEEDED',
            razorpayPaymentId: `pay_seed_${due.id}`,
            receiptNo: receiptNo('RNT', paidAt),
            paidAt,
          },
        });
      }
    }
  }

  // Society bills (what the society owes vendors) -------------------------------
  const bills: [string, string, number][] = [
    ['Electrician', 'Repairs', 15000],
    ['Housekeeping staff', 'Staff', 15000],
    ['Plumber', 'Repairs', 15000],
    ['Security agency', 'Security', 12000],
    ['Water supply', 'Utilities', 8500],
    ['Lift maintenance AMC', 'Maintenance', 18000],
    ['Generator fuel', 'Utilities', 10000],
    ['Pest control', 'Maintenance', 7500],
    ['Gardening', 'Maintenance', 9000],
    ['Cleaning staff', 'Staff', 11000],
    ['Fire safety equipment', 'Safety', 13500],
    ['Waste disposal', 'Utilities', 6000],
    ['Parking area lighting', 'Utilities', 10500],
    ['Water tank cleaning', 'Maintenance', 4500],
  ];
  await prisma.societyBill.createMany({
    data: bills.map(([vendor, category, amount], i) => {
      const paid = i % 2 === 0;
      const dueDate = paid ? at(-20 + i) : at(i - 3);
      return {
        societyId,
        vendor,
        category,
        amountPaise: rupees(amount),
        dueDate,
        status: paid ? 'PAID' : 'DUE',
        paidAt: paid ? at(-18 + i) : null,
      } as const;
    }),
  });

  // Notices -------------------------------------------------------------------
  await prisma.notice.createMany({
    data: [
      {
        title: 'Water supply interruption',
        body: 'Water supply will be off from 2 PM to 4 PM today for pipeline repairs.',
        category: 'Utilities',
        isAlert: true,
        scheduledAt: at(0, 14),
        expiresAt: at(1, 0),
      },
      {
        title: 'Lift maintenance',
        body: 'Tower-C lift will be under maintenance. Please use the service lift.',
        category: 'Maintenance',
        scheduledAt: at(2, 10),
      },
      { title: 'Fire drill', body: 'Mandatory fire drill for all towers. Assemble at the main gate.', category: 'Safety', scheduledAt: at(5, 15) },
      { title: 'Tank cleaning', body: 'Overhead water tanks will be cleaned. Store water the night before.', category: 'Maintenance', scheduledAt: at(3, 9) },
      { title: 'Pest control', body: 'Pest control in common areas and basements.', category: 'Maintenance', scheduledAt: at(-1, 11) },
      { title: 'Generator inspection', body: 'Annual generator inspection. Brief power cuts possible.', category: 'Utilities', scheduledAt: at(-2, 12) },
      { title: 'Society general meeting', body: 'AGM in the clubhouse. Agenda: budget, EV chargers, security.', category: 'Meeting', scheduledAt: at(7, 18) },
      { title: 'Parking area painting', body: 'Basement parking lines will be repainted. Move vehicles to visitor parking.', category: 'Maintenance', scheduledAt: at(-4, 8) },
    // Newest first: the alert today, then one notice per earlier day.
    ].map((n, i) => ({ ...n, societyId, createdById: admin.id, createdAt: at(-i, 8) })),
  });

  // Complaints -----------------------------------------------------------------
  await prisma.complaint.createMany({
    data: [
      { title: 'Lift stuck between floors', category: 'Lift', description: 'Tower-C lift stopped between the 3rd and 4th floor twice this week.', status: 'OPEN', flatId: admin.flat.id, raisedById: admin.id, createdAt: at(-1, 9) },
      { title: 'Gym AC not cooling', category: 'Facilities', description: 'The gym air conditioner has not been cooling since Monday.', status: 'IN_PROGRESS', flatId: owners[2].flat.id, raisedById: owners[2].id, createdAt: at(-3, 18) },
      { title: 'Water tank overflow', category: 'Water', description: 'Overhead tank in Tower-A overflows every morning.', status: 'RESOLVED', resolvedAt: at(-2, 12), flatId: owners[1].flat.id, raisedById: owners[1].id, createdAt: at(-6, 7) },
      { title: 'Parking light not working', category: 'Electrical', description: 'Two lights near B-wing parking are off.', status: 'OPEN', flatId: owners[9].flat.id, raisedById: owners[9].id, createdAt: at(-2, 21) },
    ].map((c) => ({ ...c, societyId }) as Prisma.ComplaintCreateManyInput),
  });

  // Visitors -------------------------------------------------------------------
  await prisma.visitor.createMany({
    data: [
      { name: 'Rekha', purpose: 'Maid', type: 'SERVICE', status: 'CHECKED_IN', inTime: at(0, 9), flatId: admin.flat.id },
      { name: 'Cleaner', purpose: 'Housekeeping', type: 'SERVICE', status: 'EXPECTED', flatId: admin.flat.id },
      { name: 'Father-in-law', purpose: 'Guest', type: 'GUEST', status: 'CHECKED_OUT', inTime: at(-1, 20, 10), outTime: at(-1, 22), flatId: admin.flat.id },
      { name: 'Amazon', purpose: 'Parcel', type: 'DELIVERY', status: 'HELD_AT_GATE', inTime: at(0, 10, 30), flatId: admin.flat.id },
      { name: 'Milk vendor', purpose: 'Daily milk', type: 'SERVICE', status: 'CHECKED_OUT', inTime: at(0, 7, 15), outTime: at(0, 7, 20), flatId: admin.flat.id },
      { name: 'Anita', purpose: 'Cook', type: 'SERVICE', status: 'CHECKED_IN', inTime: at(0, 8, 45), flatId: owners[3].flat.id },
      { name: 'Ravi', purpose: 'Friend', type: 'GUEST', status: 'CHECKED_OUT', inTime: at(-1, 18, 20), outTime: at(-1, 21), flatId: owners[5].flat.id },
      { name: 'Flipkart', purpose: 'Courier', type: 'DELIVERY', status: 'CHECKED_OUT', inTime: at(0, 11, 10), outTime: at(0, 11, 15), flatId: tenants[0].flat.id },
    ].map((v) => ({ ...v, societyId }) as Prisma.VisitorCreateManyInput),
  });

  // Facilities and bookings ------------------------------------------------------
  const facilityRows = [
    { name: 'Library', description: 'Quiet study area with air conditioning and free Wi-Fi.', openTime: '09:00', closeTime: '21:00', maxDurationMins: 120, capacity: 20 },
    { name: 'Badminton Court', description: 'Equipment available at the sports counter.', openTime: '06:00', closeTime: '22:00', maxDurationMins: 60, capacity: 1 },
    { name: 'Swimming Pool', description: 'Lifeguard on duty during opening hours.', openTime: '06:00', closeTime: '20:00', maxDurationMins: 60, capacity: 25 },
    { name: 'Gym', description: 'Treadmills, weights and personal trainer access.', openTime: '05:00', closeTime: '22:00', maxDurationMins: 90, capacity: 20 },
    { name: 'Tennis Court', description: 'Floodlights available for night play.', openTime: '06:00', closeTime: '22:00', maxDurationMins: 60, capacity: 1 },
    { name: 'Study Room', description: 'Perfect for group studies and laptop work.', openTime: '08:00', closeTime: '22:00', maxDurationMins: 180, capacity: 8 },
    { name: 'Music Room', description: 'Soundproof room with guitar, keyboard and drums.', openTime: '10:00', closeTime: '20:30', maxDurationMins: 60, capacity: 1 },
  ];
  const facilities = [];
  for (const f of facilityRows) facilities.push(await prisma.facility.create({ data: { ...f, societyId } }));
  await prisma.facilityBooking.createMany({
    data: [
      { facilityId: facilities[1].id, userId: admin.id, startsAt: at(0, 17), endsAt: at(0, 18) },
      { facilityId: facilities[4].id, userId: owners[6].id, startsAt: at(0, 18), endsAt: at(0, 19) },
      { facilityId: facilities[3].id, userId: tenants[1].id, startsAt: at(1, 7), endsAt: at(1, 8) },
    ],
  });

  // Polls ----------------------------------------------------------------------
  const voters = [...owners.slice(1, INVITED_OWNER_INDEX), ...tenants]; // admin hasn't voted yet
  const sundayPoll = await prisma.poll.create({
    data: {
      societyId,
      question: 'Which activity for Sunday?',
      closesAt: at(5, 20),
      createdById: admin.id,
      options: {
        create: [
          { label: 'Movie Night', sortOrder: 0 },
          { label: 'Karaoke', sortOrder: 1 },
          { label: 'Sports Tournament', sortOrder: 2 },
        ],
      },
    },
    include: { options: true },
  });
  // 9 / 7 / 5 votes
  const voteSplit = [9, 7, 5];
  let v = 0;
  for (const [optionIndex, count] of voteSplit.entries()) {
    for (let n = 0; n < count; n++, v++) {
      await prisma.pollVote.create({
        data: { pollId: sundayPoll.id, optionId: sundayPoll.options[optionIndex].id, userId: voters[v].id },
      });
    }
  }
  const evPoll = await prisma.poll.create({
    data: {
      societyId,
      question: 'Should we install EV chargers in the basement parking?',
      closesAt: at(-3, 20),
      createdById: admin.id,
      options: { create: [{ label: 'Yes', sortOrder: 0 }, { label: 'No', sortOrder: 1 }] },
    },
    include: { options: true },
  });
  for (const [i, voter] of voters.slice(0, 19).entries()) {
    await prisma.pollVote.create({
      data: { pollId: evPoll.id, optionId: evPoll.options[i < 15 ? 0 : 1].id, userId: voter.id },
    });
  }

  // Communities and announcements ------------------------------------------------
  const sanskriti = owners[16];
  const communities: [string, string, { id: string }[], { title: string; body: string; eventAt: Date; endsAt: Date; venue: string }][] = [
    [
      'Yoga Club',
      'Morning yoga and breathing sessions for all levels.',
      [admin, owners[3], owners[5], owners[7], sanskriti, owners[17], tenants[1]],
      {
        title: 'Breathing for Balance',
        body: 'Join our short morning session on "Breathing for Balance". Sanskriti will demonstrate simple pranayama techniques that help improve focus and reduce stress. Beginners are welcome — bring your mats and water bottles!',
        eventAt: at(1, 6, 30),
        endsAt: at(1, 7, 15),
        venue: 'Community Hall Terrace',
      },
    ],
    [
      'Book Readers Club',
      'A weekend reading circle. One book a month, lots of chai.',
      [admin, owners[1], owners[11], sanskriti, owners[14]],
      {
        title: 'Reading as a meditative practice',
        body: 'Join our weekend reading circle as we explore how reading can become a meditative practice. Book of the week: The Alchemist by Paulo Coelho.',
        eventAt: at(4, 17),
        endsAt: at(4, 18, 30),
        venue: 'Lounge Room, Clubhouse',
      },
    ],
    [
      'Kids Zone',
      'Activities and play dates for children of the society.',
      [owners[2], owners[8], owners[10], tenants[2]],
      {
        title: 'Painting competition',
        body: 'Kids painting competition for ages 5–12. Colours and sheets will be provided.',
        eventAt: at(10, 17),
        endsAt: at(10, 19),
        venue: 'Clubhouse Court',
      },
    ],
  ];
  for (const [name, description, members, announcement] of communities) {
    await prisma.community.create({
      data: {
        societyId,
        name,
        description,
        createdById: admin.id,
        members: { create: members.map((m) => ({ userId: m.id })) },
        announcements: { create: [{ ...announcement, authorId: name === 'Kids Zone' ? admin.id : sanskriti.id }] },
      },
    });
  }

  // Service providers --------------------------------------------------------------
  const services: [string, string, string][] = [
    ['Maid', 'Akshara More', 'Ambivali'],
    ['Maid', 'Pooja Sawant', 'Dombivli'],
    ['Maid', 'Meena Gaikwad', 'Kalyan'],
    ['Maid', 'Kavita Shinde', 'Thane West'],
    ['Maid', 'Rina More', 'Ambernath'],
    ['Maid', 'Shital Shinde', 'Ulhasnagar'],
    ['Cook', 'Anita Pawar', 'Thane West'],
    ['Cook', 'Sunita Rao', 'Majiwada'],
    ['Cook', 'Lakshmi Iyer', 'Kasarvadavali'],
    ['Driver', 'Santosh Yadav', 'Manpada'],
    ['Driver', 'Imran Shaikh', 'Kolshet'],
    ['Laundry', 'Fresh Press Laundry', 'Hiranandani Estate'],
    ['Doctor', 'Dr. Anil Desai (GP)', 'Brahmand'],
    ['Doctor', 'Dr. Swati Kulkarni (Paediatrician)', 'Vasant Vihar'],
    ['Plumber', 'Raju Plumbing Works', 'Thane West'],
    ['Electrician', 'Prakash Electricals', 'Manpada'],
    ['Gym', 'Fit Zone Trainers', 'Clubhouse'],
    ['Newspaper', 'Ganesh News Agency', 'Thane West'],
    ['Milkman', 'Gokul Dairy', 'Kolshet'],
  ];
  await prisma.serviceProvider.createMany({
    data: services.map(([category, name, location], i) => ({
      societyId,
      category,
      name,
      location,
      phone: `+9190000${String(10001 + i).padStart(5, '0')}`,
      rating: 3.8 + ((i * 7) % 12) / 10,
    })),
  });

  // Events -----------------------------------------------------------------------
  await prisma.event.createMany({
    data: [
      { title: 'Yoga Session', location: 'Terrace', startsAt: at(1, 7), endsAt: at(1, 8), description: 'Open morning yoga for all residents.' },
      { title: 'Kids Painting Competition', location: 'Clubhouse Court', startsAt: at(10, 17), endsAt: at(10, 19), description: 'Ages 5–12. Prizes for every age group.' },
      { title: 'Community Movie Night', location: 'Clubhouse Lawn', startsAt: at(5, 19, 30), description: 'Bring your own blankets. Popcorn on us.' },
      { title: 'Blood Donation Camp', location: 'Clubhouse Hall', startsAt: at(14, 10), endsAt: at(14, 16), description: 'In partnership with the city blood bank.' },
    ].map((e) => ({ ...e, societyId })),
  });

  // A few unread notifications for the admin/owner -------------------------------------
  await prisma.notification.createMany({
    data: [
      { type: 'due', title: 'Maintenance due', body: 'Your maintenance of ₹2,500 for this month is due.', createdAt: at(-1, 9) },
      { type: 'notice', title: 'Water supply interruption', body: 'Water supply will be off from 2 PM to 4 PM today.', createdAt: at(0, 8) },
      { type: 'poll', title: 'New poll', body: 'Which activity for Sunday? Cast your vote.', createdAt: at(-2, 19) },
      { type: 'visitor', title: 'Parcel at security', body: 'An Amazon parcel is waiting at the gate.', createdAt: at(0, 10, 30) },
    ].map((n) => ({ ...n, userId: admin.id, societyId })),
  });

  await prisma.receiptCounter.createMany({
    data: [...receiptCounters].map(([key, value]) => ({ societyId, key, value })),
  });

  return { owners, tenants };
}

const roleLabel: Record<Role, string> = { ADMIN: 'Admin', OWNER: 'Owner', TENANT: 'Tenant' };

main()
  .then(async ({ owners, tenants }) => {
    const pending = await prisma.due.count({ where: { status: 'PENDING', type: 'MAINTENANCE' } });
    console.log('\nSeeded "Sai Icon Co-operative Society": 3 towers, 30 flats, 20 owners, 4 tenants.');
    console.log(`Pending maintenance dues this month: ${pending}\n`);
    console.log('Demo logins (OTP is printed in the API log):');
    const rows: [string, string, string][] = [
      [roleLabel.ADMIN, owners[0].name, owners[0].phone],
      [roleLabel.OWNER, owners[0].name, owners[0].phone],
      [roleLabel.OWNER, owners[1].name, owners[1].phone],
      [roleLabel.TENANT, tenants[0].name, tenants[0].phone],
      [`${roleLabel.OWNER} (invited)`, owners[INVITED_OWNER_INDEX].name, owners[INVITED_OWNER_INDEX].phone],
    ];
    for (const [role, name, phone] of rows) console.log(`  ${role.padEnd(16)} ${name.padEnd(22)} ${phone}`);
    await prisma.$disconnect();
  })
  .catch(async (error) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
