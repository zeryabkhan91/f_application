import { config } from 'dotenv';
import { createDatabase } from '../index.js';
import { seedPlatformCatalogs } from '../seeds/catalogs.js';
import { seedDevelopmentDemo } from '../seeds/demo.js';

config({ path: '../../.env', quiet: true });
const url = process.env.MIGRATION_DATABASE_URL ?? process.env.DATABASE_URL;
if (!url) throw new Error('MIGRATION_DATABASE_URL is required for seeding');
const demo = process.argv.includes('--demo');
if (demo && process.env.NODE_ENV === 'production')
  throw new Error('Demo seeding is disabled in production');
const db = createDatabase(url);
try {
  await db.$transaction(
    async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('f_application:seed'))`;
      await seedPlatformCatalogs(tx);
      if (demo) await seedDevelopmentDemo(tx);
    },
    { timeout: 60_000 },
  );
  console.log(
    demo
      ? 'Seeded reference catalogs and development demo masters; existing values preserved.'
      : 'Seeded platform reference catalogs. Use --demo for development master data.',
  );
} finally {
  await db.$disconnect();
}
