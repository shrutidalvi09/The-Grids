import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Patch, Post } from '@nestjs/common';
import { IsOptional, IsString, Length, Matches, ValidateIf } from 'class-validator';
import { Auth, type AuthContext, Roles } from '../auth/auth-context.js';
import { ApiError } from '../common/api-error.js';
import { normalizeIndianMobile } from '../common/phone.js';
import { Role } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';

class HouseholdMemberDto {
  @IsString()
  @Length(2, 80)
  name!: string;

  /** "Wife", "Son", "Mother"… */
  @IsString()
  @Length(2, 30)
  relation!: string;

  @IsOptional()
  @ValidateIf((_, v) => v !== null && v !== '')
  @IsString()
  @Length(10, 20)
  phone?: string | null;

  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsString()
  @Matches(/^\/uploads\/[\w-]+\.(jpg|png|webp)$/, { message: 'photoUrl must come from /v1/uploads' })
  photoUrl?: string | null;
}

export interface HouseholdMemberView {
  id: string;
  name: string;
  relation: string;
  phone: string | null;
  photoUrl: string | null;
}

/** People living in the caller's flat (no Aadhaar or other ID numbers). */
@Roles(Role.OWNER, Role.TENANT)
@Controller('household')
export class HouseholdController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async list(@Auth() auth: AuthContext): Promise<HouseholdMemberView[]> {
    if (!auth.flatId) return [];
    const members = await this.prisma.householdMember.findMany({
      where: { flatId: auth.flatId },
      orderBy: { createdAt: 'asc' },
    });
    return members.map(toView);
  }

  @Post()
  async add(@Auth() auth: AuthContext, @Body() body: HouseholdMemberDto): Promise<HouseholdMemberView> {
    const flatId = this.flatOf(auth);
    const count = await this.prisma.householdMember.count({ where: { flatId } });
    if (count >= 20) throw new ApiError(HttpStatus.BAD_REQUEST, 'VALIDATION_FAILED', 'A flat can list up to 20 people');
    return toView(await this.prisma.householdMember.create({ data: { ...data(body), flatId } }));
  }

  @Patch(':id')
  async update(@Auth() auth: AuthContext, @Param('id') id: string, @Body() body: HouseholdMemberDto): Promise<HouseholdMemberView> {
    const flatId = this.flatOf(auth);
    const { count } = await this.prisma.householdMember.updateMany({ where: { id, flatId }, data: data(body) });
    if (count === 0) throw ApiError.notFound('Household member not found');
    return toView(await this.prisma.householdMember.findUniqueOrThrow({ where: { id } }));
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(@Auth() auth: AuthContext, @Param('id') id: string): Promise<void> {
    const { count } = await this.prisma.householdMember.deleteMany({ where: { id, flatId: this.flatOf(auth) } });
    if (count === 0) throw ApiError.notFound('Household member not found');
  }

  private flatOf(auth: AuthContext): string {
    if (!auth.flatId) throw ApiError.forbidden('You are not linked to a flat');
    return auth.flatId;
  }
}

function data(body: HouseholdMemberDto) {
  let phone: string | null = null;
  if (body.phone) {
    phone = normalizeIndianMobile(body.phone);
    if (!phone) {
      throw new ApiError(HttpStatus.BAD_REQUEST, 'VALIDATION_FAILED', 'Enter a valid Indian mobile number', {
        fields: ['phone must be a valid Indian mobile number'],
      });
    }
  }
  return { name: body.name.trim(), relation: body.relation.trim(), phone, photoUrl: body.photoUrl ?? null };
}

function toView(m: { id: string; name: string; relation: string; phone: string | null; photoUrl: string | null }) {
  return { id: m.id, name: m.name, relation: m.relation, phone: m.phone, photoUrl: m.photoUrl };
}
