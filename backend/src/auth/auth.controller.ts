import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Auth, type AuthContext, Public } from './auth-context.js';
import { RefreshTokenDto, RequestOtpDto, SwitchMembershipDto, VerifyOtpDto } from './auth.dto.js';
import { AuthService, type OtpChallengeView, type SessionView } from './auth.service.js';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Public()
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('otp/request')
  @HttpCode(HttpStatus.OK)
  requestOtp(@Body() body: RequestOtpDto): Promise<OtpChallengeView> {
    return this.auth.requestOtp(body);
  }

  @Public()
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('otp/verify')
  @HttpCode(HttpStatus.OK)
  verifyOtp(@Body() body: VerifyOtpDto): Promise<SessionView> {
    return this.auth.verifyOtp(body);
  }

  @Public()
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  refresh(@Body() body: RefreshTokenDto): Promise<SessionView> {
    return this.auth.refresh(body.refreshToken);
  }

  @Public()
  @Post('logout')
  @HttpCode(HttpStatus.NO_CONTENT)
  async logout(@Body() body: RefreshTokenDto): Promise<void> {
    await this.auth.logout(body.refreshToken);
  }

  @Post('switch')
  @HttpCode(HttpStatus.OK)
  switch(@Auth() auth: AuthContext, @Body() body: SwitchMembershipDto): Promise<SessionView> {
    return this.auth.switchMembership(auth, body);
  }
}
