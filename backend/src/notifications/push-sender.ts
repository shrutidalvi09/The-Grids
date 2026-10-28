import { readFile } from 'node:fs/promises';
import { Logger } from '@nestjs/common';

export interface PushMessage {
  title: string;
  body: string;
  /** String-only key/values the app uses to open the right screen. */
  data: Record<string, string>;
}

/** Delivers push notifications to device tokens. */
export abstract class PushSender {
  /** Sends to every token; returns the tokens the push service says are dead. */
  abstract send(tokens: string[], message: PushMessage): Promise<{ invalidTokens: string[] }>;
}

/** Development stand-in when no Firebase project is configured. */
export class LogPushSender extends PushSender {
  private readonly logger = new Logger('Push');

  async send(tokens: string[], message: PushMessage): Promise<{ invalidTokens: string[] }> {
    if (tokens.length) this.logger.log(`Would push "${message.title}" to ${tokens.length} device(s)`);
    return { invalidTokens: [] };
  }
}

/** Firebase Cloud Messaging via the Admin SDK. */
export class FcmPushSender extends PushSender {
  private readonly logger = new Logger('Push');

  private constructor(private readonly messaging: import('firebase-admin/messaging').Messaging) {
    super();
  }

  static async fromServiceAccountFile(file: string): Promise<FcmPushSender> {
    const { cert, initializeApp } = await import('firebase-admin/app');
    const { getMessaging } = await import('firebase-admin/messaging');
    const serviceAccount = JSON.parse(await readFile(file, 'utf8'));
    const app = initializeApp({ credential: cert(serviceAccount) }, 'the-grids');
    return new FcmPushSender(getMessaging(app));
  }

  async send(tokens: string[], message: PushMessage): Promise<{ invalidTokens: string[] }> {
    const invalidTokens: string[] = [];
    // FCM accepts at most 500 tokens per multicast.
    for (let i = 0; i < tokens.length; i += 500) {
      const batch = tokens.slice(i, i + 500);
      const result = await this.messaging.sendEachForMulticast({
        tokens: batch,
        notification: { title: message.title, body: message.body },
        data: message.data,
        android: { priority: 'high' },
      });
      result.responses.forEach((r, index) => {
        const code = r.error?.code;
        if (code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token') {
          invalidTokens.push(batch[index]);
        } else if (r.error) {
          this.logger.warn(`Push failed: ${code ?? r.error.message}`);
        }
      });
    }
    return { invalidTokens };
  }
}
