import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  withOrganization,
  requirePermission,
  nextDocumentNumber,
  OrganizationAccessDeniedError,
  UnsafeDatabaseRoleError,
  PermissionDeniedError,
  type Prisma,
} from '../src/index.js';
import type { OrganizationSelection } from '@repo/types';
import { ensureOrganizationDefaults } from '../src/seeds/organization-defaults.js';
import { seedDevelopmentDemo } from '../src/seeds/demo.js';
import { createTestDatabase } from './helpers/database.js';

type Fixture = {
  scope: OrganizationSelection;
  customerId: string;
  otherCustomerId: string;
  supplierId: string;
  otherSupplierId: string;
  warehouseId: string;
  materialId: string;
  productId: string;
  roleId: string;
};
let database: Awaited<ReturnType<typeof createTestDatabase>>;
let a: Fixture;
let branch: Fixture;
let b: Fixture;
const date = new Date('2026-10-22T00:00:00.000Z');

async function fixture(
  options: { tenantId?: string; userId?: string } = {},
): Promise<Fixture> {
  return database.admin.$transaction(
    async (tx) => {
      const suffix = randomUUID();
      const userId =
        options.userId ??
        (
          await tx.user.create({
            data: {
              name: 'Integration Actor',
              email: `${suffix}@test.invalid`,
              status: 'ACTIVE',
              passwordHash: 'test-only-unusable-authentication-hash',
            },
          })
        ).id;
      const tenantId =
        options.tenantId ??
        (
          await tx.tenant.create({
            data: { name: 'Integration Account', slug: suffix },
          })
        ).id;
      const organization = await tx.organization.create({
        data: { tenantId, name: 'Integration Factory', slug: suffix },
      });
      const scope = { tenantId, organizationId: organization.id, userId };
      const ownership = { tenantId, organizationId: organization.id };
      await ensureOrganizationDefaults(tx, ownership, userId);
      const customer = await tx.customer.create({
        data: { ...ownership, name: 'Customer', createdBy: userId },
      });
      const otherCustomer = await tx.customer.create({
        data: { ...ownership, name: 'Other Customer' },
      });
      const supplier = await tx.supplier.create({
        data: { ...ownership, name: 'Supplier' },
      });
      const otherSupplier = await tx.supplier.create({
        data: { ...ownership, name: 'Other Supplier' },
      });
      const unit = await tx.unit.findFirstOrThrow({
        where: { ...ownership, code: 'KG' },
      });
      const material = await tx.rawMaterial.create({
        data: {
          ...ownership,
          unitId: unit.id,
          name: 'Material',
          sku: 'RAW-001',
        },
      });
      const product = await tx.product.create({
        data: {
          ...ownership,
          unitId: unit.id,
          name: 'Product',
          sku: 'PRODUCT-001',
        },
      });
      const warehouse = await tx.warehouse.findFirstOrThrow({
        where: { ...ownership, isDefault: true },
      });
      const role = await tx.role.findFirstOrThrow({
        where: { ...ownership, code: 'OWNER' },
      });
      return {
        scope,
        customerId: customer.id,
        otherCustomerId: otherCustomer.id,
        supplierId: supplier.id,
        otherSupplierId: otherSupplier.id,
        warehouseId: warehouse.id,
        materialId: material.id,
        productId: product.id,
        roleId: role.id,
      };
    },
    { timeout: 30_000 },
  );
}

const ownership = (f: Fixture) => ({
  tenantId: f.scope.tenantId,
  organizationId: f.scope.organizationId,
});
const invoice = (tx: Prisma.TransactionClient, f: Fixture, total = '100.00') =>
  tx.salesInvoice.create({
    data: {
      ...ownership(f),
      customerId: f.customerId,
      invoiceNumber: randomUUID(),
      invoiceDate: date,
      dueDate: date,
      subtotal: total,
      total,
      status: 'UNPAID',
    },
  });
const scoped = <T>(
  f: Fixture,
  work: Parameters<typeof withOrganization<T>>[2],
) => withOrganization(database.runtime, f.scope, work);

beforeAll(async () => {
  database = await createTestDatabase();
  a = await fixture();
  branch = await fixture({
    tenantId: a.scope.tenantId,
    userId: a.scope.userId,
  });
  b = await fixture();
}, 60_000);
afterAll(async () => {
  if (database) await database.dispose();
}, 30_000);

describe('migrations and tenancy', () => {
  it('replays migrations from an empty database and forces RLS on all owned tables', async () => {
    const counts = await database.admin.$queryRaw<
      Array<{ tables: bigint; isolated: bigint }>
    >`
      SELECT COUNT(*) AS tables, COUNT(*) FILTER (WHERE c.relrowsecurity AND c.relforcerowsecurity) AS isolated
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.relname <> '_prisma_migrations'
    `;
    expect(counts[0]).toEqual({ tables: 51n, isolated: 47n });
    const roles = await database.runtime.$queryRaw<
      Array<{ rolsuper: boolean; rolbypassrls: boolean }>
    >`SELECT rolsuper, rolbypassrls FROM pg_roles WHERE rolname = current_user`;
    expect(roles[0]).toEqual({ rolsuper: false, rolbypassrls: false });
  });

  it('fails closed without organization context', async () => {
    expect(await database.runtime.customer.findMany()).toEqual([]);
    expect(await database.runtime.organization.findMany()).toEqual([]);
    await expect(
      database.runtime.$queryRaw`SELECT * FROM _prisma_migrations`,
    ).rejects.toThrow();
  });

  it('isolates different tenants and organizations within the same tenant', async () => {
    for (const f of [a, branch, b]) {
      const customers = await scoped(f, (tx) => tx.customer.findMany());
      expect(customers.map((c) => c.id).sort()).toEqual(
        [f.customerId, f.otherCustomerId].sort(),
      );
      expect(
        customers.every(
          (c) =>
            c.tenantId === f.scope.tenantId &&
            c.organizationId === f.scope.organizationId,
        ),
      ).toBe(true);
    }
  });

  it('rejects mismatched scope, non-members, and privileged database clients', async () => {
    await expect(
      withOrganization(
        database.runtime,
        { ...b.scope, userId: a.scope.userId },
        async () => true,
      ),
    ).rejects.toBeInstanceOf(OrganizationAccessDeniedError);
    await expect(
      withOrganization(
        database.runtime,
        { ...a.scope, organizationId: b.scope.organizationId },
        async () => true,
      ),
    ).rejects.toBeInstanceOf(OrganizationAccessDeniedError);
    await expect(
      withOrganization(database.admin, a.scope, async () => true),
    ).rejects.toBeInstanceOf(UnsafeDatabaseRoleError);
    await expect(
      withOrganization(
        database.runtime,
        { ...a.scope, permissions: ['tenant.write'] },
        async () => true,
      ),
    ).rejects.toThrow();
  });

  it('rejects inherited administrative role privileges', async () => {
    const [admin] = await database.admin.$queryRaw<
      Array<{ name: string }>
    >`SELECT current_user AS name`;
    const [runtime] = await database.runtime.$queryRaw<
      Array<{ name: string }>
    >`SELECT current_user AS name`;
    if (!admin || !runtime) throw new Error('Could not resolve test roles');
    const quote = (value: string) => `"${value.replaceAll('"', '""')}"`;
    await database.admin.$executeRawUnsafe(
      `GRANT ${quote(admin.name)} TO ${quote(runtime.name)}`,
    );
    try {
      await expect(scoped(a, async () => true)).rejects.toBeInstanceOf(
        UnsafeDatabaseRoleError,
      );
    } finally {
      await database.admin.$executeRawUnsafe(
        `REVOKE ${quote(admin.name)} FROM ${quote(runtime.name)}`,
      );
    }
  });

  it.each(['membership', 'role', 'user', 'organization', 'tenant'] as const)(
    'rejects an inactive %s',
    async (kind) => {
      const mutate = async (active: boolean) => {
        if (kind === 'membership')
          return database.admin.membership.update({
            where: { tenantId_organizationId_userId: a.scope },
            data: { status: active ? 'ACTIVE' : 'SUSPENDED' },
          });
        if (kind === 'role')
          return database.admin.role.update({
            where: { id: a.roleId },
            data: { status: active ? 'ACTIVE' : 'INACTIVE' },
          });
        if (kind === 'user')
          return database.admin.user.update({
            where: { id: a.scope.userId },
            data: { status: active ? 'ACTIVE' : 'SUSPENDED' },
          });
        if (kind === 'organization')
          return database.admin.organization.update({
            where: { id: a.scope.organizationId },
            data: { status: active ? 'ACTIVE' : 'INACTIVE' },
          });
        return database.admin.tenant.update({
          where: { id: a.scope.tenantId },
          data: { status: active ? 'ACTIVE' : 'SUSPENDED' },
        });
      };
      await mutate(false);
      try {
        await expect(scoped(a, async () => true)).rejects.toBeInstanceOf(
          OrganizationAccessDeniedError,
        );
      } finally {
        await mutate(true);
      }
    },
  );

  it('loads permissions from role mappings and freezes the server context', async () => {
    await scoped(a, async (_tx, context) => {
      expect(context.permissions).toContain('customer.write');
      expect(Object.isFrozen(context)).toBe(true);
      expect(Object.isFrozen(context.permissions)).toBe(true);
      expect(() => requirePermission(context, 'customer.write')).not.toThrow();
    });
    const user = await database.admin.user.create({
      data: {
        name: 'Viewer',
        email: `${randomUUID()}@test.invalid`,
        status: 'ACTIVE',
        passwordHash: 'test-only-unusable-authentication-hash',
      },
    });
    const role = await database.admin.role.findFirstOrThrow({
      where: { ...ownership(a), code: 'VIEWER' },
    });
    await database.admin.membership.create({
      data: { ...ownership(a), userId: user.id, roleId: role.id },
    });
    await withOrganization(
      database.runtime,
      { ...a.scope, userId: user.id },
      async (_tx, context) => {
        requirePermission(context, 'customer.read');
        expect(() => requirePermission(context, 'customer.write')).toThrow(
          PermissionDeniedError,
        );
      },
    );
  });

  it('does not leak scope through pooled connections after commits or rollbacks', async () => {
    await Promise.all(
      [a, b, branch, a, b, branch].map((f) =>
        scoped(f, async (tx) => {
          const rows = await tx.customer.findMany();
          expect(
            rows.every((r) => r.organizationId === f.scope.organizationId),
          ).toBe(true);
        }),
      ),
    );
    await expect(
      scoped(a, async () => {
        throw new Error('Rollback scope');
      }),
    ).rejects.toThrow('Rollback scope');
    expect(await database.runtime.customer.findMany()).toEqual([]);
  });

  it('blocks cross-scope inserts, ownership changes and cross-organization foreign keys', async () => {
    await expect(
      scoped(a, (tx) =>
        tx.customer.create({ data: { ...ownership(b), name: 'Wrong tenant' } }),
      ),
    ).rejects.toThrow();
    await expect(
      scoped(a, (tx) =>
        tx.customer.update({
          where: { id: a.customerId },
          data: { organizationId: branch.scope.organizationId },
        }),
      ),
    ).rejects.toThrow();
    await expect(
      scoped(a, (tx) =>
        tx.salesOrder.create({
          data: {
            ...ownership(a),
            customerId: b.customerId,
            orderNumber: randomUUID(),
            orderDate: date,
          },
        }),
      ),
    ).rejects.toMatchObject({ code: 'P2003' });
    await expect(
      scoped(a, (tx) =>
        tx.customer.update({
          where: { id: b.customerId },
          data: { name: 'Invisible row' },
        }),
      ),
    ).rejects.toMatchObject({ code: 'P2025' });
  });
});

describe('relational and financial integrity', () => {
  it('uses organization-scoped SKUs and case-insensitive global user emails', async () => {
    expect(a.materialId).not.toBe(branch.materialId);
    const material = await scoped(a, (tx) =>
      tx.rawMaterial.findUniqueOrThrow({ where: { id: a.materialId } }),
    );
    await expect(
      scoped(a, (tx) =>
        tx.rawMaterial.create({
          data: {
            ...ownership(a),
            name: 'Duplicate',
            sku: 'raw-001',
            unitId: material.unitId,
          },
        }),
      ),
    ).rejects.toMatchObject({ code: 'P2002' });
    const user = await database.admin.user.findUniqueOrThrow({
      where: { id: a.scope.userId },
    });
    await expect(
      database.admin.user.create({
        data: { name: 'Duplicate email', email: user.email.toUpperCase() },
      }),
    ).rejects.toMatchObject({ code: 'P2002' });
  });

  it('preserves exact decimal money and quantities and rejects invalid row totals', async () => {
    const result = await scoped(a, async (tx) => {
      const row = await invoice(tx, a, '0.30');
      const line = await tx.salesInvoiceItem.create({
        data: {
          ...ownership(a),
          salesInvoiceId: row.id,
          productId: a.productId,
          quantity: '2.0000',
          unitPrice: '0.15',
          lineTotal: '0.30',
        },
      });
      return { row, line };
    });
    expect(result.row.total.toFixed(2)).toBe('0.30');
    expect(result.line.quantity.toFixed(4)).toBe('2.0000');
    await expect(
      scoped(a, (tx) =>
        tx.salesInvoice.update({
          where: { id: result.row.id },
          data: { total: '0.31' },
        }),
      ),
    ).rejects.toThrow();
    await expect(
      scoped(a, (tx) =>
        tx.salesInvoiceItem.create({
          data: {
            ...ownership(a),
            salesInvoiceId: result.row.id,
            productId: a.productId,
            quantity: '0',
            unitPrice: '1.00',
            lineTotal: '0.00',
          },
        }),
      ),
    ).rejects.toThrow();
  });

  it('prevents payment allocations to a different customer or supplier', async () => {
    const sale = await scoped(a, (tx) => invoice(tx, a));
    const payment = await scoped(a, (tx) =>
      tx.customerPayment.create({
        data: {
          ...ownership(a),
          customerId: a.otherCustomerId,
          paymentNumber: randomUUID(),
          paymentDate: date,
          paymentMethod: 'CASH',
          amount: '10.00',
        },
      }),
    );
    await expect(
      scoped(a, (tx) =>
        tx.customerPaymentAllocation.create({
          data: {
            ...ownership(a),
            customerPaymentId: payment.id,
            customerId: a.otherCustomerId,
            salesInvoiceId: sale.id,
            amount: '10.00',
          },
        }),
      ),
    ).rejects.toMatchObject({ code: 'P2003' });
    const purchase = await scoped(a, (tx) =>
      tx.supplierInvoice.create({
        data: {
          ...ownership(a),
          supplierId: a.supplierId,
          supplierInvoiceNumber: randomUUID(),
          internalReference: randomUUID(),
          invoiceDate: date,
          dueDate: date,
          subtotal: '10.00',
          total: '10.00',
        },
      }),
    );
    const supplierPayment = await scoped(a, (tx) =>
      tx.supplierPayment.create({
        data: {
          ...ownership(a),
          supplierId: a.otherSupplierId,
          paymentNumber: randomUUID(),
          paymentDate: date,
          paymentMethod: 'CASH',
          amount: '10.00',
        },
      }),
    );
    await expect(
      scoped(a, (tx) =>
        tx.supplierPaymentAllocation.create({
          data: {
            ...ownership(a),
            supplierPaymentId: supplierPayment.id,
            supplierInvoiceId: purchase.id,
            supplierId: a.otherSupplierId,
            amount: '10.00',
          },
        }),
      ),
    ).rejects.toMatchObject({ code: 'P2003' });
  });

  it('derives receivables from invoices and valid payments without counting installments twice', async () => {
    const sale = await scoped(a, async (tx) => {
      const row = await invoice(tx, a);
      const payment = await tx.customerPayment.create({
        data: {
          ...ownership(a),
          customerId: a.customerId,
          paymentNumber: randomUUID(),
          paymentDate: date,
          paymentMethod: 'CASH',
          amount: '30.00',
        },
      });
      await tx.customerPaymentAllocation.create({
        data: {
          ...ownership(a),
          customerId: a.customerId,
          customerPaymentId: payment.id,
          salesInvoiceId: row.id,
          amount: '30.00',
        },
      });
      const schedule = await tx.paymentSchedule.create({
        data: {
          ...ownership(a),
          salesInvoiceId: row.id,
          scheduleType: 'MONTHLY',
          numberOfInstallments: 2,
          scheduledAmount: '70.00',
          startDate: date,
        },
      });
      await tx.paymentInstallment.createMany({
        data: [1, 2].map((n) => ({
          ...ownership(a),
          paymentScheduleId: schedule.id,
          salesInvoiceId: row.id,
          installmentNumber: n,
          dueDate: date,
          amount: '35.00',
        })),
      });
      return { row, payment };
    });
    const balances = () =>
      scoped(
        a,
        (tx) =>
          tx.$queryRaw<
            Array<{ paid_amount: unknown; balance_amount: unknown }>
          >`SELECT paid_amount, balance_amount FROM customer_invoice_balances WHERE invoice_id = ${sale.row.id}::uuid`,
      );
    const paid = (await balances())[0];
    expect(String(paid?.paid_amount)).toBe('30');
    expect(String(paid?.balance_amount)).toBe('70');
    await scoped(a, (tx) =>
      tx.customerPayment.update({
        where: { id: sale.payment.id },
        data: {
          status: 'VOID',
          voidedAt: new Date(),
          voidedBy: a.scope.userId,
          voidReason: 'Integration test reversal',
        },
      }),
    );
    expect(String((await balances())[0]?.balance_amount)).toBe('100');
    const hidden = await scoped(
      b,
      (tx) =>
        tx.$queryRaw`SELECT * FROM customer_invoice_balances WHERE invoice_id = ${sale.row.id}::uuid`,
    );
    expect(hidden).toEqual([]);
  });

  it('requires void metadata and prevents hard-deleting financial documents', async () => {
    const row = await scoped(a, (tx) => invoice(tx, a));
    for (const reason of [null, '', '   ']) {
      await expect(
        scoped(a, (tx) =>
          tx.salesInvoice.update({
            where: { id: row.id },
            data: {
              status: 'VOID',
              voidedAt: new Date(),
              voidedBy: a.scope.userId,
              voidReason: reason,
            },
          }),
        ),
      ).rejects.toThrow();
    }
    await expect(
      scoped(a, (tx) => tx.salesInvoice.delete({ where: { id: row.id } })),
    ).rejects.toThrow();
  });

  it('allocates unique sequence numbers concurrently and rolls increments back with the transaction', async () => {
    const values = await Promise.all(
      Array.from({ length: 8 }, () =>
        scoped(a, (tx, context) => nextDocumentNumber(tx, context, 'ORDER')),
      ),
    );
    expect(new Set(values).size).toBe(8);
    expect(values.sort()).toEqual(
      Array.from(
        { length: 8 },
        (_, i) => `ORD-${String(i + 1).padStart(6, '0')}`,
      ),
    );
    await expect(
      scoped(a, async (tx, context) => {
        await nextDocumentNumber(tx, context, 'ORDER');
        throw new Error('Roll back document');
      }),
    ).rejects.toThrow('Roll back document');
    expect(
      await scoped(a, (tx, context) =>
        nextDocumentNumber(tx, context, 'ORDER'),
      ),
    ).toBe('ORD-000009');
  });
});

describe('inventory, documents and audit foundations', () => {
  it('enforces exactly one inventory item, nonnegative stock and unique cached balances', async () => {
    const base = {
      ...ownership(a),
      warehouseId: a.warehouseId,
      itemType: 'RAW_MATERIAL' as const,
      rawMaterialId: a.materialId,
    };
    await expect(
      scoped(a, (tx) =>
        tx.inventoryBalance.create({
          data: { ...base, productId: a.productId },
        }),
      ),
    ).rejects.toThrow();
    await expect(
      scoped(a, (tx) =>
        tx.inventoryBalance.create({
          data: { ...base, quantityOnHand: '-1.0000' },
        }),
      ),
    ).rejects.toThrow();
    await scoped(a, (tx) =>
      tx.inventoryBalance.create({
        data: {
          ...base,
          quantityOnHand: '10.0000',
          quantityReserved: '2.0000',
        },
      }),
    );
    await expect(
      scoped(a, (tx) => tx.inventoryBalance.create({ data: base })),
    ).rejects.toMatchObject({ code: 'P2002' });
    const view = await scoped(
      a,
      (tx) =>
        tx.$queryRaw<
          Array<{ quantity_available: unknown }>
        >`SELECT quantity_available FROM inventory_availability WHERE raw_material_id = ${a.materialId}::uuid`,
    );
    expect(String(view[0]?.quantity_available)).toBe('8');
  });

  it('makes inventory movements and audit history append-only even for the table owner', async () => {
    const rows = await scoped(a, async (tx) => {
      const movement = await tx.inventoryMovement.create({
        data: {
          ...ownership(a),
          warehouseId: a.warehouseId,
          itemType: 'RAW_MATERIAL',
          rawMaterialId: a.materialId,
          movementType: 'ADJUSTMENT_IN',
          quantity: '10.0000',
          referenceType: 'ADJUSTMENT',
          movementDate: date,
          createdBy: a.scope.userId,
        },
      });
      const audit = await tx.auditLog.create({
        data: {
          ...ownership(a),
          userId: a.scope.userId,
          entityType: 'InventoryMovement',
          entityId: movement.id,
          action: 'CREATE',
          newValues: { quantity: '10.0000' },
        },
      });
      return { movement, audit };
    });
    await expect(
      database.admin.inventoryMovement.update({
        where: { id: rows.movement.id },
        data: { notes: 'Rewrite history' },
      }),
    ).rejects.toThrow('append-only');
    await expect(
      database.admin.auditLog.delete({ where: { id: rows.audit.id } }),
    ).rejects.toThrow('append-only');
    await expect(
      scoped(a, (tx) =>
        tx.auditLog.update({
          where: { id: rows.audit.id },
          data: { newValues: {} },
        }),
      ),
    ).rejects.toThrow();
  });

  it('scopes storage and attachment targets and keeps objects private by reference', async () => {
    const object = await scoped(a, (tx) =>
      tx.storedObject.create({
        data: {
          ...ownership(a),
          bucket: 'integration-test',
          objectKey: `${a.scope.tenantId}/${a.scope.organizationId}/${randomUUID()}`,
          contentType: 'application/pdf',
          sizeBytes: 123n,
        },
      }),
    );
    await expect(
      scoped(a, (tx) =>
        tx.attachment.create({
          data: {
            ...ownership(a),
            storedObjectId: object.id,
            entityType: 'CUSTOMER',
            entityId: b.customerId,
            fileName: 'test.pdf',
            uploadedBy: a.scope.userId,
          },
        }),
      ),
    ).rejects.toThrow();
    const attachment = await scoped(a, (tx) =>
      tx.attachment.create({
        data: {
          ...ownership(a),
          storedObjectId: object.id,
          entityType: 'CUSTOMER',
          entityId: a.customerId,
          fileName: 'test.pdf',
          uploadedBy: a.scope.userId,
        },
      }),
    );
    expect(attachment.storedObjectId).toBe(object.id);
    expect(await scoped(b, (tx) => tx.storedObject.findMany())).toEqual([]);
    await expect(
      scoped(a, (tx) =>
        tx.storedObject.create({
          data: {
            ...ownership(a),
            bucket: 'integration-test',
            objectKey: randomUUID(),
            contentType: 'application/pdf',
            sizeBytes: -1n,
          },
        }),
      ),
    ).rejects.toThrow();
  });

  it('bootstraps all organization defaults without resetting counters or creating duplicate demo data', async () => {
    const run = () =>
      database.admin.$transaction(
        async (tx) => {
          await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('f_application:seed'))`;
          await ensureOrganizationDefaults(tx, ownership(a), a.scope.userId);
          return seedDevelopmentDemo(tx);
        },
        { timeout: 30_000 },
      );
    const first = await run();
    const second = await run();
    expect(second).toEqual(first);
    expect(await database.admin.role.count({ where: ownership(a) })).toBe(7);
    expect(await database.admin.unit.count({ where: ownership(a) })).toBe(8);
    expect(
      await database.admin.numberSequence.count({ where: ownership(a) }),
    ).toBe(10);
    expect(
      await database.admin.warehouse.count({
        where: { ...ownership(a), isDefault: true },
      }),
    ).toBe(1);
    expect(
      (
        await database.admin.numberSequence.findUniqueOrThrow({
          where: {
            tenantId_organizationId_type: { ...ownership(a), type: 'ORDER' },
          },
        })
      ).currentNumber,
    ).toBe(9n);
    expect(await database.admin.customer.count({ where: first })).toBe(1);
    const membership = await database.admin.membership.findFirstOrThrow({
      where: first,
      include: { user: true },
    });
    expect(membership.user.passwordHash).toBeNull();
    expect(membership.user.status).toBe('INVITED');
  });
});
