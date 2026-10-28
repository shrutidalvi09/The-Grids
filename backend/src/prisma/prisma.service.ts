import { Inject, Injectable, OnModuleDestroy } from '@nestjs/common';
import { PrismaClient } from '../generated/prisma/client.js';
import { ENV, type Env } from '../config/env.js';
import { createAdapter } from './adapter.js';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleDestroy {
  constructor(@Inject(ENV) env: Env) {
    super({ adapter: createAdapter(env.databaseUrl) });
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }
}
