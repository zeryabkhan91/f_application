import { randomBytes } from 'node:crypto';
import { readFile, writeFile, rename, copyFile } from 'node:fs/promises';
import { constants } from 'node:fs';
import { Client } from 'pg';
import { config } from 'dotenv';
import { provisionRuntimeRole } from '../runtime-role.js';

const envPath = new URL('../../../../.env', import.meta.url);
config({ path: envPath, quiet: true });
const adminUrl = process.env.MIGRATION_DATABASE_URL ?? process.env.DATABASE_URL;
if (!adminUrl)
  throw new Error(
    'MIGRATION_DATABASE_URL is required to provision the local runtime role',
  );
const admin = new URL(adminUrl);
if (
  process.env.NODE_ENV === 'production' ||
  !['localhost', '127.0.0.1', '[::1]'].includes(admin.hostname)
) {
  throw new Error(
    'Local role provisioning requires a loopback database outside production; provision AWS roles separately',
  );
}
const username = 'f_application_runtime';
const previous = process.env.DATABASE_URL
  ? new URL(process.env.DATABASE_URL)
  : undefined;
const runtime = new URL(admin);
const password =
  previous?.username === username && previous.password
    ? decodeURIComponent(previous.password)
    : randomBytes(32).toString('hex');
runtime.username = username;
runtime.password = password;
const client = new Client({ connectionString: adminUrl });
await client.connect();
try {
  await provisionRuntimeRole(client, username, password);
} finally {
  await client.end();
}

let contents = '';
try {
  contents = await readFile(envPath, 'utf8');
} catch (error) {
  if (
    !(error instanceof Error) ||
    !('code' in error) ||
    error.code !== 'ENOENT'
  )
    throw error;
}
if (contents) {
  try {
    await copyFile(
      envPath,
      new URL('.env.before-tenancy', new URL('.', envPath)),
      constants.COPYFILE_EXCL,
    );
  } catch (error) {
    if (
      !(error instanceof Error) ||
      !('code' in error) ||
      error.code !== 'EEXIST'
    )
      throw error;
  }
}
for (const [key, value] of [
  ['MIGRATION_DATABASE_URL', adminUrl],
  ['DATABASE_URL', runtime.toString()],
]) {
  const line = `${key}=${value}`;
  const pattern = new RegExp(`^${key}=.*$`, 'm');
  contents = pattern.test(contents)
    ? contents.replace(pattern, () => line)
    : `${contents.trimEnd()}\n${line}\n`;
}
const temporary = new URL(
  `.env.${randomBytes(8).toString('hex')}.tmp`,
  new URL('.', envPath),
);
await writeFile(temporary, contents, { mode: 0o600, flag: 'wx' });
await rename(temporary, envPath);
console.log(
  'Configured the restricted local runtime role and saved separate runtime/migration bindings in .env.',
);
