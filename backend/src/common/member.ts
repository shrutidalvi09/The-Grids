import type { AuthContext } from '../auth/auth-context.js';
import type { PrismaService } from '../prisma/prisma.service.js';

/** The tower of the caller's flat (null for admins without a flat). */
export async function towerIdOf(prisma: PrismaService, auth: AuthContext): Promise<string | null> {
  if (!auth.flatId) return null;
  const flat = await prisma.flat.findUnique({ where: { id: auth.flatId }, select: { towerId: true } });
  return flat?.towerId ?? null;
}

/**
 * Rows scoped to a tower (notices, facilities) are visible to residents of
 * that tower; rows without a tower are society-wide. Admins see everything.
 */
export async function towerScope(
  prisma: PrismaService,
  auth: AuthContext,
): Promise<{ OR?: { towerId: string | null }[] }> {
  if (auth.role === 'ADMIN') return {};
  const towerId = await towerIdOf(prisma, auth);
  return { OR: [{ towerId: null }, ...(towerId ? [{ towerId }] : [])] };
}
