import {
  organizationSelectionSchema,
  permissionCodeSchema,
} from '@repo/validation';
import type {
  OrganizationContext,
  OrganizationSelection,
  PermissionCode,
} from '@repo/types';
import type { Prisma, PrismaClient } from './generated/prisma/client.js';

export class OrganizationAccessDeniedError extends Error {
  constructor() {
    super('An active organization membership is required');
    this.name = 'OrganizationAccessDeniedError';
  }
}

export class UnsafeDatabaseRoleError extends Error {
  constructor() {
    super(
      'Organization access requires a non-owner database role without superuser or BYPASSRLS privileges',
    );
    this.name = 'UnsafeDatabaseRoleError';
  }
}

export class PermissionDeniedError extends Error {
  constructor() {
    super('The current membership does not have permission for this action');
    this.name = 'PermissionDeniedError';
  }
}

export function requirePermission(
  context: OrganizationContext,
  permission: PermissionCode,
) {
  if (!context.permissions.includes(permission))
    throw new PermissionDeniedError();
}

/**
 * Selection must come from authenticated server state, never request headers/body.
 * RLS context is transaction-local; pooled connections cannot retain another scope.
 * Membership, account status, and permissions are resolved again for every transaction.
 */
export async function withOrganization<T>(
  db: PrismaClient,
  selection: OrganizationSelection,
  work: (
    tx: Prisma.TransactionClient,
    context: OrganizationContext,
  ) => Promise<T>,
): Promise<T> {
  const scope = organizationSelectionSchema.parse(selection);
  return db.$transaction(
    async (tx) => {
      const [role] = await tx.$queryRaw<Array<{ unsafe: boolean }>>`
        SELECT r.rolsuper OR r.rolbypassrls OR r.rolcreaterole OR r.rolcreatedb OR EXISTS (
          SELECT 1 FROM pg_roles powerful
          WHERE (powerful.rolsuper OR powerful.rolbypassrls OR powerful.rolcreaterole OR powerful.rolcreatedb)
            AND pg_has_role(r.oid, powerful.oid, 'MEMBER')
        ) OR EXISTS (
        SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname = 'public' AND c.relname = 'organizations'
            AND pg_has_role(r.oid, c.relowner, 'MEMBER')
      ) AS unsafe
      FROM pg_roles r WHERE r.rolname = current_user
    `;
      if (!role || role.unsafe) throw new UnsafeDatabaseRoleError();

      await tx.$queryRaw`
      SELECT set_config('app.user_id', ${scope.userId}, true),
             set_config('app.tenant_id', ${scope.tenantId}, true),
             set_config('app.organization_id', ${scope.organizationId}, true)
    `;
      const membership = await tx.membership.findFirst({
        where: {
          ...scope,
          status: 'ACTIVE',
          user: { status: 'ACTIVE' },
          role: { status: 'ACTIVE' },
          organization: { status: 'ACTIVE', tenant: { status: 'ACTIVE' } },
        },
        include: {
          role: {
            include: { rolePermission_role: { include: { permission: true } } },
          },
        },
      });
      if (!membership) throw new OrganizationAccessDeniedError();
      const permissions = membership.role.rolePermission_role.map((mapping) =>
        permissionCodeSchema.parse(mapping.permission.code),
      );
      const context: OrganizationContext = Object.freeze({
        ...scope,
        permissions: Object.freeze(permissions),
      });
      return work(tx, context);
    },
    { maxWait: 10_000, timeout: 15_000 },
  );
}
