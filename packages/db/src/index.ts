import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from './generated/prisma/client.js';

export function createDatabase(connectionString: string) {
  const adapter = new PrismaPg({
    connectionString,
    max: 10,
    connectionTimeoutMillis: 5_000,
    idleTimeoutMillis: 30_000,
  });
  return new PrismaClient({ adapter });
}

export { PrismaClient };
export type { StoredObject } from './generated/prisma/client.js';
export { Prisma } from './generated/prisma/client.js';
export * from './generated/prisma/enums.js';
export * from './tenancy.js';
export * from './number-sequences.js';
