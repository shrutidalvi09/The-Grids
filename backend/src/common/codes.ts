import { randomInt } from 'node:crypto';
import { Prisma } from '../generated/prisma/client.js';

/** A random numeric code with [length] digits, leading zeros kept ("042913"). */
export function randomDigits(length: number): string {
  return randomInt(0, 10 ** length)
    .toString()
    .padStart(length, '0');
}

/**
 * Runs [create] with fresh codes until one isn't taken (unique index
 * violation), so two passes never share a code in the same society.
 */
export async function withUniqueCode<T>(length: number, create: (code: string) => Promise<T>): Promise<T> {
  for (let attempt = 0; ; attempt++) {
    try {
      return await create(randomDigits(length));
    } catch (e) {
      const taken = e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002';
      if (!taken || attempt >= 4) throw e;
    }
  }
}

/** Guest passes are 6 digits and daily-help codes 5, so the gate can tell them apart. */
export const GUEST_PASS_DIGITS = 6;
export const STAFF_CODE_DIGITS = 5;

/** "MH 04 ab-1234" → "MH04AB1234". */
export function normalizeVehicleNumber(input: string): string {
  return input.toUpperCase().replace(/[^A-Z0-9]/g, '');
}
