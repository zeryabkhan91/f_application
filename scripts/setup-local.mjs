import { randomBytes } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';

const root = new URL('../', import.meta.url);
const password = randomBytes(24).toString('hex');
const template = await readFile(new URL('.env.example', root), 'utf8');
try {
  await writeFile(
    new URL('.env', root),
    template.replaceAll('replace-with-local-password', password),
    { flag: 'wx', mode: 0o600 },
  );
  console.log('Created .env with a generated local database password.');
} catch (error) {
  if (error.code !== 'EEXIST') throw error;
  console.log('Kept the existing .env unchanged.');
}
