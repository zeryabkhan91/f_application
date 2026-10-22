import type { OrganizationContext } from '@repo/types';
import { toJsonSafe, type JsonValue } from '@repo/utils';
import type { AuditAction } from './generated/prisma/enums.js';
import type { Prisma } from './generated/prisma/client.js';

export interface AuditEntry {
  /** Stable business name such as "SalesInvoice"; at most 80 characters. */
  entityType: string;
  entityId: string;
  action: AuditAction;
  before?: unknown;
  after?: unknown;
  /** Required by callers for void, cancel, reversal, and adjustment actions. */
  reason?: string;
}

export interface AuditRequestMetadata {
  ipAddress?: string;
  userAgent?: string;
}

const REDACTED = '[REDACTED]';
const sensitiveKey =
  /pass(word|phrase)?|secret|token|authorization|cookie|api[-_]?key|hash$/i;

/** Removes credentials and tokens before history is persisted forever. */
export function redactForAudit(value: unknown): JsonValue | undefined {
  return redact(toJsonSafe(value));
}

function redact(value: JsonValue | undefined): JsonValue | undefined {
  if (Array.isArray(value)) return value.map((item) => redact(item) ?? null);
  if (value !== null && typeof value === 'object')
    return Object.fromEntries(
      Object.entries(value).map(([key, member]) => [
        key,
        sensitiveKey.test(key) ? REDACTED : (redact(member) ?? null),
      ]),
    );
  return value;
}

/**
 * Appends an audit entry in the caller's transaction, so history commits or rolls
 * back together with the change it describes. The actor is always the
 * authenticated member from context, never a caller-supplied user.
 */
export async function recordAudit(
  tx: Prisma.TransactionClient,
  context: OrganizationContext,
  entry: AuditEntry,
  metadata: AuditRequestMetadata = {},
) {
  const oldValues = redactForAudit(entry.before);
  const newValues = redactForAudit(entry.after);
  return tx.auditLog.create({
    data: {
      tenantId: context.tenantId,
      organizationId: context.organizationId,
      userId: context.userId,
      entityType: entry.entityType,
      entityId: entry.entityId,
      action: entry.action,
      ...(oldValues == null
        ? {}
        : { oldValues: oldValues as Prisma.InputJsonValue }),
      ...(newValues == null
        ? {}
        : { newValues: newValues as Prisma.InputJsonValue }),
      reason: entry.reason?.trim() || null,
      ipAddress: metadata.ipAddress ?? null,
      userAgent: metadata.userAgent?.slice(0, 500) ?? null,
    },
    select: { id: true },
  });
}
