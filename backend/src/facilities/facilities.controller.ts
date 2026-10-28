import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Patch, Post, Query } from '@nestjs/common';
import { Type } from 'class-transformer';
import {
  IsDate,
  IsInt,
  IsOptional,
  IsString,
  Length,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { Auth, type AuthContext, Roles } from '../auth/auth-context.js';
import { ISO_DATE, TIME_OF_DAY } from '../common/zoned-time.js';
import { Role } from '../generated/prisma/enums.js';
import { type BookingView, FacilitiesService, type FacilityView, type SlotView } from './facilities.service.js';

class FacilityDto {
  @IsString()
  @Length(2, 60)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string | null;

  @IsOptional()
  @IsString()
  @Matches(/^\/uploads\/[\w-]+\.(jpg|png|webp)$/, { message: 'photoUrl must come from /v1/uploads' })
  photoUrl?: string | null;

  @Matches(TIME_OF_DAY, { message: 'openTime must be HH:mm' })
  openTime!: string;

  @Matches(TIME_OF_DAY, { message: 'closeTime must be HH:mm' })
  closeTime!: string;

  @IsInt()
  @Min(15)
  @Max(480)
  maxDurationMins!: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(500)
  capacity?: number | null;
}

class SlotsQuery {
  @Matches(ISO_DATE, { message: 'date must be YYYY-MM-DD' })
  date!: string;
}

class BookDto {
  @Type(() => Date)
  @IsDate()
  startsAt!: Date;
}

@Controller()
export class FacilitiesController {
  constructor(private readonly facilities: FacilitiesService) {}

  @Get('facilities')
  list(@Auth() auth: AuthContext): Promise<FacilityView[]> {
    return this.facilities.list(auth);
  }

  @Roles(Role.ADMIN)
  @Post('facilities')
  create(@Auth() auth: AuthContext, @Body() body: FacilityDto): Promise<{ id: string }> {
    return this.facilities.create(auth, body);
  }

  @Roles(Role.ADMIN)
  @Patch('facilities/:id')
  update(@Auth() auth: AuthContext, @Param('id') id: string, @Body() body: FacilityDto): Promise<{ id: string }> {
    return this.facilities.update(auth, id, body);
  }

  @Get('facilities/:id/slots')
  slots(@Auth() auth: AuthContext, @Param('id') id: string, @Query() query: SlotsQuery): Promise<SlotView[]> {
    return this.facilities.slots(auth, id, query.date);
  }

  @Post('facilities/:id/bookings')
  book(@Auth() auth: AuthContext, @Param('id') id: string, @Body() body: BookDto): Promise<BookingView> {
    return this.facilities.book(auth, id, body.startsAt);
  }

  @Get('bookings/mine')
  mine(@Auth() auth: AuthContext): Promise<BookingView[]> {
    return this.facilities.mine(auth);
  }

  @Delete('bookings/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async cancel(@Auth() auth: AuthContext, @Param('id') id: string): Promise<void> {
    await this.facilities.cancel(auth, id);
  }
}
