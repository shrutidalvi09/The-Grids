import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  Req,
  Res,
  StreamableFile,
} from '@nestjs/common';
import type { RawBodyRequest } from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';
import { IsIn, IsOptional, IsString, Length, Matches } from 'class-validator';
import type { Request, Response } from 'express';
import { Auth, type AuthContext, Public, Roles } from '../auth/auth-context.js';
import { ApiError } from '../common/api-error.js';
import { LimitQuery } from '../common/queries.js';
import { Role } from '../generated/prisma/enums.js';
import { type CheckoutView, PaymentsService, type PaymentView } from './payments.service.js';

class CreateOrderDto {
  @IsString()
  @Length(1, 64)
  dueId!: string;
}

class VerifyDto {
  @IsString()
  paymentId!: string;

  @IsString()
  orderId!: string;

  @IsString()
  @Length(1, 64)
  gatewayPaymentId!: string;

  @Matches(/^[0-9a-f]{64}$/i, { message: 'signature must be a hex HMAC-SHA256' })
  signature!: string;

  /** Simulated gateway only: the method picked on the dev checkout. */
  @IsOptional()
  @IsIn(['upi', 'card', 'netbanking', 'wallet'])
  method?: string;
}

class SimulateDto {
  @IsIn(['success', 'failure'])
  outcome!: 'success' | 'failure';
}

@Controller('payments')
export class PaymentsController {
  constructor(private readonly payments: PaymentsService) {}

  @Roles(Role.OWNER, Role.TENANT)
  @Post('orders')
  createOrder(@Auth() auth: AuthContext, @Body() body: CreateOrderDto): Promise<CheckoutView> {
    return this.payments.createOrder(auth, body.dueId);
  }

  @Post('verify')
  @HttpCode(HttpStatus.OK)
  verify(@Auth() auth: AuthContext, @Body() body: VerifyDto): Promise<PaymentView> {
    return this.payments.verify(auth, body);
  }

  /** Razorpay → server. Authenticated by the X-Razorpay-Signature header. */
  @Public()
  @SkipThrottle()
  @Post('webhook')
  @HttpCode(HttpStatus.OK)
  async webhook(
    @Req() req: RawBodyRequest<Request>,
    @Headers('x-razorpay-signature') signature: string | undefined,
  ): Promise<{ ok: true }> {
    if (!req.rawBody) throw new ApiError(HttpStatus.BAD_REQUEST, 'VALIDATION_FAILED', 'Missing body');
    await this.payments.handleWebhook(req.rawBody, signature);
    return { ok: true };
  }

  /** Development only (404 when real Razorpay keys are configured). */
  @Post(':id/simulate')
  @HttpCode(HttpStatus.OK)
  simulate(@Auth() auth: AuthContext, @Param('id') id: string, @Body() body: SimulateDto) {
    return this.payments.simulate(auth, id, body.outcome);
  }

  @Get('mine')
  mine(@Auth() auth: AuthContext, @Query() query: LimitQuery): Promise<PaymentView[]> {
    return this.payments.mine(auth, query.limit);
  }

  @Get(':id')
  get(@Auth() auth: AuthContext, @Param('id') id: string): Promise<PaymentView> {
    return this.payments.get(auth, id);
  }

  @Get(':id/receipt')
  async receipt(
    @Auth() auth: AuthContext,
    @Param('id') id: string,
    @Res({ passthrough: true }) res: Response,
  ): Promise<StreamableFile> {
    const { fileName, pdf } = await this.payments.receiptPdf(auth, id);
    res.set({
      'content-type': 'application/pdf',
      'content-disposition': `attachment; filename="${fileName}"`,
      'cache-control': 'private, max-age=0',
    });
    return new StreamableFile(pdf);
  }
}
