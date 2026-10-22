# Architecture and database foundation

## Scope and layers

The backend is an npm-workspace TypeScript monorepo. `apps/api` owns HTTP routes and
middleware. `packages/db` owns Prisma, migrations, tenancy, sequences, and seeds.
`packages/validation` owns shared enums and Zod contracts; `packages/types` derives
DTOs from those contracts. `packages/config` owns process settings and TypeScript
configuration. No frontend package is implemented in this task.

Future business modules follow route → validation → controller → service →
repository/Prisma. Controllers do not calculate financial amounts or orchestrate
multi-record writes. Services receive authenticated organization context, check
permissions, and execute all related writes in one scoped transaction.

## Ownership and relationships

User is global identity. Tenant is the account/branding boundary. Organization is
the factory/company boundary. Membership links users to organization-local roles;
a user can join several organizations and tenants. Default roles are organization
records; Permission is a platform catalog, linked through RolePermission.

All 43 organization-owned models have required `tenantId` and `organizationId`,
including child lines and allocations. Organization has a unique `(tenantId, id)`
key. Child-to-parent foreign keys include both scope IDs, backed by scoped parent
unique keys. Database foreign keys therefore reject cross-scope relationships even
when an ID is otherwise valid. Actor references point to a membership in the same
organization. The default-warehouse, active-schedule, active-BOM-version, and
default-role constraints are partial unique indexes in reviewed SQL migrations.

Payment allocations also carry the customer or supplier ID so both the payment and
invoice must belong to the same party. Installment allocation references carry the
invoice ID, and receipt/dispatch line references carry the relevant order/item
IDs. Production BOM/output references must match the order's product. Attachment
targets are checked against their scoped business table by a database trigger.

## Tenant isolation and authorization

PostgreSQL RLS is enabled and forced on all 47 non-catalog tables. The four global
catalogs are currencies, countries, permissions, and unit definitions. An unscoped
runtime query returns no owned records. User rows are restricted to the current
actor. Tenant/branding queries are tenant-scoped; organization and business queries
are organization-scoped. `idempotency_keys` is additionally restricted to the
current user, so members cannot see or replay each other's requests. Financial and inventory views use `security_invoker` so
they retain the underlying row policies.

Use `withOrganization(runtimeDb, selection, callback)` only after authentication
has established `selection.userId` on the server. Tenant/organization selection
must come from trusted authenticated state, with membership checked on every call;
do not trust request headers, query parameters, or caller-provided permissions.
The helper rejects superuser, BYPASSRLS, and table-owner connections. It sets
transaction-local PostgreSQL variables, checks active user/membership/role/
organization/tenant status, loads permissions from mappings, freezes context, and
then invokes the callback. Commit and rollback both remove the connection's scope.

```ts
await withOrganization(
  runtimeDb,
  authenticatedSelection,
  async (tx, context) => {
    requirePermission(context, 'customer.read');
    return tx.customer.findMany({
      where: {
        tenantId: context.tenantId,
        organizationId: context.organizationId,
        deletedAt: null,
      },
      take: 20,
    });
  },
);
```

RLS enforces data scope; service-level `requirePermission` enforces action-level
RBAC. Do not assume a read-only role is enforced by the shared database login.
Database session variables are a trusted-server mechanism, not end-user
authentication. Database credentials are never exposed to browsers. Raw SQL still
uses bound values and the same transaction. There are no new business HTTP routes
or identity-from-header shortcuts in this task.

`DATABASE_URL` is the restricted runtime connection. `MIGRATION_DATABASE_URL` is
the administrative migration/seed connection. The local provisioner creates a
non-owner role with no superuser, BYPASSRLS, database/role-creation, or replication
privileges. It grants catalogs read-only, stock/audit ledgers append-only, and
no access to Prisma's migration table. It saves an ignored private `.env` backup
before upgrading existing local bindings and never prints credential values.

Production API tasks must receive only the runtime URL. Migration jobs and
explicit tenant/account bootstrap code require separate privileged infrastructure;
never put the administrative URL in the API task. `db:provision` intentionally
refuses remote/production databases. Provision production roles through reviewed
infrastructure using the grant strategy in `packages/db/src/runtime-role.ts`.

Schema ownership alone does not bypass forced RLS. Local administrative fixtures
use the PostgreSQL administrator. Before production signup is implemented, Task #3
must define a narrow registration/bootstrap routine or dedicated authentication
role with explicit permissions; it must not give the API migration credentials.

## Types and precision

Primary keys use PostgreSQL-generated UUIDs. Audit timestamps use TIMESTAMPTZ(3).
Invoice/order/due dates use DATE because they represent business calendar dates;
movement, login, upload, and audit instants use TIMESTAMPTZ. Money uses
DECIMAL(18,2); quantities use DECIMAL(18,4). Wastage is a bounded percentage.
Emails/slugs/SKUs use CITEXT where case-insensitive identity is appropriate.

Financial input/output contracts use decimal strings. Use Prisma Decimal and
explicit rounding when business calculations are implemented. Row checks enforce
`total = subtotal - discount + tax` and
`lineTotal = round(quantity * unitPrice, 2) - discount + tax`; values must fit the
specified precision. Do not use JavaScript floating-point totals. Use
`calculateLineAmounts`/`calculateDocumentTotals` from `@repo/utils`: they use
ROUND_HALF_UP (PostgreSQL `round()` semantics, verified against the database in
tests). Header `subtotal` is the sum of gross line amounts (`round(qty × price, 2)`).
Header `discount`/`tax` are line totals plus document-level values. Raw BigInt file
sizes/counters also require explicit DTO serialization before future HTTP use.

## Integrity and lifecycle

Master data has soft-deletion timestamps. Financial parent documents cannot be
hard-deleted; use a state transition and required reason/actor/time metadata.
AuditLog has a first-class `reason` column for void/cancel/adjustment entries; write
it with `recordAudit` in the same transaction as the change.
AuditLog and InventoryMovement reject UPDATE and DELETE, including privileged
table-owner attempts. Reversals are new records; movements have a scoped optional
`reversalOfId`. Owned records cannot be reassigned to another scope.

Inventory rows require exactly one correctly typed raw material or product.
Quantities, amounts, dates, costs, and reservation limits have database checks.
Negative cached stock is rejected unless the organization's settings allow it.
All foreign-key deletes/updates restrict relationship breakage. No cascading
deletion can erase financial, stock, membership, or audit history.

`customer_invoice_balances` and `supplier_invoice_balances` derive paid/balance
amounts from billable invoices and allocations of POSTED payments. Draft/void
invoices do not create receivables/payables; schedules do not add another debt.
Voiding a payment excludes its allocations without deleting history.
`inventory_availability` derives on-hand minus reserved. These views are read models,
not substitutes for the later posting engines.

`nextDocumentNumber` atomically increments a scoped NumberSequence row and returns
the padded number. Call it in the same transaction that creates the document; a
failed transaction rolls the increment back. Never allocate numbers from counts.
Sequence prefixes are authoritative here rather than duplicated in settings.

## Idempotency and locking

`idempotency_keys` stores one committed response per member, organization, and
client key for 24 hours. `claimIdempotencyKey` uses `INSERT … ON CONFLICT` in the
request transaction, so concurrent duplicates wait on the unique index and then
replay. A rolled-back request leaves no key. `lockRows` takes `FOR UPDATE` locks
in ascending ID order on an allow-listed table to prevent lost updates and lock-order
deadlocks. See [API platform](api.md) for the HTTP contract.

## Migrations, ERD, and seeds

The original storage migration is preserved. The foundation migration adds all
new structures and scopes storage. It refuses a nonempty legacy unscoped storage
table instead of guessing ownership or dropping objects. Such a database needs an
explicit reviewed ownership-backfill migration before upgrading. The local
scaffold had no storage rows. The isolation migration adds RLS, checks, triggers,
partial indexes, and invoker-security views. A subsequent reason migration makes
NULL rejection explicit, since SQL CHECK otherwise accepts UNKNOWN.

Run `db:deploy` with migration credentials. Generate future migrations with Prisma
and review custom SQL separately. Never edit applied migration checksums. Roll
forward with corrective migrations; do not reset a shared database. Each new owned
table needs scope keys, scoped FKs, RLS, indexes, grants, and isolation tests.

The [domain ERD](erd.md) explains the model groups. The
[full generated ERD](schema.erd.mmd) includes every scalar field and concrete FK.
Run `npm run erd:generate` after schema changes; CI checks drift. SQL-only partial
indexes, policies, checks, views, and polymorphic attachment targets are described
here and in migration SQL because Prisma cannot express all of them.

`npm run db:seed` installs reference currencies/countries/units/permissions.
`npm run db:seed:demo` additionally creates Demo Factory, its invited owner,
roles/mappings/settings/sequences, Main Warehouse, units, expense categories,
ABC Raw Materials, XYZ Traders, Cotton, and Finished Fabric. Demo data is opt-in and
refused in production. No password or real financial/stock activity is fabricated.
`ensureOrganizationDefaults` is reusable by the future registration service inside
its privileged transaction. Seed runs serialize with an advisory lock, preserve
existing settings/role mappings/counters, and generate every record ID.

## Validation and next tasks

Integration tests create an isolated local database, replay every migration,
provision a restricted role, and exercise the real Prisma client. They require a
local administrative `MIGRATION_DATABASE_URL` (or `TEST_MIGRATION_DATABASE_URL`)
with CREATEDB/CREATEROLE and CITEXT installation rights. Only the generated test
database/role are dropped; the configured development database is never reset.
Tests cover cross-tenant and same-tenant organization isolation, active membership
and permission resolution, scoped writes/FKs, pooled connections, exact decimals,
derived balances, immutable history, attachments, sequence concurrency/rollback,
and seed repeatability. Shared enum tests prevent drift with Prisma.

Later business tasks must implement and test aggregate invariants in transactional
services: allocations must match currencies and cannot exceed a payment or invoice balance; schedule sums
must match the scheduled balance; goods receipts, production, dispatch, and stock
balances/movements must post atomically; posted lines cannot be silently edited;
and status transitions, audit emission, locking, and idempotency must be enforced.
Those workflows are not exposed or declared complete by a database foundation.
Authentication, account registration, invitations, and business OpenAPI routes
remain later backend tasks. Frontend work remains deferred.
