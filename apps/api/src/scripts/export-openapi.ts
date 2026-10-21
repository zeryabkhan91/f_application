import { mkdir, writeFile } from 'node:fs/promises';
import { createOpenApiDocument } from '../openapi.js';

await mkdir('docs', { recursive: true });
await writeFile(
  'docs/openapi.json',
  JSON.stringify(createOpenApiDocument(), null, 2) + '\n',
);
console.log('Wrote docs/openapi.json');
