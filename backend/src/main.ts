import 'dotenv/config';
import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module.js';
import { loadEnv } from './config/env.js';
import { setupApp } from './setup-app.js';

async function bootstrap() {
  const env = loadEnv(); // fail fast on bad config, before Nest boots
  // rawBody: Razorpay webhooks are verified over the exact bytes received.
  const app = setupApp(await NestFactory.create(AppModule, { rawBody: true }));
  // 0.0.0.0 so the Android emulator can reach it via 10.0.2.2.
  await app.listen(env.port, '0.0.0.0');
  Logger.log(`API listening on http://localhost:${env.port}/v1 (${env.nodeEnv})`, 'Bootstrap');
}
await bootstrap();
