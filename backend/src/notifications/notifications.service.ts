import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { asLang, type Message, renderMessage } from './messages.js';
import { preferenceFor, readPreferences } from './preferences.js';
import { PushSender } from './push-sender.js';

/**
 * What to send. Either a [message] the server writes in each recipient's
 * language, or a [title]/[body] typed by a person (notices, announcements),
 * sent as is.
 */
export type NotificationInput = {
  /** due | due_reminder | payment | notice | alert | poll | announcement | complaint | visitor | parcel | event | … */
  type: string;
  data?: Record<string, string>;
} & ({ message: Message } | { title: string; body: string });

/** Pushed even when the person turned push off: someone is waiting on them. */
const URGENT_TYPES = new Set(['sos', 'visitor_approval']);

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
      select: { id: true, language: true, notificationPrefs: true, deviceTokens: { select: { token: true } } },
    });
    const key = preferenceFor(notification.type);
    const recipients = users
      .map((u) => ({ ...u, prefs: readPreferences(u.notificationPrefs) }))
      .filter((u) => key === null || u.prefs[key]);
    if (!recipients.length) return 0;

    // One rendering per language.
    const texts = new Map<string, { title: string; body: string }>();
    const textFor = (language: string) => {
      const lang = asLang(language);
      if (!texts.has(lang)) {
        texts.set(lang, 'message' in notification ? renderMessage(notification.message, lang) : notification);
      }
      return { lang, ...texts.get(lang)! };
    };

    await this.prisma.notification.createMany({
      data: recipients.map((u) => {
        const { title, body } = textFor(u.language);
        return { userId: u.id, societyId, type: notification.type, title, body, data: notification.data ?? undefined };
      }),
    });

    // Pushes go out per language, since each batch shares one text.
    const tokensByLang = new Map<string, string[]>();
    const urgent = URGENT_TYPES.has(notification.type);
    for (const u of recipients.filter((r) => urgent || r.prefs.push)) {
      const { lang } = textFor(u.language);
      tokensByLang.set(lang, [...(tokensByLang.get(lang) ?? []), ...u.deviceTokens.map((d) => d.token)]);
    }
    for (const [lang, tokens] of tokensByLang) {
      if (!tokens.length) continue;
      const { title, body } = texts.get(lang)!;
      try {
        const { invalidTokens } = await this.push.send(tokens, {
          title,
          body,
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
        role: { in: ['ADMIN', 'OWNER', 'TENANT'] }, // guards get gate updates only
        // Tower notices go to that tower's residents and to admins.
        ...(where.towerId ? { OR: [{ role: 'ADMIN' }, { flat: { towerId: where.towerId } }] } : {}),
      },
      select: { userId: true },
    });
    return members.map((m) => m.userId);
  }

  /**
   * Who works the gate: the guards, or the admins when the society has no
   * guards yet. [withAdmins] adds the admins anyway (SOS).
   */
  async gateStaffIds(societyId: string, { withAdmins = false } = {}): Promise<string[]> {
    const members = await this.prisma.membership.findMany({
      where: { societyId, status: 'ACTIVE', role: { in: ['GUARD', 'ADMIN'] } },
      select: { userId: true, role: true },
    });
    const guards = members.filter((m) => m.role === 'GUARD');
    const staff = withAdmins || !guards.length ? members : guards;
    return staff.map((m) => m.userId);
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
