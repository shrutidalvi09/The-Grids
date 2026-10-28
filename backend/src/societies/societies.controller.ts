import { Controller, Get, Query } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { IsOptional, IsString, MaxLength } from 'class-validator';
import { Public } from '../auth/auth-context.js';
import { PrismaService } from '../prisma/prisma.service.js';

class SearchSocietiesQuery {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  search?: string;
}

export interface SocietySummary {
  id: string;
  name: string;
  city: string | null;
}

/** Public list for the "Select your society" screen. */
@Controller('societies')
export class SocietiesController {
  constructor(private readonly prisma: PrismaService) {}

  @Public()
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @Get()
  list(@Query() query: SearchSocietiesQuery): Promise<SocietySummary[]> {
    const search = query.search?.trim();
    return this.prisma.society.findMany({
      where: { isActive: true, ...(search ? { name: { contains: search } } : {}) },
      select: { id: true, name: true, city: true },
      orderBy: { name: 'asc' },
      take: 50,
    });
  }
}
