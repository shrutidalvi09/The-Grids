import { Injectable, Logger } from '@nestjs/common';
import { maskPhone } from '../common/phone.js';

/** Sends OTP text messages. Swap the implementation to plug in a provider. */
export abstract class SmsSender {
  abstract send(phoneE164: string, message: string): Promise<void>;
}

/**
 * Development sender: prints the message to the server log instead of sending
 * an SMS. Refused in production by env validation.
 */
@Injectable()
export class ConsoleSmsSender extends SmsSender {
  private readonly logger = new Logger('SMS');

  async send(phoneE164: string, message: string): Promise<void> {
    this.logger.warn(`[dev SMS → ${maskPhone(phoneE164)}] ${message}`);
  }
}
