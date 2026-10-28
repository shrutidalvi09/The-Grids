import { createHmac, randomInt, timingSafeEqual } from 'node:crypto';

export const OTP_LENGTH = 6;
export const OTP_TTL_SECONDS = 300;
export const OTP_RESEND_COOLDOWN_SECONDS = 30;
export const OTP_MAX_ATTEMPTS = 5;
export const OTP_MAX_PER_HOUR = 5;

export function generateOtp(): string {
  return randomInt(0, 10 ** OTP_LENGTH).toString().padStart(OTP_LENGTH, '0');
}

/** Codes are stored only as HMACs bound to their challenge id. */
export function hashOtp(pepper: string, challengeId: string, code: string): string {
  return createHmac('sha256', pepper).update(`${challengeId}:${code}`).digest('hex');
}

export function otpMatches(pepper: string, challengeId: string, code: string, storedHash: string): boolean {
  const candidate = Buffer.from(hashOtp(pepper, challengeId, code), 'hex');
  const stored = Buffer.from(storedHash, 'hex');
  return candidate.length === stored.length && timingSafeEqual(candidate, stored);
}
