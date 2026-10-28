import { Module } from '@nestjs/common';
import { ENV, type Env } from './config/env.js';
import { DuesScheduler } from './maintenance/dues.scheduler.js';
import { DuesService } from './maintenance/dues.service.js';
import { MaintenanceController } from './maintenance/maintenance.controller.js';
import { PaymentGateway, RazorpayGateway, SimulatedGateway } from './payments/gateway.js';
import { PaymentsController } from './payments/payments.controller.js';
import { PaymentsService } from './payments/payments.service.js';

/** Maintenance, rent, payments and receipts (Phase 4). */
@Module({
  controllers: [MaintenanceController, PaymentsController],
  providers: [
    DuesService,
    DuesScheduler,
    PaymentsService,
    {
      provide: PaymentGateway,
      inject: [ENV],
      useFactory: (env: Env) =>
        env.razorpay ? new RazorpayGateway(env.razorpay) : new SimulatedGateway(env.jwtAccessSecret),
    },
  ],
})
export class MoneyModule {}
