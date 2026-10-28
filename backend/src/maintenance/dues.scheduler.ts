import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service.js';
import { DuesService } from './dues.service.js';

/**
 * Issues each month's dues. Runs daily (not just on the 1st) so a missed run
 * or a newly added tenant is picked up the next day; generation is idempotent.
 */
@Injectable()
export class DuesScheduler {
  private readonly logger = new Logger(DuesScheduler.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly dues: DuesService,
  ) {}

  @Cron('15 0 * * *', { name: 'issue-dues', timeZone: 'Asia/Kolkata' })
  async issueDues(): Promise<void> {
    const societies = await this.prisma.society.findMany({ where: { isActive: true }, select: { id: true } });
    for (const { id } of societies) {
      try {
        await this.dues.generate(id);
      } catch (error) {
        this.logger.error(`Issuing dues failed for society ${id}: ${(error as Error).message}`);
      }
    }
  }
}
