# Factory Management System — Roadmap after Task #1

This roadmap breaks the remaining work in the [blueprint](implementation-plan.md) into
self-contained tasks. Start each session with: _"Implement Task #N from
docs/plans/roadmap.md"_ plus the standard preamble in section 3. Task #1 (architecture and
database foundation) is complete; see [CONTEXT.md](../CONTEXT.md).

---

## 1. Where the codebase is today (Task #1 is done)

| Area                                                                                                                                                                                                                        | State                             | Where                                              |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- | -------------------------------------------------- |
| Monorepo (npm workspaces, TS, ESLint, Prettier, Vitest, CI)                                                                                                                                                                 | ✅ Done                           | root `package.json`, `.github/workflows/ci.yml`    |
| Express API shell: helmet, CORS allow-list, rate limit, pino request logging + request IDs, Zod `validateRequest`, `ApiError` + `errorHandler`, Swagger at `/docs`, `/openapi.json`                                         | ✅ Done (health/info routes only) | `apps/api/src/app.ts`, `middleware/`, `openapi.ts` |
| S3 object-storage service (presigned URLs)                                                                                                                                                                                  | ✅ Service only, no routes        | `apps/api/src/services/object-storage.ts`          |
| Prisma schema: 50 models, 26 enums, every blueprint entity                                                                                                                                                                  | ✅ Done                           | `packages/db/prisma/schema.prisma`                 |
| Migrations with RLS on 46 tables, scoped composite FKs, CHECKs, immutable ledgers (AuditLog, InventoryMovement), derived balance views (`customer_invoice_balances`, `supplier_invoice_balances`, `inventory_availability`) | ✅ Done                           | `packages/db/prisma/migrations/*`                  |
| Tenancy: `withOrganization()` + `requirePermission()`                                                                                                                                                                       | ✅ Done                           | `packages/db/src/tenancy.ts`                       |
| Atomic document numbers: `nextDocumentNumber()`                                                                                                                                                                             | ✅ Done                           | `packages/db/src/number-sequences.ts`              |
| Shared enums, 57 permission codes, `moneySchema`/`quantitySchema` decimal strings                                                                                                                                           | ✅ Done                           | `packages/validation/src/domain.ts`                |
| Seeds: catalogs + opt-in demo master data; `ensureOrganizationDefaults()`                                                                                                                                                   | ✅ Done                           | `packages/db/src/seeds/*`                          |
| Restricted runtime DB role provisioning                                                                                                                                                                                     | ✅ Local only                     | `packages/db/src/runtime-role.ts`                  |
| Authentication, onboarding, any business API, posting engines, audit writer, jobs, PDF, frontend, AWS IaC                                                                                                                   | ❌ Not started                    | —                                                  |

### Gaps found during analysis (each is assigned to a task below)

1. **No auth tables.** There is no session/refresh-token table, password-reset token table,
   or invitation token table. `User.passwordHash` exists. → Task 3, Task 4.
2. **Login and signup cannot work under current RLS.** The runtime role can only see the
   _current_ user's row, so it can't look up a user by email, and it can't create a new
   tenant. `database.md` explicitly says Task #2 must solve this _without_ giving the API
   migration credentials. → Task 3 (SECURITY DEFINER functions).
3. **No idempotency table**, but blueprint §91 requires it for payments and posting endpoints. → Task 2.
4. **No balance adjustment model.** Ledgers (§35–36) list "Credit Adjustments", but the schema has
   only `openingBalance`. → Task 10 (supplier side) and Task 13 (customer side).
5. **Error envelope mismatch.** The blueprint uses `error.fields: {}`, while the code returns a
   `details[]` array. → Task 2 (add `fields`, keep `details` + `requestId`).
6. **OpenAPI is hand-written** in `openapi.ts`. With ~120 endpoints it will drift unless it is
   generated from route definitions. → Task 2.
7. **Background jobs can't scan across organizations** under RLS, and `withOrganization` needs a user
   membership. Jobs need a reviewed "system actor" path. → Task 17.
8. **No money calculation library.** `moneySchema` validates strings, but nothing computes
   line/subtotal/tax/total with Prisma Decimal and the rounding rules the DB CHECKs enforce. → Task 2.

---

## 2. Recommended order and dependency graph

```
Backend (AGENTS.md: frontend deferred)
 2 API platform infra ─► 3 Auth & onboarding ─► 4 Org/settings/users ─► 5 Master data
                                                            │            │
                                         6 Attachments ◄────┘            ▼
                                                              7 Inventory engine
                                                                         │
                     ┌───────────────────────────────────────────────────┤
                     ▼                                                   ▼
 8 Purchase orders & goods receipts                    11 Sales orders & sales invoices
 9 Supplier invoices                                   12 Payment schedules (installments)
10 Supplier payments + supplier ledger                 13 Customer payments + customer ledger
                     └──────────────┬────────────────────────────────────┘
                                    ▼
          14 Expenses · 15 BOM & production · 16 Dispatch
                                    ▼
          17 Jobs + notifications · 18 Invoice PDF + CSV export
                                    ▼
          19 Dashboard + reports + transactional demo seed      ◄── backend MVP complete
Frontend
20 Web foundation & design system ─► 21 Auth/onboarding/dashboard/shell ─► 22 Master data UI
 ─► 23 Purchase & payables UI ─► 24 Sales & receivables UI ─► 25 Inventory/production/
    dispatch/expenses UI ─► 26 Reports/settings/notifications/audit UI ─► 27 PWA & mobile
Hardening & release
28 Playwright E2E ─► 29 Security & tenant-isolation review ─► 30 AWS staging deployment
```

**MVP cut (blueprint §84):** Tasks 2–14 and 17–19 on the backend, then 20–24 and 26–30.
Tasks 15, 16 and 25 (production, dispatch, and their UI) can come right after the first
release. The DB already supports them.

**Parallelism:** After Task 7, the purchase track (8–10) and the sales track (11–13) are
independent and can run in separate sessions. Task 20 can start any time after Task 3,
because it only needs the auth contract and the OpenAPI pipeline.

---

## 3. Standard preamble to paste with every task

> Read `AGENTS.md`, `docs/CONTEXT.md`, `docs/architecture/database.md`, and
> `docs/plans/roadmap.md` (this task's section) before changing code. Use the
> blueprint `docs/plans/implementation-plan.md` as reference only. Implement **only** this task.
> Rules: route → validation → controller → service → Prisma. All org data access goes through
> `withOrganization` + `requirePermission` using identity from the authenticated session, never
> request fields. Money and quantities are decimal strings in the API and Prisma Decimal in services.
> The server computes all totals. Never mutate stock without an InventoryMovement or financial data
> without an AuditLog. Schema changes go in new migrations, with RLS, scoped FKs, grants, and an
> isolation test for every new owned table. Regenerate the ERD and OpenAPI. Done means `npm run build`,
> `lint`, `test`, `test:integration`, and `format:check` all pass. Update `docs/CONTEXT.md` with
> what was delivered.

**Standard "Definition of Done" for each backend task:** migration (if any), Zod contracts in
`packages/validation`, service with transactions and locking, routes registered in OpenAPI
with permission and error docs, audit entries, unit tests for calculations, integration tests
for happy path, failure path, and cross-tenant/cross-org denial, and updated docs.

---

## 4. Task definitions

### Task 2 — API platform infrastructure (shared plumbing for every module)

**Status:** ✅ Complete — see [API platform](../architecture/api.md).

**Goal:** Every later module becomes a thin, consistent addition.
**Depends on:** Task 1.
**Build:**

- **Module layout:** `apps/api/src/modules/<domain>/{routes,controller,service,schemas,tests}.ts`,
  matching blueprint §86. Mount everything under `/api/v1`.
- **Route definition helper** (e.g. `defineRoute({ method, path, permission, params, query, body,
response, errors, summary, tags, idempotent })`). It does four things from one declaration:
  registers the Express handler, runs validation, enforces the permission, and **generates the
  OpenAPI path**. This replaces hand-editing `openapi.ts` and prevents drift (§65). CI already
  diffs `docs/openapi.json`.
- **Org-scoped handler wrapper:** it reads the authenticated selection from `res.locals.auth`
  (populated in Task 3; stub it here behind an interface), calls `withOrganization`, and passes
  `(tx, context)` to the service.
- **Response envelopes:** `{ data }` for single resources and `{ data, meta: { page, pageSize, total,
totalPages } }` for lists.
- **Shared list query schema:** `page`, `pageSize` (default 20, max 100), `search`, `status`, `sortBy`
  (per-resource allow-list), `sortOrder`, `dateFrom`, `dateTo`.
- **Error mapping:**
  - Add `fields: Record<path, message>` to the error envelope (keep `details`, `requestId`).
  - Map `PermissionDeniedError` → 403 `FORBIDDEN`, `OrganizationAccessDeniedError` → 403, and
    Prisma `P2002` → 409 `DUPLICATE`, `P2003`/`P2025` → 409/404.
  - Map PG check violations → 422 with plain-language messages (§106). Technical detail is logged only.
- **Money library** in `packages/utils` (or a `packages/domain`), using Prisma Decimal / decimal.js:
  `lineTotal = round(qty × unitPrice, 2) − discount + tax` and
  `total = subtotal − discount + tax`. Use the exact rounding the DB CHECKs require
  (`database.md` "Types and precision"). Add serializers for Decimal → string and BigInt → string.
- **Audit writer:** `recordAudit(tx, context, { entityType, entityId, action, before, after, reason })`
  inside the same transaction. Redact secrets.
- **Idempotency:** a new migration adds `idempotency_keys`, scoped by tenant/org/user, with key,
  request hash, response status/body, and expiry, under RLS. Middleware reads the
  `Idempotency-Key` header: it replays the stored response for the same key and hash, and returns
  409 for the same key with a different body.
- **Locking helper:** `lockRows(tx, table, ids)` using `SELECT … FOR UPDATE` in a deterministic
  ID order to avoid deadlocks.
- **Logging:** add `userId`, `tenantId`, and `organizationId` to the pino child logger once they
  are known. Never log bodies of auth routes.

**Out of scope:** auth itself, any business endpoint.
**Tests:** money library unit tests (rounding, large values, negative rejection), error mapping,
idempotency replay and conflict, OpenAPI generation snapshot.

### Task 3 — Authentication & self-service onboarding

**Goal:** Implement blueprint §5 and §42. A user registers (name, email, password, company) and
lands on an active org.
**Depends on:** Task 2.
**Build:**

- **Migration** with `user_sessions` (refresh-token family, hashed token, user agent, IP, expiresAt,
  revokedAt, rotatedFromId) and `password_reset_tokens` (hashed, single-use, expiry).
- **SECURITY DEFINER SQL functions** owned by a dedicated non-login role. They give the runtime
  role `EXECUTE` only and pin `search_path`. They are needed because RLS blocks these operations
  for the runtime role:
  - `auth_find_user_by_email(email)` returns only id, hash, and status.
  - `auth_register_account(name, email, passwordHash, companyName)` creates User (ACTIVE), Tenant
    (unique slug), Organization, OWNER membership, and runs the same defaults as
    `ensureOrganizationDefaults()` (settings, warehouse, sequences, roles + mappings, units,
    expense categories) atomically.
  - `auth_list_memberships(userId)` returns the user's org choices.
  - Session and reset-token helpers.
  - Document the grants in `runtime-role.ts` and `database.md`. The API still never receives
    `MIGRATION_DATABASE_URL`.
- **Passwords:** argon2id, with a minimum length and a breached-pattern check kept simple.
- **Tokens:** short-lived access JWT (≈15 min) plus a rotating refresh token, both in
  `HttpOnly; Secure; SameSite=Lax` cookies. Reuse detection revokes the whole family. Add CSRF
  protection (double-submit token or `SameSite=Strict` plus an Origin check) for cookie-auth
  mutations.
- **Endpoints:** `POST /auth/register`, `/login`, `/logout`, `/refresh`, `/forgot-password`,
  `/reset-password`, `GET /auth/me` (user, memberships, active org, permissions, tenant branding),
  and `POST /auth/switch-organization`. The active org is stored in the session, never read from
  a header or query.
- **Auth middleware:** populates `res.locals.auth = { userId, tenantId, organizationId }` from the session.
- **Stricter rate limits** on login, register, and forgot-password. Login returns a generic error
  message.
- **Email delivery:** stub it with a logged "mail outbox" interface. SES comes later. Reset links
  must not be logged in production.

**Tests:** register creates all defaults; duplicate email; login; wrong password; refresh rotation
and reuse detection; logout; reset flow; an invited or suspended user is denied; switching to a
non-member org is denied; an unauthenticated org route returns 401.

### Task 4 — Organization, settings, users, roles & invitations

**Depends on:** Task 3.
**Build:**

- `GET/PATCH /organizations/current`, `GET/PATCH /organization-settings`.
- `GET /number-sequences` and `PATCH /number-sequences/:type` (prefix and padding only; the current
  number is never lowered).
- `GET /tenant/branding` (read; editing is limited to OWNER, minimal per §112).
- `GET /roles` with their permissions, `GET /members`, `POST /members/invitations` (email + role,
  with a migration for a hashed `invitation_tokens` table), `POST /auth/accept-invitation` (sets
  the password and activates the membership through a SECURITY DEFINER function),
  `PATCH /members/:id` (change role, suspend). The last active OWNER can't be removed or demoted.
- Audit every change.

**Tests:** permission matrix (VIEWER can't PATCH); invitation accept, expired, and reused tokens;
last-owner guard; cross-org isolation.

### Task 5 — Master data APIs

**Depends on:** Task 4.
**Build:** CRUD for **customers, suppliers, units, warehouses, raw materials, products, expense
categories**, following blueprint §45–48 and §60.

- List endpoints support search on name, code, phone, and SKU, plus status filters and pagination.
- `DELETE` is a soft delete (`deletedAt`). It is rejected with a friendly 409 if the record is
  referenced by open documents.
- Auto-generate customer and supplier codes if the schema has them. Enforce SKU uniqueness per org.
- Product and raw-material `GET /:id/stock` and `/movements` endpoints are added in Task 7.
- Ledger, outstanding, orders, and invoices sub-routes are added in Tasks 10 and 13.
- Credit limit is stored here. Warnings are computed in Task 11.
- Default warehouse switching respects the partial unique index.

**Tests:** CRUD, search, soft-delete hiding, duplicate SKU → 409, isolation, permissions.

### Task 6 — Attachments (documents)

**Depends on:** Task 5. Reuse `apps/api/src/services/object-storage.ts`.
**Build:**

- `POST /attachments/upload-url` validates entity type and ID (it must exist in scope), content
  type allow-list, and size limit, then returns a presigned PUT with the key
  `tenant/org/entity/uuid`.
- `POST /attachments` confirms the upload with a HEAD check on S3 and creates StoredObject +
  Attachment.
- `GET /attachments?entityType&entityId` returns short-lived presigned GET URLs that are generated
  per request and never stored.
- `DELETE /attachments/:id` is a soft delete plus an S3 delete (or lifecycle policy).
- The DB trigger already validates targets. Write an audit entry.

**Tests:** S3 mocked in unit tests; MinIO or S3 mock in integration; isolation; attaching to
another org's record is rejected.

### Task 7 — Inventory movement engine (core, used by Tasks 8, 15, 16)

**Depends on:** Task 5.
**Build:**

- **One service, `postInventoryMovements(tx, context, movements[])`.** For each movement it locks
  the `InventoryBalance` row (creating it if missing), checks `allowNegativeStock`, appends the
  immutable `InventoryMovement`, and updates the cached balance. Reversals create opposite
  movements with `reversalOfId`.
- This is the **only** code path allowed to change stock.
- Store valuation fields if the schema has them (unit cost on receipt, moving average for
  materials). Keep it simple and document the method.
- **APIs (§57):** `GET /inventory`, `/inventory/low-stock` (reorderLevel vs available, using the
  `inventory_availability` view), `/inventory/movements`, `/inventory/raw-materials`,
  `/inventory/products`, `POST /inventory/adjustments` (item, warehouse, signed quantity, required
  reason, notes; idempotent; audited), and `GET /raw-materials/:id/stock|movements` and
  `/products/:id/stock|movements`.

**Tests:** concurrency (two parallel adjustments must not lose updates); a negative-stock block,
and the same case with the setting enabled; reversal; ledger immutability; the cached balance
equals the sum of movements.

### Task 8 — Purchase orders & goods receipts

**Depends on:** Task 7.
**Build:**

- **PO (§49):** create and edit drafts with lines (server-computed totals), `confirm` (allocates
  `PO-` number via `nextDocumentNumber`), `cancel` (only if nothing has been received),
  `GET /:id/receipts`.
- **Goods receipt (§50):** create a draft against a PO (or ad-hoc without a PO if the schema
  allows). `post` is idempotent and does the following in one transaction:
  - lock the PO lines
  - validate that the received quantity is ≤ ordered − already received
  - post `PURCHASE_RECEIPT` movements through Task 7's engine
  - set PO status to PARTIALLY_RECEIVED or RECEIVED
  - write an audit entry
- `cancel` on a posted receipt creates reversal movements and recomputes PO status.
- Posted lines are immutable.
- Add `GET /suppliers/:id/purchases`.

**Tests:** partial receipt then full receipt; over-receipt rejected; double-post replay; cancel
reversal restores stock; status transitions table.

### Task 9 — Supplier invoices (payables origin)

**Depends on:** Task 8.
**Build (§51):**

- Create and edit drafts, optionally linked to a PO or goods receipts, with lines.
- Uniqueness on `(org, supplierId, supplierInvoiceNumber)`.
- Due date defaults from supplier payment terms or org defaults.
- `post` makes the payable exist (status UNPAID).
- `void` requires a reason and is blocked while POSTED allocations exist (the user must void the
  payment first, with a friendly message).
- Paid and balance amounts come from the `supplier_invoice_balances` view, never from stored
  columns.

**Tests:** totals; duplicate number; void rules; balance view correctness; isolation.

### Task 10 — Supplier payments, supplier ledger & outstanding

**Depends on:** Task 9.
**Build:**

- `POST /supplier-payments` follows the §52 payload and is idempotent. In one transaction it:
  - locks the payment's invoices
  - validates that each allocation is > 0, ≤ the invoice balance, that the sum is ≤ the payment
    amount, that the currency matches, and that each invoice belongs to the same supplier
  - creates the payment (number allocated) and its allocations
  - updates invoice statuses (PARTIALLY_PAID / PAID)
  - writes an audit entry
- An unallocated remainder is allowed and is stored as an advance or credit.
- `void` excludes allocations, recomputes statuses, and is audited.
- **Migration:** `supplier_balance_adjustments` (dated, signed amount, reason, audited, voidable),
  with RLS.
- `GET /suppliers/:id/ledger` builds rows from opening balance, invoices, payments, and adjustments,
  with debit, credit, and running balance, a date range, and an opening carry-forward. Also add
  `/suppliers/:id/outstanding` and `/suppliers/:id/payments`.
- Ledger logic lives in one SQL/view-backed service that is reused by reports (Task 19).

**Tests:** spec examples (500k split 200k + 300k); over-allocation; a concurrent double payment
against the same invoice; void then re-pay; ledger running balance equals outstanding.

### Task 11 — Sales orders & sales invoices (receivables origin)

**Depends on:** Task 7 (stock reservation optional), Task 5.
**Build:**

- **Sales order (§53):** drafts with lines, `confirm` (number allocated), `cancel` (blocked once
  invoiced or dispatched), `GET /:id/invoices|dispatches`, `GET /customers/:id/orders`.
- A credit-limit **warning**, not a block, is returned in `meta.warnings` when a customer's
  outstanding plus the new order exceeds their limit.
- **Sales invoice (§54):** create from an order (supports **partial invoicing**: invoiced quantity
  ≤ ordered − already invoiced) or standalone.
- `post` allocates the `INV-` number and starts the receivable.
- `PATCH` is allowed only on drafts. Amount changes are audited (§102).
- `void` requires a reason and is blocked while live allocations exist. Any payment schedule is
  cancelled.
- The OVERDUE status is set by the Task 17 job. The balance comes from the
  `customer_invoice_balances` view.
- Add `GET /customers/:id/invoices`. The PDF route is added in Task 18.

**Tests:** partial invoicing across two invoices; over-invoicing rejected; totals and tax;
credit-limit warning; void rules.

### Task 12 — Payment schedules (installments)

**Depends on:** Task 11.
**Build (§24, §55):**

- `POST /sales-invoices/:id/payment-schedule` supports WEEKLY or MONTHLY (start date, count or
  amount per installment) and CUSTOM (explicit date/amount rows).
- **Rules:**
  - The installment sum must equal the invoice's _current balance_ exactly.
  - Rounding is done to the cent, and the remainder goes to the last installment.
  - Month-end dates are clamped (Jan 31 → Feb 28/29).
  - Only one ACTIVE schedule per invoice (the partial index already exists).
  - Schedules never create extra receivable (§34).
- `GET` the schedule. `PATCH /payment-schedules/:id` edits unpaid installments only, and the sum is
  revalidated. `POST /:id/regenerate` cancels the old schedule and rebuilds it from the remaining
  balance, keeping paid installments as history.
- Installment status (UPCOMING / DUE / PARTIALLY_PAID / PAID / OVERDUE) is derived from allocations
  and dates. Put the pure function in shared domain code and unit-test it.

**Tests:** heavy unit coverage of the generator (odd cents, leap years, 1 vs 36 installments);
regeneration after a partial payment.

### Task 13 — Customer payments, customer ledger & receivables

**Depends on:** Task 12.
**Build:**

- `POST /customer-payments` is idempotent and mirrors Task 10. Allocations go to invoices and,
  optionally, to installments (FIFO auto-allocation by due date when the client sends none — "Receive
  Payment" UX).
- In one transaction it locks rows, validates, and updates invoice and installment statuses.
- `void` reverses the effects without deleting anything.
- **Migration:** `customer_balance_adjustments` (credit notes or adjustments).
- Add `GET /customers/:id/ledger`, `/outstanding`, and `/payments`.
- Reuse the ledger builder pattern from Task 10. Extract it to a shared helper rather than copying it.

**Tests:** partial payment spanning two installments; auto-allocation order; concurrent
payments; void restores the installment state; ledger equals outstanding.

### Task 14 — Expenses

**Depends on:** Task 5.
**Build:** expense CRUD (§60) with category, date, amount, payment method, payee, notes, and an
optional attachment.

- POSTED expenses can't be hard-deleted. `DELETE` on a draft is allowed. Posted expenses are voided
  with a reason.
- Allocate an `EXP-` number.
- Add `GET/POST /expense-categories`.

**Tests:** CRUD; void rules; category isolation.

### Task 15 — BOM & production (post-MVP-ready)

**Depends on:** Task 7.
**Build:**

- `GET/PUT /products/:id/bom` creates a new version and archives the previous one. Only one ACTIVE
  version per product (the partial index exists). Lines carry quantity per unit and wastage %.
- **Production order (§58):** create (product, planned quantity, BOM snapshot, optional sales-order
  link) → `start` → `complete`. Completion is one idempotent, locked transaction that:
  - calculates expected consumption from the BOM, allowing actual-consumption overrides
  - posts `PRODUCTION_CONSUMPTION` movements
  - posts `PRODUCTION_OUTPUT` for good quantity
  - records rejected or waste quantity
  - updates the order and the linked sales-order status (IN_PRODUCTION / READY)
- `cancel` is allowed before completion only.

**Tests:** stock math; insufficient material blocked (unless negative stock is allowed); the BOM
product must match; double-complete replay.

### Task 16 — Dispatch (post-MVP-ready)

**Depends on:** Task 11 (and 15 optionally).
**Build (§30, §59):**

- Create a draft from a sales order (supports **partial dispatch**: quantity ≤ ordered − dispatched),
  with vehicle, driver, and delivery address.
- `post` is idempotent and locked. It posts `SALE_DISPATCH` movements and updates the SO status to
  PARTIALLY_DISPATCHED or DISPATCHED.
- Add a `deliver` status update.
- `cancel` on a posted dispatch creates reversal movements.
- Optionally create an invoice from the dispatch (sales flow §116).

**Tests:** partial dispatches; over-dispatch; insufficient stock; reversal.

### Task 17 — Background jobs & in-app notifications

**Depends on:** Tasks 10, 13, 7.
**Build:**

- **Job runner:** pg-boss on the existing Postgres (no new infrastructure), running as a separate
  worker process and ECS service entry point.
- **System actor design (security-critical; document it in `database.md`):**
  - A SECURITY DEFINER `system_list_active_organizations()` returns the orgs to process.
  - A `withSystemOrganization(db, orgId, work)` sets RLS scope for a single org with a
    `app.actor = system` flag, with policies or grants that allow only the reads and inserts the
    jobs need.
  - Never bypass RLS globally.
- **Daily jobs per org (in the org timezone):**
  - mark overdue invoices and installments
  - upcoming installment reminders
  - supplier invoices due
  - low raw-material stock (if `lowStockNotificationsEnabled`)
  - order delivery approaching
- De-duplicate with a unique `(org, type, entity, date)` key.
- **APIs (§64):** `GET /notifications` (current user, with unread count), `POST /:id/read`,
  `POST /read-all`.

**Tests:** job idempotency (running it twice creates no duplicates); timezone boundary; isolation
between orgs in one job run.

### Task 18 — Invoice PDF & CSV export

**Depends on:** Tasks 12, 13.
**Build:**

- `GET /sales-invoices/:id/pdf` contains the §100 fields: company and tenant invoice branding,
  lines, tax, discount, total, paid, balance, schedule, and notes.
- Use a server-side renderer (e.g. `pdfkit`, or Playwright HTML-to-PDF in the worker for larger
  documents).
- Streamed; no public URLs.
- CSV export helper (`?format=csv`) for list and report endpoints, with streaming and a row cap.
  Exports large enough to need it run as a background job that delivers an S3 presigned link.

**Tests:** PDF content snapshot (text extraction); CSV escaping and decimals.

### Task 19 — Dashboard, reports & transactional demo seed

**Depends on:** Tasks 10, 13, 14 (and 15/16 when present).
**Build:**

- `GET /dashboard/summary` returns every §44 field in **one** request, using a few aggregate SQL
  queries (no N+1).
- **Reports (§61):** sales, purchases, receivables, receivables-aging (0–30/31–60/61–90/90+),
  payables, payables-aging, inventory, customer-ledger, supplier-ledger, expenses,
  payment-collections, order-status, production.
- Filters: dateFrom, dateTo, customerId, supplierId, status. Support CSV through Task 18.
- `GET /audit-logs` and `/audit-logs/:entityType/:entityId` (§63, `audit.read` only).
- **Extend `db:seed:demo`:** it creates realistic transactions **through the services**, never raw
  inserts, so all invariants hold. That means purchases, receipts, supplier invoices and partial
  payments, orders, invoices, a monthly schedule, partial receipts, expenses, and low stock, so
  the dashboard shows meaningful data. Activate the demo owner with a password taken from an env
  variable, never committed.

**Tests:** dashboard numbers reconcile with the ledgers; aging bucket edges; report isolation.
**Milestone:** Backend MVP is complete and the OpenAPI contract is frozen as v1.

### Task 20 — Web foundation & design system

**Depends on:** Task 3 (auth contract), OpenAPI pipeline.
**Build:**

- Next.js (App Router, TS) in `apps/web` and Tailwind with a component library in `packages/ui`.
- Theme tokens (§81–82 status colours), with tenant branding applied at runtime (app name, logo,
  colours; no hard-coded product name, §112).
- Typed API client generated from `docs/openapi.json` (e.g. openapi-typescript + openapi-fetch),
  with TanStack Query hooks.
- React Hook Form + Zod reusing `packages/validation` schemas. Display only; no financial
  calculation is authoritative on the client (§88, §109).
- Cookie auth with silent refresh. Map the error envelope to field errors.
- **Base components:** AppShell (sidebar on desktop, bottom nav on mobile §67/§79), page header,
  data list/table that turns into cards on mobile, empty state (§105 copy pattern), money and
  quantity inputs (decimal strings), date picker, status badge, confirmation sheet (§73),
  toast, skeleton, error state.
- Add CI for web: lint, typecheck, build.

### Task 21 — Auth, onboarding, app shell & dashboard UI

Login, Register/Company setup (four fields, redirects straight to the dashboard, §5), forgot and
reset password, accept invitation, and an org switcher.
**Dashboard (§68):** "What do I need to do?" cards (money to receive, money to pay, overdue, low
stock, orders), quick actions (§69: Receive Payment, Pay Supplier, New Order, Add Purchase, Add
Expense). Mobile-first.

### Task 22 — Master data UI

Customers and suppliers (list, detail with tabs for overview, ledger, invoices/purchases,
payments, documents), raw materials, products, warehouses, and units. Includes create/edit forms
with smart defaults (§71–72), soft delete with confirmation, and empty states.

### Task 23 — Purchase & payables UI

Implements the §76 purchase UX:

- Purchase (PO) form → Receive Material → Supplier Invoice.
- "Pay Supplier" flow with suggested allocations to the oldest unpaid invoices.
- Supplier balances, supplier ledger view, and attachments on purchases and invoices.
- Idempotency key per submit to survive double-taps.

### Task 24 — Sales & receivables UI

Implements the §74–75 UX:

- Order → Invoice (partial, from order) → Payment schedule builder (weekly, monthly, custom, with
  a live preview from the server) → "Receive Payment" with auto-allocation.
- Invoice detail with paid/balance/schedule timeline, PDF download, void with reason.
- Customer ledger.

### Task 25 — Inventory, production, dispatch & expenses UI

Implements §77:

- Stock list with low-stock highlighting, movement history, and adjustment with a reason.
- BOM editor and production order lifecycle.
- Dispatch from order.
- Expense entry (fast mobile form) and list.

### Task 26 — Reports, settings, notifications & audit UI

- Reports hub with filters and CSV/PDF export.
- Settings: company, invoice settings, numbering, users and roles, invitations, branding.
- Notification bell and list.
- Audit history panel on financial documents (permission-gated).
- Global search (§78) across customers, suppliers, invoices, orders, and materials. If a search
  endpoint is needed, add a small backend endpoint in this task.

### Task 27 — PWA & mobile optimization

Implements §79–80 and Phase 11:

- Manifest from tenant branding, service worker caching the app shell only (no offline
  transactions, per §103), and an install prompt.
- Touch targets, bottom nav, and Lighthouse PWA/performance budget checks.

### Task 28 — End-to-end tests (Playwright)

Covers the §94 E2E scenario: onboarding → supplier → purchase → receive → pay supplier → customer
→ order → invoice → monthly schedule → partial payment → dashboard check.

- Add a second-tenant isolation E2E test.
- Runs in CI against docker-compose Postgres with seeded catalogs.

### Task 29 — Security & tenant-isolation review

- Systematic check of every route: auth required, permission declared, no scope taken from
  request input.
- Fuzz cross-tenant IDs on every `:id` route.
- Review SECURITY DEFINER functions, cookie/CSRF/CORS/headers, rate limits, S3 key scoping and
  content types, log redaction, dependency audit, and secrets scan.
- Fix findings and write `docs/security.md`.

### Task 30 — AWS staging deployment

- IaC (AWS CDK in TS, so it fits the monorepo) for: VPC, RDS PostgreSQL (TLS, backups), the S3
  documents bucket (private, block public access), ECR, and ECS Fargate services for the API,
  worker, and web.
- One-off migration task with a separate secret; runtime role grants via a reviewed provisioning
  step.
- ALB + CloudFront, Secrets Manager, CloudWatch logs, alarms for 5xx, slow requests, job failures,
  and failed financial transactions (§97), and WAF rate limiting.
- GitHub Actions deploy pipeline to staging, with a smoke test against the deployed staging
  environment (`scripts/smoke.mjs`).
