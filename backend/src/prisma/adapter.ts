import { PrismaMariaDb } from '@prisma/adapter-mariadb';

/** Builds the MariaDB-driver adapter Prisma 7 uses to talk to MySQL. */
export function createAdapter(databaseUrl: string): PrismaMariaDb {
  const url = new URL(databaseUrl);
  return new PrismaMariaDb({
    host: url.hostname,
    port: Number(url.port || 3306),
    user: decodeURIComponent(url.username),
    password: decodeURIComponent(url.password),
    database: url.pathname.replace(/^\//, ''),
    connectionLimit: 10,
    // MySQL 8 defaults to caching_sha2_password; without TLS the driver must
    // fetch the server's public key. Fine for localhost; use TLS in production.
    allowPublicKeyRetrieval: true,
  });
}
