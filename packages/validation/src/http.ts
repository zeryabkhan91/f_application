import { z } from 'zod';

export const DEFAULT_PAGE_SIZE = 20;
export const MAX_PAGE_SIZE = 100;

export const paginationMetaSchema = z.object({
  page: z.number().int().positive(),
  pageSize: z.number().int().positive(),
  total: z.number().int().nonnegative(),
  totalPages: z.number().int().nonnegative(),
});

export function dataEnvelope<T extends z.ZodType>(data: T) {
  return z.object({ data });
}

export function listEnvelope<T extends z.ZodType>(item: T) {
  return z.object({ data: z.array(item), meta: paginationMetaSchema });
}

export const sortOrderSchema = z.enum(['asc', 'desc']);

/**
 * Standard list query (§41). Each resource declares its sortable columns so callers
 * can never sort by arbitrary fields, plus resource filters such as status or
 * customerId. Filters must be optional; unknown query parameters are ignored.
 */
export function listQuerySchema<
  const SortBy extends readonly [string, ...string[]],
  Filters extends z.ZodRawShape = Record<never, never>,
>(options: {
  sortBy: SortBy;
  defaultSortBy: SortBy[number];
  defaultSortOrder?: z.infer<typeof sortOrderSchema>;
  filters?: Filters;
}) {
  return z
    .object({
      page: z.coerce.number().int().min(1).default(1),
      pageSize: z.coerce
        .number()
        .int()
        .min(1)
        .max(MAX_PAGE_SIZE)
        .default(DEFAULT_PAGE_SIZE),
      search: z.string().trim().min(1).max(200).optional(),
      sortBy: z.enum(options.sortBy).default(options.defaultSortBy),
      sortOrder: sortOrderSchema.default(options.defaultSortOrder ?? 'desc'),
      dateFrom: z.iso.date().optional(),
      dateTo: z.iso.date().optional(),
      ...(options.filters ?? ({} as Filters)),
    })
    .refine(
      (query) => {
        // Generic filter shapes hide the base fields from inference; they are always present.
        const { dateFrom, dateTo } = query as {
          dateFrom?: string;
          dateTo?: string;
        };
        return !dateFrom || !dateTo || dateFrom <= dateTo;
      },
      { path: ['dateTo'], message: 'End date must be on or after start date' },
    );
}

/** Opaque client-generated key; a UUID v4 is recommended. */
export const idempotencyKeySchema = z
  .string()
  .regex(/^[A-Za-z0-9_.:-]{8,128}$/, 'Use 8–128 letters, digits, or _.:-');
