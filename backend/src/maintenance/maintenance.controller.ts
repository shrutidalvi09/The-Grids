import { Body, Controller, Get, HttpCode, HttpStatus, Param, Patch, Post, Put, Query } from '@nestjs/common';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsDate,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Length,
  Matches,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { Auth, type AuthContext, Roles } from '../auth/auth-context.js';
import { BillStatus, Role } from '../generated/prisma/enums.js';
import {
  type DefaulterView,
  DuesService,
  type DueView,
  type MaintenanceConfigView,
  type SocietyBillView,
} from './dues.service.js';

class ItemDto {
  @IsString()
  @Length(2, 40)
  label!: string;

  /** Paise; ₹1 to ₹1,00,000 per line. */
  @IsInt()
  @Min(100)
  @Max(10_000_000)
  amountPaise!: number;
}

class ConfigDto {
  @ValidateNested({ each: true })
  @Type(() => ItemDto)
  @ArrayMinSize(1)
  @ArrayMaxSize(20)
  items!: ItemDto[];

  @IsInt()
  @Min(1)
  @Max(28)
  dueDay!: number;
}

class GenerateDto {
  @IsOptional()
  @Matches(/^\d{4}-(0[1-9]|1[0-2])$/, { message: 'period must be YYYY-MM' })
  period?: string;
}

class BillsQuery {
  @IsOptional()
  @IsEnum(BillStatus)
  status?: BillStatus;
}

class BillDto {
  @IsString()
  @Length(2, 80)
  vendor!: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  category?: string;

  @IsInt()
  @Min(100)
  @Max(1_000_000_000)
  amountPaise!: number;

  @Type(() => Date)
  @IsDate()
  dueDate!: Date;
}

@Controller()
export class MaintenanceController {
  constructor(private readonly dues: DuesService) {}

  @Get('dues/mine')
  mine(@Auth() auth: AuthContext): Promise<DueView[]> {
    return this.dues.mine(auth);
  }

  @Get('maintenance/config')
  config(@Auth() auth: AuthContext): Promise<MaintenanceConfigView> {
    return this.dues.config(auth.societyId);
  }

  @Roles(Role.ADMIN)
  @Put('maintenance/config')
  updateConfig(@Auth() auth: AuthContext, @Body() body: ConfigDto): Promise<MaintenanceConfigView> {
    return this.dues.updateConfig(auth.societyId, body);
  }

  @Roles(Role.ADMIN)
  @Post('maintenance/dues/generate')
  @HttpCode(HttpStatus.OK)
  generate(@Auth() auth: AuthContext, @Body() body: GenerateDto) {
    return this.dues.generate(auth.societyId, body.period);
  }

  @Roles(Role.ADMIN)
  @Get('maintenance/summary')
  summary(@Auth() auth: AuthContext) {
    return this.dues.summary(auth.societyId);
  }

  @Roles(Role.ADMIN)
  @Get('maintenance/defaulters')
  defaulters(@Auth() auth: AuthContext): Promise<DefaulterView[]> {
    return this.dues.defaulters(auth.societyId);
  }

  @Roles(Role.ADMIN)
  @Post('maintenance/defaulters/:flatId/remind')
  @HttpCode(HttpStatus.OK)
  remind(@Auth() auth: AuthContext, @Param('flatId') flatId: string) {
    return this.dues.remind(auth.societyId, flatId);
  }

  @Roles(Role.ADMIN)
  @Get('society-bills')
  bills(@Auth() auth: AuthContext, @Query() query: BillsQuery): Promise<SocietyBillView[]> {
    return this.dues.bills(auth.societyId, query.status);
  }

  @Roles(Role.ADMIN)
  @Post('society-bills')
  addBill(@Auth() auth: AuthContext, @Body() body: BillDto) {
    return this.dues.addBill(auth.societyId, body);
  }

  @Roles(Role.ADMIN)
  @Patch('society-bills/:id/paid')
  @HttpCode(HttpStatus.NO_CONTENT)
  async markPaid(@Auth() auth: AuthContext, @Param('id') id: string): Promise<void> {
    await this.dues.markBillPaid(auth.societyId, id);
  }
}
