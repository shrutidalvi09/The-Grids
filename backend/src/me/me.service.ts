import { Injectable } from '@nestjs/common';
import { ApiError } from '../common/api-error.js';
import type { Role } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';

export interface MembershipView {
  id: string;
  role: Role;
  societyId: string;
  societyName: string;
  flatId: string | null;
  /** "Tower-C, 502" */
  flatLabel: string | null;
}

export interface MeView {
  user: {
    id: string;
    name: string;
    phone: string;
    email: string | null;
    photoUrl: string | null;
    language: string;
    theme: string;
  };
  /** The membership this session is acting as. */
  membership: MembershipView;
  /** Every society/role this person can switch to (drawer switcher). */
  memberships: MembershipView[];
}

const membershipInclude = {
  society: { select: { name: true } },
  flat: { select: { number: true, tower: { select: { name: true } } } },
} as const;

@Injectable()
export class MeService {
  constructor(private readonly prisma: PrismaService) {}

  async get(userId: string, membershipId: string): Promise<MeView> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        memberships: {
          where: { status: { in: ['INVITED', 'ACTIVE'] }, society: { isActive: true } },
          include: membershipInclude,
          orderBy: [{ societyId: 'asc' }, { role: 'asc' }],
        },
      },
    });
    if (!user) throw ApiError.unauthenticated();

    const memberships = user.memberships.map(toView);
    const membership = memberships.find((m) => m.id === membershipId);
    if (!membership) throw ApiError.unauthenticated('Membership is no longer active');

    return {
      user: {
        id: user.id,
        name: user.name,
        phone: user.phone,
        email: user.email,
        photoUrl: user.photoUrl,
        language: user.language,
        theme: user.theme,
      },
      membership,
      memberships,
    };
  }
}

function toView(m: {
  id: string;
  role: Role;
  societyId: string;
  flatId: string | null;
  society: { name: string };
  flat: { number: string; tower: { name: string } } | null;
}): MembershipView {
  return {
    id: m.id,
    role: m.role,
    societyId: m.societyId,
    societyName: m.society.name,
    flatId: m.flatId,
    flatLabel: m.flat ? `${m.flat.tower.name}, ${m.flat.number}` : null,
  };
}
