import type { PageQuery, PaginationMeta } from '@repo/types';

/** `{ data }` envelope for a single resource. */
export function single<T>(data: T) {
  return { data };
}

/** Prisma skip/take for a parsed list query; pageSize is already capped by the schema. */
export function pageArgs(query: PageQuery) {
  return { skip: (query.page - 1) * query.pageSize, take: query.pageSize };
}

/** `{ data, meta }` envelope for one page of a collection. */
export function paginated<T>(
  data: T[],
  total: number,
  query: PageQuery,
): { data: T[]; meta: PaginationMeta } {
  return {
    data,
    meta: {
      page: query.page,
      pageSize: query.pageSize,
      total,
      totalPages: Math.ceil(total / query.pageSize),
    },
  };
}
