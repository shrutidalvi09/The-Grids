import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';

/** Prisma `select` for rendering "Tower-C, 502". */
export const flatLabelSelect = { number: true, tower: { select: { name: true } } } as const;

export function flatLabel(flat: { number: string; tower: { name: string } } | null | undefined): string | null {
  return flat ? `${flat.tower.name}, ${flat.number}` : null;
}

/** `?limit=` for list endpoints (the Tower tab asks for the top 3). */
export class LimitQuery {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;
}
