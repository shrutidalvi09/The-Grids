import { loadEnv } from './env.js';

const valid = {
  NODE_ENV: 'development',
  DATABASE_URL: 'mysql://u:p@127.0.0.1:3306/db',
  JWT_ACCESS_SECRET: 'a'.repeat(32),
  OTP_PEPPER: 'b'.repeat(32),
};

describe('loadEnv', () => {
  it('applies defaults', () => {
    expect(loadEnv(valid)).toMatchObject({ port: 3000, jwtAccessTtlSeconds: 900, refreshTokenTtlDays: 30, otpDevEcho: false });
  });

  it('reads the proxy hop count, defaulting to none', () => {
    expect(loadEnv(valid).trustProxyHops).toBe(0);
    expect(loadEnv({ ...valid, TRUST_PROXY_HOPS: '0' }).trustProxyHops).toBe(0);
    expect(loadEnv({ ...valid, TRUST_PROXY_HOPS: '1' }).trustProxyHops).toBe(1);
    expect(() => loadEnv({ ...valid, TRUST_PROXY_HOPS: 'yes' })).toThrow(/TRUST_PROXY_HOPS/);
  });

  it('lists every problem at once', () => {
    const error = (() => {
      try {
        loadEnv({ JWT_ACCESS_SECRET: 'short' });
      } catch (e) {
        return (e as Error).message;
      }
    })();
    expect(error).toContain('DATABASE_URL is required');
    expect(error).toContain('JWT_ACCESS_SECRET must be at least 32 characters');
    expect(error).toContain('OTP_PEPPER is required');
  });

  it('refuses dev-only OTP behaviour in production', () => {
    expect(() => loadEnv({ ...valid, NODE_ENV: 'production', OTP_DEV_ECHO: 'true' })).toThrow(/OTP_DEV_ECHO/);
    expect(() => loadEnv({ ...valid, NODE_ENV: 'production' })).toThrow(/SMS_PROVIDER=console/);
  });
});
