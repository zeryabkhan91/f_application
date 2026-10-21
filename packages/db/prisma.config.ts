import { config } from 'dotenv';
import { defineConfig } from 'prisma/config';

config({ path: '../../.env', quiet: true });

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: { path: 'prisma/migrations' },
  // Client generation needs no database; migration commands still require a URL.
  datasource: { url: process.env.DATABASE_URL ?? '' },
});
