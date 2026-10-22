import { Writable } from 'node:stream';
import request from 'supertest';
import { pino } from 'pino';
import { describe, expect, it } from 'vitest';
import type { Prisma } from '@repo/db';
import type { OrganizationContext, PermissionCode } from '@repo/types';
import {
  dataEnvelope,
  errorResponseSchema,
  listEnvelope,
  listQuerySchema,
  moneySchema,
  z,
} from '@repo/validation';
import { organizationRoute, publicRoute } from '../src/http/route.js';
import { paginated, single } from '../src/http/responses.js';
import type { OrganizationRunner } from '../src/http/router.js';
import { fixedAuthenticator, testApp } from './helpers/app.js';

const selection = {
  userId: '6b3f1c0e-1a2b-4c3d-8e4f-5a6b7c8d9e0f',
  tenantId: '7c4f2d1e-2b3c-4d4e-9f50-6b7c8d9e0f1a',
  organizationId: '8d5f3e2f-3c4d-4e5f-a061-7c8d9e0f1a2b',
};

function fakeRunner(permissions: PermissionCode[]) {
  const calls: string[] = [];
  const runner: OrganizationRunner = async (scope, work) => {
    calls.push(scope.organizationId);
    const context: OrganizationContext = Object.freeze({
      ...scope,
      permissions,
    });
    return work({} as Prisma.TransactionClient, context);
  };
  return { runner, calls };
}

const item = z.object({ id: z.uuid(), name: z.string(), amount: moneySchema });
const rows = Array.from({ length: 45 }, (_, index) => ({
  id: `00000000-0000-4000-8000-${String(index).padStart(12, '0')}`,
  name: `Customer ${index}`,
  amount: '10.00',
  internalNote: 'must not leak',
}));

const routes = [
  publicRoute({
    method: 'get',
    path: '/public/echo/:code',
    operationId: 'echo',
    summary: 'Echo',
    tags: ['Test'],
    params: z.object({ code: z.string().min(3) }),
    response: {
      status: 200,
      description: 'Echo',
      schema: dataEnvelope(z.object({ code: z.string() })),
    },
    handler: async ({ params }) => single({ code: params.code, extra: true }),
  }),
  organizationRoute({
    method: 'get',
    path: '/customers',
    operationId: 'listCustomers',
    summary: 'List',
    tags: ['Test'],
    permission: 'customer.read',
    query: listQuerySchema({
      sortBy: ['name', 'createdAt'],
      defaultSortBy: 'createdAt',
      filters: { status: z.enum(['ACTIVE', 'INACTIVE']).optional() },
    }),
    response: { status: 200, description: 'Page', schema: listEnvelope(item) },
    handler: async ({ query }) => {
      const start = (query.page - 1) * query.pageSize;
      return paginated(
        rows.slice(start, start + query.pageSize),
        rows.length,
        query,
      );
    },
  }),
  organizationRoute({
    method: 'post',
    path: '/customers',
    operationId: 'createCustomer',
    summary: 'Create',
    tags: ['Test'],
    permission: 'customer.write',
    body: z.object({
      name: z.string().trim().min(1),
      creditLimit: moneySchema,
    }),
    response: {
      status: 201,
      description: 'Created',
      schema: dataEnvelope(item),
    },
    handler: async ({ body }) =>
      single({ id: rows[0]!.id, name: body.name, amount: body.creditLimit }),
  }),
  organizationRoute({
    method: 'delete',
    path: '/customers/:id',
    operationId: 'deleteCustomer',
    summary: 'Delete',
    tags: ['Test'],
    permission: 'customer.write',
    params: z.object({ id: z.uuid() }),
    response: { status: 204, description: 'Deleted' },
    handler: async () => {},
  }),
  organizationRoute({
    method: 'post',
    path: '/payments',
    operationId: 'createPayment',
    summary: 'Pay',
    tags: ['Test'],
    permission: 'customer-payment.write',
    idempotent: true,
    body: z.object({ amount: moneySchema }),
    response: { status: 201, description: 'Paid', schema: dataEnvelope(item) },
    handler: async () => {
      throw new Error('Unit tests never reach an idempotent handler');
    },
  }),
  organizationRoute({
    method: 'get',
    path: '/broken',
    operationId: 'broken',
    summary: 'Broken contract',
    tags: ['Test'],
    permission: 'customer.read',
    response: {
      status: 200,
      description: 'Broken',
      schema: dataEnvelope(item),
    },
    // Simulates a controller returning a shape that violates its own contract.
    handler: async () => ({ data: { id: 'not-a-uuid' } }) as never,
  }),
];

function app(
  options: { permissions?: PermissionCode[]; signedIn?: boolean } = {},
) {
  const { runner, calls } = fakeRunner(
    options.permissions ?? ['customer.read', 'customer.write'],
  );
  const server = testApp({
    routes,
    runInOrganization: runner,
    authenticator: fixedAuthenticator(() =>
      options.signedIn === false ? null : selection,
    ),
  });
  return { server, calls };
}

describe('route definitions', () => {
  it('serves public routes and strips undeclared response fields', async () => {
    const response = await request(app().server)
      .get('/api/v1/public/echo/abc')
      .expect(200);
    expect(response.body).toEqual({ data: { code: 'abc' } });
    await request(app().server).get('/api/v1/public/echo/ab').expect(422);
  });

  it('requires a session before validation or any database work', async () => {
    const { server, calls } = app({ signedIn: false });
    const response = await request(server)
      .post('/api/v1/customers')
      .send({ name: '' })
      .expect(401);
    expect(errorResponseSchema.parse(response.body).error).toMatchObject({
      code: 'UNAUTHENTICATED',
    });
    expect(response.body.error.fields).toBeUndefined();
    expect(calls).toEqual([]);
  });

  it('enforces the declared permission inside the scoped transaction', async () => {
    const { server, calls } = app({ permissions: ['customer.read'] });
    const response = await request(server)
      .post('/api/v1/customers')
      .send({ name: 'Acme', creditLimit: '100.00' })
      .expect(403);
    expect(response.body.error.code).toBe('FORBIDDEN');
    expect(calls).toEqual([selection.organizationId]);
  });

  it('returns field errors with both details and a fields map', async () => {
    const response = await request(app().server)
      .post('/api/v1/customers')
      .send({ name: ' ', creditLimit: 12.5 })
      .expect(422);
    const error = errorResponseSchema.parse(response.body).error;
    expect(error.code).toBe('VALIDATION_ERROR');
    expect(Object.keys(error.fields ?? {}).sort()).toEqual([
      'creditLimit',
      'name',
    ]);
    expect(error.details).toHaveLength(2);
  });

  it('wraps created resources in a data envelope with the declared status', async () => {
    const response = await request(app().server)
      .post('/api/v1/customers')
      .send({ name: ' Acme ', creditLimit: '100.00' })
      .expect(201);
    expect(response.body).toEqual({
      data: { id: rows[0]!.id, name: 'Acme', amount: '100.00' },
    });
  });

  it('paginates with defaults, caps page size, and restricts sorting', async () => {
    const server = app().server;
    const first = await request(server).get('/api/v1/customers').expect(200);
    expect(first.body.meta).toEqual({
      page: 1,
      pageSize: 20,
      total: 45,
      totalPages: 3,
    });
    expect(first.body.data).toHaveLength(20);
    expect(first.body.data[0]).not.toHaveProperty('internalNote');
    const last = await request(server)
      .get(
        '/api/v1/customers?page=3&pageSize=20&sortBy=name&sortOrder=asc&status=ACTIVE',
      )
      .expect(200);
    expect(last.body.data).toHaveLength(5);
    for (const query of [
      'pageSize=101',
      'page=0',
      'sortBy=passwordHash',
      'sortOrder=sideways',
      'status=DELETED',
      'dateFrom=2026-10-22&dateTo=2026-10-01',
      'dateFrom=22-10-2026',
    ])
      await request(server).get(`/api/v1/customers?${query}`).expect(422);
  });

  it('returns 204 without a body', async () => {
    const response = await request(app().server)
      .delete(`/api/v1/customers/${rows[1]!.id}`)
      .expect(204);
    expect(response.text).toBe('');
  });

  it('requires a well-formed Idempotency-Key before opening a transaction', async () => {
    const { server, calls } = app({ permissions: ['customer-payment.write'] });
    const missing = await request(server)
      .post('/api/v1/payments')
      .send({ amount: '10.00' })
      .expect(428);
    expect(missing.body.error.code).toBe('IDEMPOTENCY_KEY_REQUIRED');
    const invalid = await request(server)
      .post('/api/v1/payments')
      .set('Idempotency-Key', 'bad key!')
      .send({ amount: '10.00' })
      .expect(400);
    expect(invalid.body.error.code).toBe('INVALID_IDEMPOTENCY_KEY');
    expect(calls).toEqual([]);
  });

  it('treats a response that violates its contract as a server error', async () => {
    const response = await request(app().server)
      .get('/api/v1/broken')
      .expect(500);
    expect(response.body.error.code).toBe('INTERNAL_ERROR');
  });

  it('adds scope fields to request logs and never logs request bodies', async () => {
    const lines: string[] = [];
    const logger = pino(
      { level: 'info' },
      new Writable({
        write(chunk, _encoding, done) {
          lines.push(chunk.toString());
          done();
        },
      }),
    );
    const { runner } = fakeRunner(['customer.write']);
    const server = testApp({
      routes,
      logger,
      runInOrganization: runner,
      authenticator: fixedAuthenticator(() => selection),
    });
    await request(server)
      .post('/api/v1/customers')
      .send({ name: 'Acme', creditLimit: '100.00', password: 'hunter2-secret' })
      .expect(201);
    const completed = lines
      .map((line) => JSON.parse(line))
      .find((entry) => entry.res);
    expect(completed).toMatchObject(selection);
    expect(lines.join('\n')).not.toContain('hunter2-secret');
  });
});
