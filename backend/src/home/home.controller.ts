import { Controller, Get } from '@nestjs/common';
import { Auth, type AuthContext } from '../auth/auth-context.js';
import { HomeService, type HomeView } from './home.service.js';

@Controller('home')
export class HomeController {
  constructor(private readonly home: HomeService) {}

  /** Everything the Home tab needs for the caller's role, in one call. */
  @Get()
  get(@Auth() auth: AuthContext): Promise<HomeView> {
    return this.home.get(auth);
  }
}
