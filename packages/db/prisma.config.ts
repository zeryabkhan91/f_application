import { config } from 'dotenv';
import { defineConfig } from 'prisma/config';

config({ path: '../../.env', quiet: true });

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
    seed: 'tsx src/scripts/seed.ts',
  },
  // Client generation needs no database; migration commands still require a URL.
  datasource: {
    url: process.env.MIGRATION_DATABASE_URL ?? process.env.DATABASE_URL ?? '',
  },
});
