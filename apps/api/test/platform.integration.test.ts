import { randomUUID } from 'node:crypto';
import { setTimeout as sleep } from 'node:timers/promises';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  lockRows,
  nextDocumentNumber,
  RecordNotFoundError,
  withOrganization,
} from '@repo/db';
import type { OrganizationSelection } from '@repo/types';
import { calculateLineAmounts, toMoneyString } from '@repo/utils';
import { dataEnvelope, moneySchema, z } from '@repo/validation';
import { createTestDatabase } from '../../../packages/db/test/helpers/database.js';
import { ensureOrganizationDefaults } from '../../../packages/db/src/seeds/organization-defaults.js';
import { organizationRoute } from '../src/http/route.js';
import { single } from '../src/http/responses.js';
import { ApiError } from '../src/lib/api-error.js';
import { fixedAuthenticator, testApp } from './helpers/app.js';

let database: Awaited<ReturnType<typeof createTestDatabase>>;
let owner: OrganizationSelection;
let viewer: OrganizationSelection;
let otherOrganization: OrganizationSelection;
let customerId: string;
let actor: OrganizationSelection | null = null;
let handlerCalls = 0;

const paymentBody = z.object({
  amount: moneySchema,
  fail: z.boolean().optional(),
  delayMs: z.number().int().min(0).max(1_000).optional(),
});

const routes = [
  organizationRoute({
    method: 'post',
    path: '/test-payments',
    operationId: 'createTestPayment',
    summary: 'Idempotent write used by platform tests',
    tags: ['Test'],
    permission: 'customer-payment.write',
    idempotent: true,
    body: paymentBody,
    response: {
      status: 201,
      description: 'Created',
      schema: dataEnvelope(
        z.object({ number: z.string(), amount: moneySchema }),
      ),
    },
    handler: async ({ body, tx, context, audit }) => {
      handlerCalls += 1;
      const number = await nextDocumentNumber(tx, context, 'PAYMENT');
      await audit({
        entityType: 'TestPayment',
        entityId: randomUUID(),
        action: 'CREATE',
        after: {
          amount: body.amount,
          accessToken: 'secret-token-value',
          nested: { passwordHash: 'secret-hash-value', note: 'kept' },
        },
        reason: ' Integration check ',
      });
      if (body.delayMs) await sleep(body.delayMs);
      if (body.fail)
        throw new ApiError(
          422,
          'PAYMENT_REJECTED',
          'The payment was rejected.',
        );
      return single({ number, amount: body.amount });
    },
  }),
  organizationRoute({
    method: 'post',
    path: '/test-customers',
    operationId: 'createTestCustomer',
    summary: 'Write that exercises database error mapping',
    tags: ['Test'],
    permission: 'customer.write',
    body: z.object({
      creditLimit: moneySchema.optional(),
      currencyCode: z.string().length(3).optional(),
      unitCode: z.string().optional(),
    }),
    response: { status: 201, description: 'Created' },
    handler: async ({ body, tx, context }) => {
      const scope = {
        tenantId: context.tenantId,
        organizationId: context.organizationId,
      };
      if (body.unitCode)
        await tx.unit.create({
          data: { ...scope, code: body.unitCode, name: 'Unit', symbol: 'u' },
        });
      else
        await tx.customer.create({
          data: {
            ...scope,
            name: 'Mapped Customer',
            creditLimit: body.creditLimit ?? '0',
            currencyCode: body.currencyCode ?? 'PKR',
          },
        });
    },
  }),
];

const server = () =>
  testApp({
    routes,
    authenticator: fixedAuthenticator(() => actor),
    runInOrganization: (selection, work) =>
      withOrganization(database.runtime, selection, work),
  });

async function createOrganization(name: string) {
  return database.admin.$transaction(
    async (tx) => {
      const suffix = randomUUID();
      const user = await tx.user.create({
        data: {
          name: `${name} Owner`,
          email: `${suffix}@test.invalid`,
          status: 'ACTIVE',
          passwordHash: 'test-only-unusable-authentication-hash',
        },
      });
      const tenant = await tx.tenant.create({ data: { name, slug: suffix } });
      const organization = await tx.organization.create({
        data: { tenantId: tenant.id, name, slug: suffix },
      });
      const scope = { tenantId: tenant.id, organizationId: organization.id };
      await ensureOrganizationDefaults(tx, scope, user.id);
      return { ...scope, userId: user.id };
    },
    { timeout: 30_000 },
  );
}

async function addViewer(scope: OrganizationSelection) {
  return database.admin.$transaction(async (tx) => {
    const user = await tx.user.create({
      data: {
        name: 'Viewer',
        email: `${randomUUID()}@test.invalid`,
        status: 'ACTIVE',
        passwordHash: 'test-only-unusable-authentication-hash',
      },
    });
    const role = await tx.role.findFirstOrThrow({
      where: {
        tenantId: scope.tenantId,
        organizationId: scope.organizationId,
        code: 'VIEWER',
      },
    });
    await tx.membership.create({
      data: {
        tenantId: scope.tenantId,
        organizationId: scope.organizationId,
        userId: user.id,
        roleId: role.id,
        status: 'ACTIVE',
      },
    });
    return { ...scope, userId: user.id };
  });
}

const sequenceValue = async (scope: OrganizationSelection) =>
  (
    await database.admin.numberSequence.findFirstOrThrow({
      where: {
        tenantId: scope.tenantId,
        organizationId: scope.organizationId,
        type: 'PAYMENT',
      },
    })
  ).currentNumber;

const keyCount = (scope: OrganizationSelection) =>
  database.admin.idempotencyKey.count({
    where: { tenantId: scope.tenantId, organizationId: scope.organizationId },
  });

function pay(key: string | undefined, body: z.input<typeof paymentBody>) {
  const call = request(server()).post('/api/v1/test-payments');
  if (key) call.set('Idempotency-Key', key);
  return call.set('User-Agent', 'platform-test/1.0').send(body);
}

beforeAll(async () => {
  database = await createTestDatabase();
  owner = await createOrganization('Platform Factory');
  viewer = await addViewer(owner);
  otherOrganization = await createOrganization('Other Factory');
  customerId = (
    await database.admin.customer.create({
      data: {
        tenantId: owner.tenantId,
        organizationId: owner.organizationId,
        name: 'Locked Customer',
      },
    })
  ).id;
}, 120_000);

afterAll(async () => {
  if (database) await database.dispose();
}, 30_000);

describe('idempotent writes', () => {
  it('replays the committed response without repeating side effects', async () => {
    actor = owner;
    const key = randomUUID();
    const before = await sequenceValue(owner);
    const first = await pay(key, { amount: '500000.00' }).expect(201);
    const calls = handlerCalls;
    const replay = await pay(key, { amount: '500000.00' }).expect(201);
    expect(replay.body).toEqual(first.body);
    expect(replay.headers['idempotent-replayed']).toBe('true');
    expect(first.headers['idempotent-replayed']).toBeUndefined();
    expect(handlerCalls).toBe(calls);
    expect(await sequenceValue(owner)).toBe(before + 1n);
  });

  it('rejects a reused key with a different body', async () => {
    actor = owner;
    const key = randomUUID();
    await pay(key, { amount: '10.00' }).expect(201);
    const conflict = await pay(key, { amount: '10.01' }).expect(409);
    expect(conflict.body.error.code).toBe('IDEMPOTENCY_KEY_REUSED');
  });

  it('serializes concurrent retries so the work happens once', async () => {
    actor = owner;
    const key = randomUUID();
    const before = await sequenceValue(owner);
    const responses = await Promise.all([
      pay(key, { amount: '75.00', delayMs: 300 }),
      pay(key, { amount: '75.00', delayMs: 300 }),
      pay(key, { amount: '75.00', delayMs: 300 }),
    ]);
    expect(responses.map((response) => response.status)).toEqual([
      201, 201, 201,
    ]);
    expect(
      new Set(responses.map((response) => response.body.data.number)).size,
    ).toBe(1);
    expect(
      responses.filter((response) => response.headers['idempotent-replayed']),
    ).toHaveLength(2);
    expect(await sequenceValue(owner)).toBe(before + 1n);
  });

  it('keeps no key or side effects when the request fails, so it can be retried', async () => {
    actor = owner;
    const key = randomUUID();
    const before = await sequenceValue(owner);
    const keys = await keyCount(owner);
    const failed = await pay(key, { amount: '20.00', fail: true }).expect(422);
    expect(failed.body.error.code).toBe('PAYMENT_REJECTED');
    expect(await keyCount(owner)).toBe(keys);
    expect(await sequenceValue(owner)).toBe(before);
    await pay(key, { amount: '20.00' }).expect(201);
  });

  it('reclaims expired keys', async () => {
    actor = owner;
    const key = randomUUID();
    await pay(key, { amount: '30.00' }).expect(201);
    await database.admin.idempotencyKey.updateMany({
      where: { key },
      data: {
        createdAt: new Date('2026-01-01'),
        expiresAt: new Date('2026-01-02'),
      },
    });
    const fresh = await pay(key, { amount: '31.00' }).expect(201);
    expect(fresh.headers['idempotent-replayed']).toBeUndefined();
  });

  it('keeps keys private to the member and organization that sent them', async () => {
    actor = owner;
    const key = randomUUID();
    await pay(key, { amount: '40.00' }).expect(201);
    const visible = (scope: OrganizationSelection) =>
      withOrganization(database.runtime, scope, (tx) =>
        tx.idempotencyKey.count({ where: { key } }),
      );
    expect(await visible(owner)).toBe(1);
    expect(await visible(viewer)).toBe(0);
    expect(await visible(otherOrganization)).toBe(0);
    // The same key from another organization is an independent request.
    actor = otherOrganization;
    const other = await pay(key, { amount: '99.00' }).expect(201);
    expect(other.headers['idempotent-replayed']).toBeUndefined();
  });

  it('checks permission before claiming a key', async () => {
    actor = viewer;
    const keys = await keyCount(owner);
    const denied = await pay(randomUUID(), { amount: '50.00' }).expect(403);
    expect(denied.body.error.code).toBe('FORBIDDEN');
    expect(await keyCount(owner)).toBe(keys);
    actor = null;
    await pay(randomUUID(), { amount: '50.00' }).expect(401);
  });
});

describe('audit writer', () => {
  it('records the authenticated actor, reason, request metadata, and redacted values', async () => {
    actor = owner;
    await pay(randomUUID(), { amount: '60.00' }).expect(201);
    const entry = await database.admin.auditLog.findFirstOrThrow({
      where: {
        organizationId: owner.organizationId,
        entityType: 'TestPayment',
      },
      orderBy: { createdAt: 'desc' },
    });
    expect(entry).toMatchObject({
      tenantId: owner.tenantId,
      userId: owner.userId,
      action: 'CREATE',
      reason: 'Integration check',
      userAgent: 'platform-test/1.0',
      oldValues: null,
      newValues: {
        amount: '60.00',
        accessToken: '[REDACTED]',
        nested: { passwordHash: '[REDACTED]', note: 'kept' },
      },
    });
    expect(entry.ipAddress).toBeTruthy();
    expect(JSON.stringify(entry)).not.toContain('secret-');
  });
});

describe('database error mapping', () => {
  it('returns plain-language duplicate, check, and reference errors', async () => {
    actor = owner;
    const app = server();
    const duplicate = await request(app)
      .post('/api/v1/test-customers')
      .send({ unitCode: 'KG' })
      .expect(409);
    expect(duplicate.body.error).toMatchObject({
      code: 'DUPLICATE',
      message: 'A record with these details already exists.',
    });
    const check = await request(app)
      .post('/api/v1/test-customers')
      .send({ creditLimit: '-1.00' })
      .expect(422);
    expect(check.body.error).toMatchObject({
      code: 'BUSINESS_RULE_VIOLATION',
      message: 'This value cannot be negative.',
    });
    const reference = await request(app)
      .post('/api/v1/test-customers')
      .send({ currencyCode: 'XXX' })
      .expect(409);
    expect(reference.body.error.code).toBe('REFERENCE_CONFLICT');
    for (const response of [duplicate, check, reference])
      expect(response.text).not.toMatch(/constraint|violates|Failing row/);
  });
});

describe('row locking', () => {
  it('holds locks until the transaction ends', async () => {
    let release!: () => void;
    let acquired!: () => void;
    const held = new Promise<void>((resolve) => (release = resolve));
    const locked = new Promise<void>((resolve) => (acquired = resolve));
    const holder = withOrganization(
      database.runtime,
      owner,
      async (tx, context) => {
        expect(
          await lockRows(tx, context, 'customers', [customerId, customerId]),
        ).toEqual([customerId]);
        acquired();
        await held;
      },
    );
    await locked;
    await expect(
      withOrganization(
        database.runtime,
        owner,
        (tx) =>
          tx.$queryRaw`SELECT id FROM customers WHERE id = ${customerId}::uuid FOR UPDATE NOWAIT`,
      ),
    ).rejects.toThrow();
    release();
    await holder;
    await withOrganization(database.runtime, owner, (tx, context) =>
      lockRows(tx, context, 'customers', [customerId]),
    );
  });

  it('treats missing, malformed, and other-organization IDs as not found', async () => {
    await expect(
      withOrganization(database.runtime, otherOrganization, (tx, context) =>
        lockRows(tx, context, 'customers', [customerId]),
      ),
    ).rejects.toBeInstanceOf(RecordNotFoundError);
    await expect(
      withOrganization(database.runtime, owner, (tx, context) =>
        lockRows(tx, context, 'customers', [customerId, randomUUID()]),
      ),
    ).rejects.toBeInstanceOf(RecordNotFoundError);
    await expect(
      withOrganization(database.runtime, owner, (tx, context) =>
        lockRows(tx, context, 'customers', ['not-a-uuid']),
      ),
    ).rejects.toBeInstanceOf(RecordNotFoundError);
    expect(
      await withOrganization(database.runtime, owner, (tx, context) =>
        lockRows(tx, context, 'customers', [randomUUID()], {
          requireAll: false,
        }),
      ),
    ).toEqual([]);
  });
});

describe('money library and database rounding', () => {
  it('matches PostgreSQL round(quantity × unit price, 2) exactly', async () => {
    const pairs: Array<[string, string]> = [
      ['3.3333', '3.33'],
      ['0.0050', '1.00'],
      ['2.6750', '1.00'],
      ['1.0005', '0.05'],
      ['99999999999999.9999', '0.01'],
      ['12.3456', '9876.54'],
      ['0.0001', '0.50'],
    ];
    for (const [quantity, unitPrice] of pairs) {
      const [row] = await database.admin.$queryRaw<Array<{ amount: string }>>`
        SELECT round(${quantity}::numeric(18,4) * ${unitPrice}::numeric(18,2), 2)::text AS amount
      `;
      expect(
        toMoneyString(
          calculateLineAmounts({ quantity, unitPrice }).grossAmount,
        ),
      ).toBe(row!.amount);
    }
  });
});
