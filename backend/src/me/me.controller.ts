import { Controller, Get } from '@nestjs/common';
import { Auth, type AuthContext, Everyone } from '../auth/auth-context.js';
import { MeService, type MeView } from './me.service.js';

@Everyone()
@Controller('me')
export class MeController {
  constructor(private readonly me: MeService) {}

  @Get()
  get(@Auth() auth: AuthContext): Promise<MeView> {
    return this.me.get(auth.userId, auth.membershipId);
  }
}
