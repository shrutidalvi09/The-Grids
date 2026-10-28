import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { preferenceFor, readPreferences } from './preferences.js';
import { PushSender } from './push-sender.js';

export interface NotificationInput {
  /** due | due_reminder | payment | notice | alert | poll | announcement | complaint | visitor | … */
  type: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly push: PushSender,
  ) {}

  /**
   * Saves an in-app notification for each user who wants this kind of update
   * and pushes it to their phones. The author is skipped. Returns how many
   * people were notified. Push failures never fail the caller.
   */
  async notify(
    societyId: string,
    userIds: Iterable<string>,
    notification: NotificationInput,
    exceptUserId?: string,
  ): Promise<number> {
    const candidates = [...new Set(userIds)].filter((id) => id !== exceptUserId);
    if (!candidates.length) return 0;

    const users = await this.prisma.user.findMany({
      where: { id: { in: candidates } },
      select: { id: true, notificationPrefs: true, deviceTokens: { select: { token: true } } },
    });
    const key = preferenceFor(notification.type);
    const recipients = users
      .map((u) => ({ ...u, prefs: readPreferences(u.notificationPrefs) }))
      .filter((u) => key === null || u.prefs[key]);
    if (!recipients.length) return 0;

    await this.prisma.notification.createMany({
      data: recipients.map((u) => ({
        userId: u.id,
        societyId,
        type: notification.type,
        title: notification.title,
        body: notification.body,
        data: notification.data ?? undefined,
      })),
    });

    const tokens = recipients.filter((u) => u.prefs.push).flatMap((u) => u.deviceTokens.map((d) => d.token));
    if (tokens.length) {
      try {
        const { invalidTokens } = await this.push.send(tokens, {
          title: notification.title,
          body: notification.body,
          data: { type: notification.type, societyId, ...notification.data },
        });
        if (invalidTokens.length) await this.prisma.deviceToken.deleteMany({ where: { token: { in: invalidTokens } } });
      } catch (e) {
        this.logger.warn(`Push delivery failed: ${(e as Error).message}`);
      }
    }
    return recipients.length;
  }

  /** Everyone who can sign in to the society right now. */
  async activeMemberIds(societyId: string, where: { towerId?: string | null } = {}): Promise<string[]> {
    const members = await this.prisma.membership.findMany({
      where: {
        societyId,
        status: 'ACTIVE',
        // Tower notices go to that tower's residents and to admins.
        ...(where.towerId ? { OR: [{ role: 'ADMIN' }, { flat: { towerId: where.towerId } }] } : {}),
      },
      select: { userId: true },
    });
    return members.map((m) => m.userId);
  }

  /** Owners and tenants (active or invited) of a flat. */
  async flatResidentIds(societyId: string, flatId: string, roles: ('OWNER' | 'TENANT')[] = ['OWNER', 'TENANT']) {
    const members = await this.prisma.membership.findMany({
      where: { societyId, flatId, role: { in: roles }, status: { in: ['ACTIVE', 'INVITED'] } },
      select: { userId: true },
    });
    return members.map((m) => m.userId);
  }
}
