import assert from 'node:assert/strict';

const base = process.env.API_BASE_URL ?? 'http://127.0.0.1:4000';
for (const [path, expected] of [
  ['/health/live', { status: 'ok' }],
  ['/health/ready', { status: 'ready' }],
  ['/api/v1', { name: 'f-application-api', version: '0.1.0' }],
]) {
  const response = await fetch(new URL(path, base), {
    signal: AbortSignal.timeout(10_000),
  });
  assert.equal(response.status, 200, `Unexpected status from ${path}`);
  assert.deepEqual(await response.json(), expected);
  assert.ok(response.headers.get('x-request-id'));
  console.log(`PASS ${path}`);
}
