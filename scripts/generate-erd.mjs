import { readFile, writeFile, mkdir } from 'node:fs/promises';

const source = await readFile('packages/db/prisma/schema.prisma', 'utf8');
const blocks = [...source.matchAll(/model (\w+) \{([\s\S]*?)\n\}/g)];
const names = new Set(blocks.map((match) => match[1]));
const output = [
  '%% Generated from packages/db/prisma/schema.prisma; run npm run erd:generate.',
  'erDiagram',
];
const relationships = [];
for (const [, name, body] of blocks) {
  const fields = body
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith('@@') && !line.startsWith('//'));
  const foreignKeys = new Set();
  for (const line of fields) {
    const parts = line.match(
      /^(\w+)\s+(\w+)(\?)?\s+@relation\(.*fields:\s*\[([^\]]+)\]/,
    );
    if (!parts) continue;
    const [, field, target, optional, local] = parts;
    const keys = local.split(',').map((v) => v.trim());
    keys.forEach((key) => foreignKeys.add(key));
    const unique = [...body.matchAll(/@@unique\(\[([^\]]+)\]/g)].some(
      (match) => match[1].replaceAll(/\s/g, '') === keys.join(','),
    );
    relationships.push(
      `  ${target} ${optional ? '|o' : '||'}--${unique ? 'o|' : 'o{'} ${name} : "${field}"`,
    );
  }
  output.push(`  ${name} {`);
  for (const line of fields) {
    const [, field, type] = line.match(/^(\w+)\s+(\w+)/) ?? [];
    if (!field || !type || names.has(type)) continue;
    const flags = [
      line.includes('@id') ? 'PK' : '',
      foreignKeys.has(field) ? 'FK' : '',
    ].filter(Boolean);
    output.push(
      `    ${type} ${field}${flags.length ? ` ${flags.join(', ')}` : ''}`,
    );
  }
  output.push('  }');
}
output.push(...relationships);
await mkdir('docs/architecture', { recursive: true });
await writeFile('docs/architecture/schema.erd.mmd', `${output.join('\n')}\n`);
console.log(
  `Generated ERD for ${blocks.length} models and ${relationships.length} relationships.`,
);
