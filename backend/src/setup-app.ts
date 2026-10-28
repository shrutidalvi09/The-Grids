import path from 'node:path';
import { type INestApplication, ValidationPipe } from '@nestjs/common';
import type { NestExpressApplication } from '@nestjs/platform-express';
import express from 'express';
import helmet from 'helmet';
import { ENV, type Env } from './config/env.js';

/** Shared by main.ts and the e2e tests so both run the same pipeline. */
export function setupApp(app: INestApplication): INestApplication {
  const env = app.get<Env>(ENV);
  // Behind a load balancer every request would otherwise share its IP, and the
  // per-IP OTP and request limits would throttle everyone together.
  if (env.trustProxyHops > 0) (app as NestExpressApplication).set('trust proxy', env.trustProxyHops);
  app.use(helmet());
  // Uploaded photos. Names are random, files are immutable.
  app.use(
    '/uploads',
    express.static(path.resolve(env.uploadsDir), { index: false, fallthrough: false, immutable: true, maxAge: '30d' }),
  );
  app.setGlobalPrefix('v1', { exclude: ['health'] });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );
  app.enableShutdownHooks();
  return app;
}
