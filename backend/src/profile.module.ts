import { Module } from '@nestjs/common';
import { AuthModule } from './auth/auth.module.js';
import { AccountController } from './profile/account.controller.js';
import { HouseholdController } from './profile/household.controller.js';
import { SocietyController } from './profile/society.controller.js';
import { TenancyController } from './profile/tenancy.controller.js';

/** Profile tab: account, preferences, household, services, tenant info (Phase 6). */
@Module({
  imports: [AuthModule],
  controllers: [AccountController, HouseholdController, SocietyController, TenancyController],
})
export class ProfileModule {}
