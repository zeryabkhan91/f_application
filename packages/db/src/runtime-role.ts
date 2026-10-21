import type { Client } from 'pg';

/** Explicit deployment operation; callers supply administrative credentials. Never call from a request. */
export async function provisionRuntimeRole(
  client: Client,
  username: string,
  password: string,
) {
  const quote = (value: string) => `"${value.replaceAll('"', '""')}"`;
  try {
    await client.query('BEGIN');
    await client.query(
      "SELECT pg_advisory_xact_lock(hashtext('f_application:runtime-role'))",
    );
    const inherited = await client.query(
      'SELECT 1 FROM pg_auth_members m JOIN pg_roles r ON r.oid = m.member WHERE r.rolname = $1',
      [username],
    );
    if (inherited.rowCount)
      throw new Error(
        'The local runtime role has inherited roles; review its grants before provisioning',
      );
    const exists = await client.query(
      'SELECT 1 FROM pg_roles WHERE rolname = $1',
      [username],
    );
    const command = await client.query<{ statement: string }>(
      `SELECT format('${exists.rowCount ? 'ALTER' : 'CREATE'} ROLE %I LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD %L', $1::text, $2::text) AS statement`,
      [username, password],
    );
    const statement = command.rows[0]?.statement;
    if (!statement) throw new Error('Could not prepare the local runtime role');
    await client.query(statement);
    const database = await client.query<{ name: string }>(
      'SELECT current_database() AS name',
    );
    const databaseName = database.rows[0]?.name;
    if (!databaseName)
      throw new Error('Could not determine the local database');
    await client.query(
      `GRANT CONNECT ON DATABASE ${quote(databaseName)} TO ${quote(username)}`,
    );
    await client.query(`GRANT USAGE ON SCHEMA public TO ${quote(username)}`);
    await client.query(
      `REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM ${quote(username)}`,
    );
    const objects = await client.query<{ name: string; kind: string }>(
      "SELECT c.relname AS name, c.relkind AS kind FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relkind IN ('r', 'v') AND c.relname <> '_prisma_migrations'",
    );
    const catalogs = new Set([
      'currencies',
      'countries',
      'permissions',
      'unit_definitions',
      'users',
    ]);
    const appendOnly = new Set(['audit_logs', 'inventory_movements']);
    for (const object of objects.rows) {
      const privileges =
        catalogs.has(object.name) || object.kind === 'v'
          ? 'SELECT'
          : appendOnly.has(object.name)
            ? 'SELECT, INSERT'
            : 'SELECT, INSERT, UPDATE, DELETE';
      await client.query(
        `GRANT ${privileges} ON TABLE public.${quote(object.name)} TO ${quote(username)}`,
      );
    }
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  }
}
