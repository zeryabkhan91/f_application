import { permissionCodes } from '@repo/validation';
import type { Prisma } from '../generated/prisma/client.js';

export const defaultUnits = [
  { code: 'KG', name: 'Kilogram', symbol: 'kg' },
  { code: 'GRAM', name: 'Gram', symbol: 'g' },
  { code: 'LITER', name: 'Liter', symbol: 'L' },
  { code: 'METER', name: 'Meter', symbol: 'm' },
  { code: 'PIECE', name: 'Piece', symbol: 'pc' },
  { code: 'BOX', name: 'Box', symbol: 'box' },
  { code: 'BAG', name: 'Bag', symbol: 'bag' },
  { code: 'ROLL', name: 'Roll', symbol: 'roll' },
] as const;

/** Run with migration/administrative credentials, never the API runtime role. */
export async function seedPlatformCatalogs(tx: Prisma.TransactionClient) {
  for (const currency of [
    { code: 'PKR', name: 'Pakistani Rupee', symbol: 'Rs' },
    { code: 'USD', name: 'US Dollar', symbol: '$' },
    { code: 'GBP', name: 'Pound Sterling', symbol: '£' },
  ]) {
    await tx.currency.upsert({
      where: { code: currency.code },
      create: currency,
      update: {},
    });
  }
  for (const country of [
    { code: 'PK', name: 'Pakistan' },
    { code: 'US', name: 'United States' },
    { code: 'GB', name: 'United Kingdom' },
  ]) {
    await tx.country.upsert({
      where: { code: country.code },
      create: country,
      update: {},
    });
  }
  for (const unit of defaultUnits) {
    await tx.unitDefinition.upsert({
      where: { code: unit.code },
      create: unit,
      update: {},
    });
  }
  for (const code of permissionCodes) {
    await tx.permission.upsert({
      where: { code },
      create: {
        code,
        description: code.replaceAll('.', ': ').replaceAll('-', ' '),
      },
      update: {},
    });
  }
}
