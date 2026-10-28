import { Controller, Get } from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';
import { Public } from './auth/auth-context.js';
import { PrismaService } from './prisma/prisma.service.js';

@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  @Public()
  @SkipThrottle()
  @Get()
  async check(): Promise<{ status: 'ok'; database: 'ok' }> {
    await this.prisma.$queryRaw`SELECT 1`;
    return { status: 'ok', database: 'ok' };
  }
}
