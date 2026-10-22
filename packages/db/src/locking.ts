import type { OrganizationContext } from '@repo/types';
import { z } from '@repo/validation';
import { Prisma } from './generated/prisma/client.js';

export class RecordNotFoundError extends Error {
  constructor(public readonly table: string) {
    super(`One or more ${table} records were not found in this organization`);
    this.name = 'RecordNotFoundError';
  }
}

/** Identifiers cannot be bound parameters, so only these reviewed table names are accepted. */
export const lockableTables = [
  'customers',
  'suppliers',
  'raw_materials',
  'products',
  'warehouses',
  'purchase_orders',
  'purchase_order_items',
  'goods_receipts',
  'supplier_invoices',
  'supplier_payments',
  'sales_orders',
  'sales_order_items',
  'sales_invoices',
  'customer_payments',
  'payment_schedules',
  'payment_installments',
  'production_orders',
  'dispatches',
  'inventory_balances',
  'expenses',
] as const;
export type LockableTable = (typeof lockableTables)[number];

const idsSchema = z.array(z.uuid());

/**
 * Takes row locks with SELECT … FOR UPDATE in ascending ID order. Every workflow
 * locking several rows of a table acquires them in the same order, so concurrent
 * payments or postings wait for each other instead of deadlocking. Locks last
 * until the surrounding transaction ends. Missing or out-of-scope rows raise
 * RecordNotFoundError unless requireAll is false.
 */
export async function lockRows(
  tx: Prisma.TransactionClient,
  context: OrganizationContext,
  table: LockableTable,
  ids: readonly string[],
  options: { requireAll?: boolean } = {},
): Promise<string[]> {
  if (!lockableTables.includes(table))
    throw new Error(`Table ${String(table)} is not lockable`);
  const parsed = idsSchema.safeParse([...new Set(ids)]);
  if (!parsed.success) throw new RecordNotFoundError(table);
  const unique = parsed.data;
  if (unique.length === 0) return [];
  const rows = await tx.$queryRaw<Array<{ id: string }>>`
    SELECT id::text AS id FROM ${Prisma.raw(`"${table}"`)}
    WHERE tenant_id = ${context.tenantId}::uuid
      AND organization_id = ${context.organizationId}::uuid
      AND id = ANY(${unique}::uuid[])
    ORDER BY id
    FOR UPDATE
  `;
  if ((options.requireAll ?? true) && rows.length !== unique.length)
    throw new RecordNotFoundError(table);
  return rows.map((row) => row.id);
}
