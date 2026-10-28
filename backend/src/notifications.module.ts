import { Global, Logger, Module } from '@nestjs/common';
import { ENV, type Env } from './config/env.js';
import { NotificationsController } from './notifications/notifications.controller.js';
import { NotificationsService } from './notifications/notifications.service.js';
import { FcmPushSender, LogPushSender, PushSender } from './notifications/push-sender.js';

/** In-app notifications and FCM push (Phase 6). Global so any feature can notify. */
@Global()
@Module({
  controllers: [NotificationsController],
  providers: [
    NotificationsService,
    {
      provide: PushSender,
      inject: [ENV],
      useFactory: async (env: Env): Promise<PushSender> => {
        if (!env.firebaseServiceAccountFile) return new LogPushSender();
        const sender = await FcmPushSender.fromServiceAccountFile(env.firebaseServiceAccountFile);
        new Logger('Push').log('Firebase Cloud Messaging enabled');
        return sender;
      },
    },
  ],
  exports: [NotificationsService],
})
export class NotificationsModule {}
