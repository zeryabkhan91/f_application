import { domainEnums, permissionCodes } from '@repo/validation';
import type { PermissionCode, RoleCode, NumberSequenceType } from '@repo/types';
import type { Prisma } from '../generated/prisma/client.js';
import { defaultUnits } from './catalogs.js';

type Scope = { tenantId: string; organizationId: string };

const roleModules: Partial<Record<RoleCode, readonly string[]>> = {
  ACCOUNTS: [
    'customer',
    'supplier',
    'supplier-invoice',
    'supplier-payment',
    'invoice',
    'customer-payment',
    'payment-schedule',
    'expense',
    'report',
    'attachment',
  ],
  SALES: ['customer', 'order', 'invoice', 'payment-schedule', 'attachment'],
  PRODUCTION: ['bom', 'production'],
  WAREHOUSE: ['inventory', 'goods-receipt', 'dispatch', 'warehouse'],
};

export function defaultPermissions(role: RoleCode): readonly PermissionCode[] {
  if (role === 'CUSTOM') return [];
  if (role === 'OWNER') return permissionCodes;
  if (role === 'ADMIN')
    return permissionCodes.filter((p) => p !== 'tenant.write');
  if (role === 'VIEWER')
    return permissionCodes.filter((p) => p.endsWith('.read'));
  const modules = roleModules[role] ?? [];
  return permissionCodes.filter(
    (p) =>
      modules.includes(p.split('.')[0] ?? '') ||
      [
        'material.read',
        'product.read',
        'inventory.read',
        'warehouse.read',
        'organization.read',
        'notification.read',
      ].includes(p),
  );
}

export const sequencePrefixes: Record<NumberSequenceType, string> = {
  INVOICE: 'INV-',
  ORDER: 'ORD-',
  PURCHASE: 'PUR-',
  PAYMENT: 'PAY-',
  SUPPLIER_PAYMENT: 'SPAY-',
  SUPPLIER_INVOICE: 'SINV-',
  GOODS_RECEIPT: 'GRN-',
  PRODUCTION: 'PROD-',
  DISPATCH: 'DSP-',
  EXPENSE: 'EXP-',
};

/** Idempotent organization bootstrap, inside the caller's administrative transaction. */
export async function ensureOrganizationDefaults(
  tx: Prisma.TransactionClient,
  scope: Scope,
  ownerUserId: string,
) {
  const organization = await tx.organization.findUniqueOrThrow({
    where: {
      tenantId_id: { tenantId: scope.tenantId, id: scope.organizationId },
    },
  });
  const roles = new Map<RoleCode, string>();
  for (const code of domainEnums.RoleCode.filter((v) => v !== 'CUSTOM')) {
    let role = await tx.role.findFirst({ where: { ...scope, code } });
    if (!role) {
      role = await tx.role.create({ data: { ...scope, code, name: code } });
      const roleId = role.id;
      const definitions = await tx.permission.findMany({
        where: { code: { in: [...defaultPermissions(code)] } },
      });
      await tx.rolePermission.createMany({
        data: definitions.map((p) => ({
          ...scope,
          roleId,
          permissionId: p.id,
        })),
      });
    }
    roles.set(code, role.id);
  }
  const ownerRoleId = roles.get('OWNER');
  if (!ownerRoleId) throw new Error('Owner role initialization failed');
  await tx.membership.upsert({
    where: {
      tenantId_organizationId_userId: { ...scope, userId: ownerUserId },
    },
    create: {
      ...scope,
      userId: ownerUserId,
      roleId: ownerRoleId,
      status: 'ACTIVE',
    },
    update: {},
  });
  const actors = { createdBy: ownerUserId, updatedBy: ownerUserId };
  await tx.organizationSettings.upsert({
    where: { tenantId_organizationId: scope },
    create: { ...scope, ...actors, defaultCurrency: organization.currencyCode },
    update: {},
  });
  for (const type of domainEnums.NumberSequenceType) {
    await tx.numberSequence.upsert({
      where: { tenantId_organizationId_type: { ...scope, type } },
      create: { ...scope, ...actors, type, prefix: sequencePrefixes[type] },
      update: {},
    });
  }
  for (const unit of defaultUnits) {
    const definition = await tx.unitDefinition.findUniqueOrThrow({
      where: { code: unit.code },
    });
    await tx.unit.upsert({
      where: { tenantId_organizationId_code: { ...scope, code: unit.code } },
      create: { ...scope, ...actors, ...unit, definitionId: definition.id },
      update: {},
    });
  }
  const warehouse = await tx.warehouse.findFirst({
    where: { ...scope, isDefault: true, deletedAt: null, status: 'ACTIVE' },
  });
  if (!warehouse) {
    await tx.warehouse.upsert({
      where: { tenantId_organizationId_code: { ...scope, code: 'MAIN' } },
      create: {
        ...scope,
        ...actors,
        code: 'MAIN',
        name: 'Main Warehouse',
        isDefault: true,
      },
      update: { isDefault: true, deletedAt: null, status: 'ACTIVE' },
    });
  }
  for (const name of [
    'Electricity',
    'Gas',
    'Labour',
    'Transport',
    'Rent',
    'Packaging',
    'Maintenance',
    'Machine Repair',
    'Miscellaneous',
  ]) {
    await tx.expenseCategory.upsert({
      where: { tenantId_organizationId_name: { ...scope, name } },
      create: { ...scope, ...actors, name },
      update: {},
    });
  }
}
