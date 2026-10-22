import { createHash } from 'node:crypto';
import { Router, type Request, type Response } from 'express';
import {
  claimIdempotencyKey,
  completeIdempotencyKey,
  recordAudit,
  requirePermission,
  type AuditRequestMetadata,
  type Prisma,
} from '@repo/db';
import type { OrganizationContext, OrganizationSelection } from '@repo/types';
import { canonicalJson, toJsonSafe, type JsonValue } from '@repo/utils';
import { idempotencyKeySchema } from '@repo/validation';
import { ApiError } from '../lib/api-error.js';
import { parseRequestPart } from '../middleware/validate-request.js';
import type { ApiRoute, OrganizationRouteDefinition } from './route.js';

/** Runs work in one organization-scoped transaction; production uses withOrganization. */
export type OrganizationRunner = <T>(
  selection: OrganizationSelection,
  work: (
    tx: Prisma.TransactionClient,
    context: OrganizationContext,
  ) => Promise<T>,
) => Promise<T>;

export const IDEMPOTENCY_HEADER = 'Idempotency-Key';
export const REPLAYED_HEADER = 'Idempotent-Replayed';

interface Outcome {
  status: number;
  body: JsonValue | undefined;
  replayed: boolean;
}

export function createApiRouter(
  routes: readonly ApiRoute[],
  runInOrganization: OrganizationRunner,
) {
  const router = Router();
  for (const route of routes)
    router[route.method](route.path, async (req, res) => {
      const outcome = await execute(route, req, res, runInOrganization);
      if (outcome.replayed) res.setHeader(REPLAYED_HEADER, 'true');
      if (outcome.body === undefined || outcome.status === 204)
        res.status(outcome.status).end();
      else res.status(outcome.status).json(outcome.body);
    });
  return router;
}

async function execute(
  route: ApiRoute,
  req: Request,
  res: Response,
  runInOrganization: OrganizationRunner,
): Promise<Outcome> {
  if (route.access === 'public') {
    const result = await route.handler({ ...parseInput(route, req), req, res });
    return {
      status: route.response.status,
      body: serialize(route, result),
      replayed: false,
    };
  }
  // Sessions are resolved before routing, so a 401 needs no database work and
  // unauthenticated callers never receive field-level validation detail.
  const selection = res.locals.auth;
  if (!selection)
    throw new ApiError(401, 'UNAUTHENTICATED', 'Please sign in to continue.');
  const input = parseInput(route, req);
  const idempotency = route.idempotent
    ? idempotentRequest(route, req, input)
    : undefined;

  return runInOrganization(selection, async (tx, context) => {
    requirePermission(context, route.permission);
    let claimId: string | undefined;
    if (idempotency) {
      const claim = await claimIdempotencyKey(tx, context, idempotency);
      if (claim.state === 'conflict')
        throw new ApiError(
          409,
          'IDEMPOTENCY_KEY_REUSED',
          'This request was already sent with different details. Refresh and try again.',
        );
      if (claim.state === 'replay')
        return {
          status: claim.status,
          body: claim.body ?? undefined,
          replayed: true,
        };
      claimId = claim.id;
    }
    const result = await route.handler({
      ...input,
      tx,
      context,
      audit: async (entry) => {
        await recordAudit(tx, context, entry, input.request);
      },
    });
    const body = serialize(route, result);
    if (claimId)
      await completeIdempotencyKey(tx, claimId, route.response.status, body);
    return { status: route.response.status, body, replayed: false };
  });
}

function parseInput(route: ApiRoute, req: Request) {
  return {
    params: route.params
      ? parseRequestPart(route.params, req.params)
      : undefined,
    query: route.query ? parseRequestPart(route.query, req.query) : undefined,
    body: route.body ? parseRequestPart(route.body, req.body ?? {}) : undefined,
    request: requestMetadata(req),
    log: req.log,
  };
}

/** Parsing the declared schema strips undeclared fields, so responses cannot leak columns. */
function serialize(route: ApiRoute, result: unknown): JsonValue | undefined {
  const schema = route.response.schema;
  if (!schema) return undefined;
  return toJsonSafe(schema.parse(toJsonSafe(result)));
}

function requestMetadata(req: Request): AuditRequestMetadata {
  return {
    ...(req.ip ? { ipAddress: req.ip } : {}),
    ...(req.get('user-agent') ? { userAgent: req.get('user-agent') } : {}),
  };
}

function idempotentRequest(
  route: OrganizationRouteDefinition,
  req: Request,
  input: { params: unknown; query: unknown; body: unknown },
) {
  const header = req.get(IDEMPOTENCY_HEADER);
  if (header === undefined)
    throw new ApiError(
      428,
      'IDEMPOTENCY_KEY_REQUIRED',
      'This request needs an Idempotency-Key header.',
    );
  const key = idempotencyKeySchema.safeParse(header);
  if (!key.success)
    throw new ApiError(
      400,
      'INVALID_IDEMPOTENCY_KEY',
      'The Idempotency-Key header is invalid.',
    );
  const method = route.method.toUpperCase();
  const path = `${req.baseUrl}${req.path}`;
  const requestHash = createHash('sha256')
    .update(canonicalJson({ method, path, ...input }))
    .digest('hex');
  return { key: key.data, method, path, requestHash };
}
