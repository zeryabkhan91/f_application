import { describe, expect, it } from 'vitest';
import {
  dataEnvelope,
  listEnvelope,
  listQuerySchema,
  moneySchema,
  z,
} from '@repo/validation';
import { buildOpenApiPaths } from '../src/http/openapi-paths.js';
import { organizationRoute, publicRoute } from '../src/http/route.js';
import { createOpenApiDocument } from '../src/openapi.js';

const customer = z.object({
  id: z.uuid(),
  name: z.string(),
  creditLimit: moneySchema,
});

const sampleRoutes = [
  organizationRoute({
    method: 'get',
    path: '/customers',
    operationId: 'listCustomers',
    summary: 'List customers',
    tags: ['Customers'],
    permission: 'customer.read',
    query: listQuerySchema({
      sortBy: ['name', 'createdAt'],
      defaultSortBy: 'name',
      defaultSortOrder: 'asc',
      filters: { status: z.enum(['ACTIVE', 'INACTIVE']).optional() },
    }),
    response: {
      status: 200,
      description: 'One page of customers',
      schema: listEnvelope(customer),
    },
    handler: async () => ({
      data: [],
      meta: { page: 1, pageSize: 20, total: 0, totalPages: 0 },
    }),
  }),
  organizationRoute({
    method: 'patch',
    path: '/customers/:id',
    operationId: 'updateCustomer',
    summary: 'Update a customer',
    description: 'Changes contact details.',
    tags: ['Customers'],
    permission: 'customer.write',
    params: z.object({ id: z.uuid() }),
    body: z.object({ name: z.string().min(1).optional() }),
    response: {
      status: 200,
      description: 'Updated customer',
      schema: dataEnvelope(customer),
    },
    errors: [
      {
        status: 404,
        code: 'NOT_FOUND',
        description: 'Customer does not exist',
      },
      { status: 409, code: 'DUPLICATE', description: 'Name already used' },
    ],
    handler: async () => ({
      data: { id: crypto.randomUUID(), name: 'x', creditLimit: '0.00' },
    }),
  }),
  organizationRoute({
    method: 'post',
    path: '/customer-payments',
    operationId: 'createCustomerPayment',
    summary: 'Receive a payment',
    tags: ['Payments'],
    permission: 'customer-payment.write',
    idempotent: true,
    body: z.object({ amount: moneySchema }),
    response: { status: 201, description: 'Payment recorded' },
    handler: async () => {},
  }),
  publicRoute({
    method: 'get',
    path: '/status',
    operationId: 'getStatus',
    summary: 'Status',
    tags: ['System'],
    response: {
      status: 200,
      description: 'OK',
      schema: z.object({ ok: z.boolean() }),
    },
    handler: async () => ({ ok: true }),
  }),
];

describe('OpenAPI generation', () => {
  it('derives paths, parameters, permissions, and errors from route definitions', () => {
    expect(buildOpenApiPaths(sampleRoutes)).toMatchSnapshot();
  });

  it('documents the registered API routes beside the health probes', () => {
    const document = createOpenApiDocument();
    expect(Object.keys(document.paths)).toEqual([
      '/health/live',
      '/health/ready',
      '/api/v1',
    ]);
    expect(document.paths['/api/v1']).toHaveProperty(
      'get.operationId',
      'getServiceInfo',
    );
  });

  it('rejects routes whose params drift from their path or that collide', () => {
    const base = {
      method: 'get' as const,
      summary: 'Get',
      tags: ['Test'],
      permission: 'customer.read' as const,
      response: { status: 204 as const, description: 'None' },
      handler: async () => {},
    };
    expect(() =>
      buildOpenApiPaths([
        organizationRoute({
          ...base,
          path: '/customers/:id',
          operationId: 'a',
        }),
      ]),
    ).toThrow('params schema must declare exactly id');
    expect(() =>
      buildOpenApiPaths([
        organizationRoute({
          ...base,
          path: '/customers',
          operationId: 'b',
          params: z.object({ id: z.uuid() }),
        }),
      ]),
    ).toThrow('params schema must declare exactly no keys');
    expect(() =>
      buildOpenApiPaths([
        organizationRoute({ ...base, path: '/one', operationId: 'same' }),
        organizationRoute({ ...base, path: '/two', operationId: 'same' }),
      ]),
    ).toThrow('Duplicate operationId same');
    expect(() =>
      buildOpenApiPaths([
        organizationRoute({ ...base, path: '/one', operationId: 'c' }),
        organizationRoute({ ...base, path: '/one', operationId: 'd' }),
      ]),
    ).toThrow('Duplicate route GET /api/v1/one');
  });
});
