import { Module } from '@nestjs/common';
import { APP_FILTER, APP_GUARD } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { AuthModule } from './auth/auth.module.js';
import { CommunityModule } from './community.module.js';
import { NotificationsModule } from './notifications.module.js';
import { ProfileModule } from './profile.module.js';
import { FeaturesModule } from './features.module.js';
import { MoneyModule } from './money.module.js';
import { ScheduleModule } from '@nestjs/schedule';
import { JwtAuthGuard, RolesGuard } from './auth/guards.js';
import { AllExceptionsFilter } from './common/http-exception.filter.js';
import { AppConfigModule } from './config/config.module.js';
import { HealthController } from './health.controller.js';
import { MembershipsController } from './memberships/memberships.controller.js';
import { PrismaModule } from './prisma/prisma.module.js';
import { SocietiesController } from './societies/societies.controller.js';

@Module({
  imports: [
    AppConfigModule,
    PrismaModule,
    ThrottlerModule.forRoot({
      throttlers: [{ name: 'default', ttl: 60_000, limit: 120 }],
      // Per-IP limits would make the e2e suite flaky; OTP cooldowns and
      // attempt limits are enforced in AuthService regardless.
      skipIf: () => process.env.NODE_ENV === 'test',
    }),
    AuthModule,
    NotificationsModule,
    FeaturesModule,
    MoneyModule,
    CommunityModule,
    ProfileModule,
    ScheduleModule.forRoot(),
  ],
  controllers: [HealthController, SocietiesController, MembershipsController],
  providers: [
    // Order matters: rate limit → authenticate → authorise.
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
    { provide: APP_FILTER, useClass: AllExceptionsFilter },
  ],
})
export class AppModule {}
