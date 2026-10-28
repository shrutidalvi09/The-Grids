import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ENV, type Env } from '../config/env.js';
import { MeController } from '../me/me.controller.js';
import { MeService } from '../me/me.service.js';
import { AuthController } from './auth.controller.js';
import { AuthService } from './auth.service.js';
import { ConsoleSmsSender, SmsSender } from './sms.js';
import { TokensService } from './tokens.service.js';

@Module({
  imports: [
    JwtModule.registerAsync({
      global: true,
      inject: [ENV],
      useFactory: (env: Env) => ({
        secret: env.jwtAccessSecret,
        signOptions: { algorithm: 'HS256', issuer: 'the-grids' },
        verifyOptions: { algorithms: ['HS256'], issuer: 'the-grids' },
      }),
    }),
  ],
  controllers: [AuthController, MeController],
  providers: [AuthService, TokensService, MeService, { provide: SmsSender, useClass: ConsoleSmsSender }],
  exports: [MeService],
})
export class AuthModule {}
