import { describe, expect, it } from 'vitest';
import request from 'supertest';
import { pino } from 'pino';
import { parseEnvironment } from '@repo/config';
import { errorResponseSchema } from '@repo/validation';
import { createApp } from '../src/app.js';

function app(
  options: {
    checkDatabase?: () => Promise<void>;
    isShuttingDown?: () => boolean;
    production?: boolean;
  } = {},
) {
  return createApp({
    config: parseEnvironment({
      DATABASE_URL: 'postgresql://test:test@localhost:5432/test',
      NODE_ENV: options.production ? 'production' : 'test',
      CORS_ORIGINS: 'http://localhost:3000',
    }),
    logger: pino({ level: 'silent' }),
    checkDatabase: options.checkDatabase ?? (async () => {}),
    isShuttingDown: options.isShuttingDown,
  });
}

describe('HTTP API', () => {
  it('returns liveness, readiness, identity and request IDs', async () => {
    const server = app();
    const live = await request(server).get('/health/live').expect(200);
    expect(live.body).toEqual({ status: 'ok' });
    expect(live.headers['cache-control']).toBe('no-store');
    expect(live.headers['x-request-id']).toBeTruthy();
    const ready = await request(server).get('/health/ready').expect(200);
    expect(ready.body).toEqual({ status: 'ready' });
    const info = await request(server).get('/api/v1').expect(200);
    expect(info.body).toEqual({ name: 'f-application-api', version: '0.1.0' });
    expect(info.headers['x-powered-by']).toBeUndefined();
    expect(info.headers['x-content-type-options']).toBe('nosniff');
  });

  it('keeps liveness healthy when the database fails and returns safe readiness errors', async () => {
    const server = app({
      checkDatabase: async () => {
        throw new Error('private db details');
      },
    });
    await request(server).get('/health/live').expect(200);
    const response = await request(server).get('/health/ready').expect(503);
    expect(response.body).toEqual({ status: 'not_ready' });
    expect(response.text).not.toContain('private');
  });

  it('stops advertising readiness while shutting down', async () => {
    let checked = false;
    const server = app({
      isShuttingDown: () => true,
      checkDatabase: async () => {
        checked = true;
      },
    });
    await request(server).get('/health/ready').expect(503);
    expect(checked).toBe(false);
  });

  it('returns a documented 404 and preserves safe correlation IDs', async () => {
    const response = await request(app())
      .get('/missing')
      .set('X-Request-Id', 'request_123')
      .expect(404);
    expect(errorResponseSchema.parse(response.body).error).toEqual({
      code: 'NOT_FOUND',
      message: 'Route not found',
      requestId: 'request_123',
    });
    expect(response.headers['x-request-id']).toBe('request_123');
  });

  it('rejects disallowed origins and permits configured preflights', async () => {
    const server = app();
    const rejected = await request(server)
      .get('/api/v1')
      .set('Origin', 'https://untrusted.example')
      .expect(403);
    expect(rejected.body.error.code).toBe('ORIGIN_NOT_ALLOWED');
    const allowed = await request(server)
      .options('/api/v1')
      .set('Origin', 'http://localhost:3000')
      .set('Access-Control-Request-Method', 'GET')
      .expect(204);
    expect(allowed.headers['access-control-allow-origin']).toBe(
      'http://localhost:3000',
    );
  });

  it('handles malformed JSON and enforces the request body limit', async () => {
    const server = app();
    const invalid = await request(server)
      .post('/api/v1')
      .set('Content-Type', 'application/json')
      .send('{broken')
      .expect(400);
    expect(invalid.body.error.code).toBe('INVALID_JSON');
    const large = await request(server)
      .post('/api/v1')
      .send({ value: 'x'.repeat(1024 * 1024) })
      .expect(413);
    expect(large.body.error.code).toBe('PAYLOAD_TOO_LARGE');
  });

  it('serves the OpenAPI contract and interactive docs during development', async () => {
    const server = app();
    const response = await request(server).get('/openapi.json').expect(200);
    expect(response.body.openapi).toBe('3.0.3');
    expect(Object.keys(response.body.paths)).toEqual([
      '/health/live',
      '/health/ready',
      '/api/v1',
    ]);
    const docs = await request(server).get('/docs/').expect(200);
    expect(docs.text).toContain('swagger-ui');
  });

  it('keeps interactive docs disabled by default in production', async () => {
    await request(app({ production: true }))
      .get('/openapi.json')
      .expect(404);
  });

  it('returns the standard error contract when rate limited', async () => {
    const server = app();
    for (let i = 0; i < 120; i++)
      await request(server).get('/api/v1').expect(200);
    const response = await request(server).get('/api/v1').expect(429);
    expect(errorResponseSchema.parse(response.body).error.code).toBe(
      'RATE_LIMITED',
    );
    expect(response.headers['retry-after']).toBeTruthy();
    await request(server).get('/health/live').expect(200);
  });
});
