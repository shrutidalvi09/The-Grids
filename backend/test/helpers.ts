import 'dotenv/config';
import { Injectable, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module.js';
import { SmsSender } from '../src/auth/sms.js';
import { normalizeIndianMobile } from '../src/common/phone.js';
import type { Role } from '../src/generated/prisma/enums.js';
import { PrismaService } from '../src/prisma/prisma.service.js';
import { setupApp } from '../src/setup-app.js';

// Must be set before the app (and its env validation) loads.
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = process.env.TEST_DATABASE_URL;
process.env.OTP_DEV_ECHO = 'false';
process.env.UPLOADS_DIR = `${process.env.TEMP ?? '/tmp'}/thegrids-test-uploads`;

/** Captures OTP messages instead of logging them. */
@Injectable()
export class CapturingSmsSender extends SmsSender {
  readonly sent: { phone: string; message: string }[] = [];

  async send(phone: string, message: string): Promise<void> {
    this.sent.push({ phone, message });
  }

  lastCodeFor(phone: string): string {
    const last = [...this.sent].reverse().find((m) => m.phone === phone);
    if (!last) throw new Error(`No SMS sent to ${phone}`);
    return last.message.slice(0, 6);
  }
}

export interface TestApp {
  app: INestApplication;
  prisma: PrismaService;
  sms: CapturingSmsSender;
  http: () => ReturnType<typeof request>;
}

export async function createTestApp(): Promise<TestApp> {
  const sms = new CapturingSmsSender();
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
    .overrideProvider(SmsSender)
    .useValue(sms)
    .compile();
  const app = setupApp(moduleRef.createNestApplication({ rawBody: true }));
  await app.init();
  return {
    app,
    prisma: app.get(PrismaService),
    sms,
    http: () => request(app.getHttpServer()),
  };
}

/** Empties every table (keeps the migrations table). */
export async function resetDatabase(prisma: PrismaService): Promise<void> {
  const tables = await prisma.$queryRaw<{ name: string }[]>`
    SELECT TABLE_NAME AS name FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME <> '_prisma_migrations'`;
  await prisma.$transaction(async (tx) => {
    await tx.$executeRawUnsafe('SET FOREIGN_KEY_CHECKS = 0');
    for (const { name } of tables) await tx.$executeRawUnsafe(`TRUNCATE TABLE \`${name}\``);
    await tx.$executeRawUnsafe('SET FOREIGN_KEY_CHECKS = 1');
    // ~30 TRUNCATEs can exceed Prisma's 5 s default on a busy machine.
  }, { timeout: 30_000 });
}

/** A small society: 1 tower, 2 flats, an admin, an owner and a tenant. */
export async function createFixture(prisma: PrismaService) {
  const society = await prisma.society.create({ data: { name: 'Test Heights', city: 'Pune' } });
  const tower = await prisma.tower.create({ data: { societyId: society.id, name: 'Tower-A', floors: 2 } });
  const flat101 = await prisma.flat.create({ data: { societyId: society.id, towerId: tower.id, number: '101', floor: 1 } });
  const flat102 = await prisma.flat.create({ data: { societyId: society.id, towerId: tower.id, number: '102', floor: 1 } });

  const person = async (name: string, phone: string, role: Role, flatId: string | null, status: 'ACTIVE' | 'INVITED' = 'ACTIVE') => {
    const user = await prisma.user.upsert({ where: { phone }, update: {}, create: { name, phone } });
    const membership = await prisma.membership.create({
      data: { userId: user.id, societyId: society.id, role, flatId, status },
    });
    return { user, membership, phone };
  };

  const admin = await person('Asha Admin', '+919800000001', 'ADMIN', null);
  const adminAsOwner = await prisma.membership.create({
    data: { userId: admin.user.id, societyId: society.id, role: 'OWNER', flatId: flat101.id, status: 'ACTIVE' },
  });
  const owner = await person('Omkar Owner', '+919800000002', 'OWNER', flat102.id);
  const tenant = await person('Tara Tenant', '+919800000003', 'TENANT', flat102.id);

  return { society, tower, flat101, flat102, admin, adminAsOwner, owner, tenant };
}

/** Full OTP login; returns the session response body. */
export async function login(t: TestApp, societyId: string, phone: string, role: Role) {
  const requested = await t.http().post('/v1/auth/otp/request').send({ phone, societyId, role }).expect(200);
  const verified = await t
    .http()
    .post('/v1/auth/otp/verify')
    .send({ challengeId: requested.body.challengeId, code: t.sms.lastCodeFor(normalizeIndianMobile(phone)!) })
    .expect(200);
  return verified.body as {
    accessToken: string;
    refreshToken: string;
    me: { user: { id: string; name: string }; membership: { id: string; role: Role; flatLabel: string | null }; memberships: { id: string; role: Role }[] };
  };
}
