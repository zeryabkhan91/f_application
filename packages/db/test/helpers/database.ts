import { randomBytes } from 'node:crypto';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { fileURLToPath } from 'node:url';
import { Client } from 'pg';
import { createDatabase } from '../../src/index.js';
import { provisionRuntimeRole } from '../../src/runtime-role.js';
import { seedPlatformCatalogs } from '../../src/seeds/catalogs.js';

/** Tests own an isolated temporary database; never reset or delete a configured database. */
export async function createTestDatabase() {
  const connection =
    process.env.TEST_MIGRATION_DATABASE_URL ??
    process.env.MIGRATION_DATABASE_URL;
  if (!connection)
    throw new Error(
      'TEST_MIGRATION_DATABASE_URL or MIGRATION_DATABASE_URL is required for integration tests',
    );
  const source = new URL(connection);
  if (!['localhost', '127.0.0.1', '[::1]'].includes(source.hostname)) {
    throw new Error(
      'Integration tests create temporary databases on a local PostgreSQL server only',
    );
  }
  const suffix = randomBytes(8).toString('hex');
  const name = `f_application_test_${suffix}`;
  const role = `fapp_test_${suffix}`;
  const password = randomBytes(24).toString('hex');
  const adminUrl = new URL(source);
  adminUrl.pathname = `/${name}`;
  const control = new Client({ connectionString: connection });
  await control.connect();
  await control.query(`CREATE DATABASE "${name}"`);
  let createdRole = false;
  const cleanup = async () => {
    // Both identifiers are generated here, never supplied by the caller.
    await control.query(`DROP DATABASE "${name}" WITH (FORCE)`);
    if (createdRole) await control.query(`DROP ROLE "${role}"`);
    await control.end();
  };
  try {
    await promisify(execFile)(
      process.execPath,
      [
        fileURLToPath(
          new URL(
            '../../../../node_modules/prisma/build/index.js',
            import.meta.url,
          ),
        ),
        'migrate',
        'deploy',
      ],
      {
        cwd: fileURLToPath(new URL('../../', import.meta.url)),
        env: {
          ...process.env,
          MIGRATION_DATABASE_URL: adminUrl.toString(),
          DATABASE_URL: adminUrl.toString(),
        },
        maxBuffer: 2 * 1024 * 1024,
      },
    );
    const grantClient = new Client({ connectionString: adminUrl.toString() });
    await grantClient.connect();
    try {
      await provisionRuntimeRole(grantClient, role, password);
      createdRole = true;
    } finally {
      await grantClient.end();
    }
    const runtimeUrl = new URL(adminUrl);
    runtimeUrl.username = role;
    runtimeUrl.password = password;
    const admin = createDatabase(adminUrl.toString());
    const runtime = createDatabase(runtimeUrl.toString());
    await admin.$transaction(seedPlatformCatalogs, { timeout: 30_000 });
    return {
      admin,
      runtime,
      async dispose() {
        await runtime.$disconnect();
        await admin.$disconnect();
        await cleanup();
      },
    };
  } catch (error) {
    await cleanup();
    throw error;
  }
}
