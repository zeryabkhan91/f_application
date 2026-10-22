import type { OrganizationContext } from '@repo/types';
import type { JsonValue } from '@repo/utils';
import type { Prisma } from './generated/prisma/client.js';

export const IDEMPOTENCY_TTL_HOURS = 24;

export interface IdempotentRequest {
  key: string;
  method: string;
  path: string;
  /** SHA-256 hex digest of the method, path, and canonical validated input. */
  requestHash: string;
}

export type IdempotencyClaim =
  | { state: 'claimed'; id: string }
  | { state: 'replay'; status: number; body: JsonValue | null }
  | { state: 'conflict' };

/**
 * Claims a key inside the request's transaction. A concurrent request with the
 * same key blocks on the unique index until the first transaction finishes, then
 * replays its committed response; if the first one rolled back, this one proceeds.
 * Failed requests therefore never leave a key behind, and retries stay safe.
 * Expired keys are reclaimed in place.
 */
export async function claimIdempotencyKey(
  tx: Prisma.TransactionClient,
  context: OrganizationContext,
  request: IdempotentRequest,
): Promise<IdempotencyClaim> {
  const claimed = await tx.$queryRaw<Array<{ id: string }>>`
    INSERT INTO idempotency_keys
      (tenant_id, organization_id, user_id, key, request_method, request_path, request_hash, expires_at)
    VALUES (
      ${context.tenantId}::uuid, ${context.organizationId}::uuid, ${context.userId}::uuid,
      ${request.key}, ${request.method}, ${request.path}, ${request.requestHash},
      now() + make_interval(hours => ${IDEMPOTENCY_TTL_HOURS}::int)
    )
    ON CONFLICT (tenant_id, organization_id, user_id, key) DO UPDATE SET
      request_method = EXCLUDED.request_method,
      request_path = EXCLUDED.request_path,
      request_hash = EXCLUDED.request_hash,
      response_status = NULL,
      response_body = NULL,
      created_at = now(),
      expires_at = EXCLUDED.expires_at
    WHERE idempotency_keys.expires_at <= now()
    RETURNING id::text AS id
  `;
  if (claimed[0]) return { state: 'claimed', id: claimed[0].id };

  const [existing] = await tx.$queryRaw<
    Array<{
      requestHash: string;
      responseStatus: number | null;
      responseBody: JsonValue | null;
    }>
  >`
    SELECT request_hash AS "requestHash", response_status AS "responseStatus", response_body AS "responseBody"
    FROM idempotency_keys
    WHERE tenant_id = ${context.tenantId}::uuid
      AND organization_id = ${context.organizationId}::uuid
      AND user_id = ${context.userId}::uuid
      AND key = ${request.key}
  `;
  if (
    !existing ||
    existing.requestHash !== request.requestHash ||
    existing.responseStatus === null
  )
    return { state: 'conflict' };
  return {
    state: 'replay',
    status: existing.responseStatus,
    body: existing.responseBody,
  };
}

/** Stores the success response in the same transaction as the work it describes. */
export async function completeIdempotencyKey(
  tx: Prisma.TransactionClient,
  claimId: string,
  status: number,
  body: JsonValue | undefined,
) {
  const serialized = body === undefined ? null : JSON.stringify(body);
  await tx.$executeRaw`
    UPDATE idempotency_keys
    SET response_status = ${status}::smallint, response_body = ${serialized}::jsonb
    WHERE id = ${claimId}::uuid
  `;
}
