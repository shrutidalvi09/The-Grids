const INDIAN_MOBILE = /^[6-9]\d{9}$/;

/**
 * Accepts "98765 43210", "+91 98765-43210", "09876543210" etc. and returns
 * E.164 ("+919876543210"), or null if it isn't an Indian mobile number.
 * Mirrors `Validators.normalizeIndianMobile` in the Flutter app.
 */
export function normalizeIndianMobile(input: string): string | null {
  let digits = input.replace(/[\s\-()]/g, '');
  if (digits.startsWith('+91')) {
    digits = digits.slice(3);
  } else if (digits.length === 12 && digits.startsWith('91')) {
    digits = digits.slice(2);
  } else if (digits.length === 11 && digits.startsWith('0')) {
    digits = digits.slice(1);
  }
  return INDIAN_MOBILE.test(digits) ? `+91${digits}` : null;
}

/** "+919876543210" → "+91 ••••••3210" for logs. */
export function maskPhone(e164: string): string {
  return `${e164.slice(0, 3)} ••••••${e164.slice(-4)}`;
}
