import { Module } from '@nestjs/common';
import { CommunitiesController } from './community/communities.controller.js';
import { PollsController } from './community/polls.controller.js';

/** Community tab: polls, clubs and club announcements (Phase 5). */
@Module({
  controllers: [PollsController, CommunitiesController],
})
export class CommunityModule {}
