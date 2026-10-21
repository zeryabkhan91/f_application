import type { Prisma } from '../generated/prisma/client.js';
import { ensureOrganizationDefaults } from './organization-defaults.js';

/** Development master data only; no fabricated payments, posted stock, or login password. */
export async function seedDevelopmentDemo(tx: Prisma.TransactionClient) {
  const owner = await tx.user.upsert({
    where: { email: 'owner@demo.invalid' },
    create: {
      name: 'Demo Owner',
      email: 'owner@demo.invalid',
      status: 'INVITED',
    },
    update: {},
  });
  const tenant = await tx.tenant.upsert({
    where: { slug: 'demo-factory' },
    create: { name: 'Demo Factory Account', slug: 'demo-factory' },
    update: {},
  });
  const organization = await tx.organization.upsert({
    where: { tenantId_slug: { tenantId: tenant.id, slug: 'demo-factory' } },
    create: { tenantId: tenant.id, name: 'Demo Factory', slug: 'demo-factory' },
    update: {},
  });
  const scope = { tenantId: tenant.id, organizationId: organization.id };
  await ensureOrganizationDefaults(tx, scope, owner.id);
  await tx.tenantBranding.upsert({
    where: { tenantId: tenant.id },
    create: { tenantId: tenant.id, applicationName: 'Demo Factory' },
    update: {},
  });
  const actors = { createdBy: owner.id, updatedBy: owner.id };
  if (
    !(await tx.supplier.findFirst({
      where: { ...scope, name: 'ABC Raw Materials' },
    }))
  ) {
    await tx.supplier.create({
      data: { ...scope, ...actors, name: 'ABC Raw Materials' },
    });
  }
  if (
    !(await tx.customer.findFirst({ where: { ...scope, name: 'XYZ Traders' } }))
  ) {
    await tx.customer.create({
      data: { ...scope, ...actors, name: 'XYZ Traders' },
    });
  }
  const kg = await tx.unit.findUniqueOrThrow({
    where: { tenantId_organizationId_code: { ...scope, code: 'KG' } },
  });
  const meter = await tx.unit.findUniqueOrThrow({
    where: { tenantId_organizationId_code: { ...scope, code: 'METER' } },
  });
  await tx.rawMaterial.upsert({
    where: { tenantId_organizationId_sku: { ...scope, sku: 'COTTON' } },
    create: {
      ...scope,
      ...actors,
      name: 'Cotton',
      sku: 'COTTON',
      unitId: kg.id,
      standardCost: '250.00',
      minimumStockLevel: '100.0000',
    },
    update: {},
  });
  await tx.product.upsert({
    where: { tenantId_organizationId_sku: { ...scope, sku: 'FABRIC' } },
    create: {
      ...scope,
      ...actors,
      name: 'Finished Fabric',
      sku: 'FABRIC',
      unitId: meter.id,
      sellingPrice: '500.00',
      standardCost: '350.00',
    },
    update: {},
  });
  return scope;
}
