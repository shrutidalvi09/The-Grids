import { generateOtp, hashOtp, otpMatches } from './otp.js';

const pepper = 'p'.repeat(64);

describe('otp', () => {
  it('generates 6 digits, keeping leading zeros', () => {
    for (let i = 0; i < 200; i++) expect(generateOtp()).toMatch(/^\d{6}$/);
  });

  it('matches only the same code for the same challenge', () => {
    const hash = hashOtp(pepper, 'challenge-1', '042137');
    expect(otpMatches(pepper, 'challenge-1', '042137', hash)).toBe(true);
    expect(otpMatches(pepper, 'challenge-1', '042138', hash)).toBe(false);
    expect(otpMatches(pepper, 'challenge-2', '042137', hash)).toBe(false);
    expect(otpMatches('q'.repeat(64), 'challenge-1', '042137', hash)).toBe(false);
  });
});
