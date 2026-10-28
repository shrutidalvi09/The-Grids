import 'dotenv/config';
import { execSync } from 'node:child_process';

/** Points the suite at TEST_DATABASE_URL and applies migrations once. */
export default function setup() {
  const url = process.env.TEST_DATABASE_URL;
  if (!url) throw new Error('TEST_DATABASE_URL is not set (see .env.example)');
  if (url === process.env.DATABASE_URL) throw new Error('TEST_DATABASE_URL must differ from DATABASE_URL');

  execSync('npx prisma migrate deploy', {
    stdio: 'inherit',
    env: { ...process.env, DATABASE_URL: url },
  });
}
