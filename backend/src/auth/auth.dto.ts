import { IsEnum, IsNotEmpty, IsString, Length, Matches } from 'class-validator';
import { Role } from '../generated/prisma/enums.js';
import { OTP_LENGTH } from './otp.js';

export class RequestOtpDto {
  @IsString()
  @Length(10, 20)
  phone!: string;

  @IsString()
  @IsNotEmpty()
  societyId!: string;

  @IsEnum(Role)
  role!: Role;
}

export class VerifyOtpDto {
  @IsString()
  @IsNotEmpty()
  challengeId!: string;

  @Matches(new RegExp(`^\\d{${OTP_LENGTH}}$`), { message: `code must be ${OTP_LENGTH} digits` })
  code!: string;
}

export class RefreshTokenDto {
  @IsString()
  @Length(20, 200)
  refreshToken!: string;
}

export class SwitchMembershipDto extends RefreshTokenDto {
  @IsString()
  @IsNotEmpty()
  membershipId!: string;
}
