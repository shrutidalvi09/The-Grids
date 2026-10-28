/**
 * Typed, validated environment. The app refuses to start on bad config
 * rather than failing later at request time.
 */
export interface Env {
  nodeEnv: 'development' | 'test' | 'production';
  port: number;
  databaseUrl: string;
  jwtAccessSecret: string;
  jwtAccessTtlSeconds: number;
  refreshTokenTtlDays: number;
  otpPepper: string;
  smsProvider: 'console';
  /** Dev only: include the OTP in the API response. Forbidden in production. */
  otpDevEcho: boolean;
  /** Where uploaded photos are stored (local disk for now). */
  uploadsDir: string;
  /** Where generated PDF receipts are stored (never served publicly). */
  receiptsDir: string;
  /**
   * Razorpay credentials. Without a key id, development uses a simulated
   * gateway (refused in production).
   */
  razorpay: { keyId: string; keySecret: string; webhookSecret: string } | null;
  /**
   * Firebase service-account JSON file for push notifications (FCM). Without
   * it, notifications are still saved in-app and pushes are only logged.
   */
  firebaseServiceAccountFile: string | null;
  /**
   * Reverse proxies / load balancers in front of the API (Express "trust
   * proxy" hop count). Needed in production so rate limits see the client's
   * IP rather than the proxy's; 0 when clients connect directly.
   */
  trustProxyHops: number;
}

export function loadEnv(source: NodeJS.ProcessEnv = process.env): Env {
  const errors: string[] = [];

  const str = (key: string): string => {
    const value = source[key]?.trim();
    if (!value) errors.push(`${key} is required`);
    return value ?? '';
  };
  const int = (key: string, fallback: number): number => {
    const raw = source[key];
    if (raw === undefined || raw === '') return fallback;
    const value = Number(raw);
    if (!Number.isInteger(value) || value <= 0) errors.push(`${key} must be a positive integer`);
    return value;
  };

  const nodeEnv = (source.NODE_ENV ?? 'development') as Env['nodeEnv'];
  if (!['development', 'test', 'production'].includes(nodeEnv)) {
    errors.push('NODE_ENV must be development, test or production');
  }

  const jwtAccessSecret = str('JWT_ACCESS_SECRET');
  if (jwtAccessSecret && jwtAccessSecret.length < 32) {
    errors.push('JWT_ACCESS_SECRET must be at least 32 characters');
  }
  const otpPepper = str('OTP_PEPPER');
  if (otpPepper && otpPepper.length < 32) {
    errors.push('OTP_PEPPER must be at least 32 characters');
  }

  const smsProvider = (source.SMS_PROVIDER ?? 'console') as Env['smsProvider'];
  if (smsProvider !== 'console') errors.push('SMS_PROVIDER must be "console" (no real provider configured yet)');

  const otpDevEcho = source.OTP_DEV_ECHO === 'true';
  if (otpDevEcho && nodeEnv === 'production') errors.push('OTP_DEV_ECHO must not be enabled in production');
  if (smsProvider === 'console' && nodeEnv === 'production') {
    errors.push('SMS_PROVIDER=console cannot be used in production');
  }

  const keyId = source.RAZORPAY_KEY_ID?.trim() ?? '';
  const keySecret = source.RAZORPAY_KEY_SECRET?.trim() ?? '';
  const webhookSecret = source.RAZORPAY_WEBHOOK_SECRET?.trim() ?? '';
  if (keyId && !keySecret) errors.push('RAZORPAY_KEY_SECRET is required when RAZORPAY_KEY_ID is set');
  if (keyId && !/^rzp_(test|live)_\w+$/.test(keyId)) errors.push('RAZORPAY_KEY_ID must look like rzp_test_… or rzp_live_…');
  if (nodeEnv === 'production' && (!keyId || !webhookSecret)) {
    errors.push('Razorpay keys and RAZORPAY_WEBHOOK_SECRET are required in production (no simulated payments)');
  }

  const env: Env = {
    nodeEnv,
    port: int('PORT', 3000),
    databaseUrl: str('DATABASE_URL'),
    jwtAccessSecret,
    jwtAccessTtlSeconds: int('JWT_ACCESS_TTL_SECONDS', 900),
    refreshTokenTtlDays: int('REFRESH_TOKEN_TTL_DAYS', 30),
    otpPepper,
    smsProvider,
    otpDevEcho,
    uploadsDir: source.UPLOADS_DIR?.trim() || 'uploads',
    receiptsDir: source.RECEIPTS_DIR?.trim() || 'storage/receipts',
    razorpay: keyId ? { keyId, keySecret, webhookSecret } : null,
    firebaseServiceAccountFile: source.FIREBASE_SERVICE_ACCOUNT_FILE?.trim() || null,
    trustProxyHops: (source.TRUST_PROXY_HOPS ?? '0').trim() === '0' ? 0 : int('TRUST_PROXY_HOPS', 0),
  };

  if (errors.length) {
    throw new Error(`Invalid environment:\n  - ${errors.join('\n  - ')}`);
  }
  return env;
}

export const ENV = Symbol('ENV');
