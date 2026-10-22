# API platform

Every `/api/v1` endpoint is declared once with `organizationRoute` or `publicRoute`
(`apps/api/src/http/route.ts`). That single declaration registers the Express handler,
validates params/query/body, authenticates, enforces the permission, opens the scoped
transaction, validates and strips the response, and generates the OpenAPI operation.
Controllers and documentation cannot drift: CI regenerates `docs/openapi.json` and
fails on a diff, and startup rejects duplicate operations or path/params mismatches.

## Module layout

```text
apps/api/src/modules/<domain>/
  routes.ts    route declarations; each handler is the thin controller
  service.ts   business rules, calculations, multi-record writes (receives tx + context)
  schemas.ts   module-local Zod schemas (shared contracts go in packages/validation)
apps/api/test/<domain>*.test.ts   unit and *.integration.test.ts tests
```

Register the module's route array in `apps/api/src/modules/index.ts`. Handlers parse
nothing themselves, compute no money, and return the declared response body.

```ts
organizationRoute({
  method: 'post',
  path: '/customer-payments',
  operationId: 'createCustomerPayment',
  summary: 'Receive a payment',
  tags: ['Customer payments'],
  permission: 'customer-payment.write',
  idempotent: true,
  body: createCustomerPaymentSchema,
  response: {
    status: 201,
    description: 'Payment recorded',
    schema: dataEnvelope(paymentSchema),
  },
  errors: [
    {
      status: 409,
      code: 'OVER_ALLOCATED',
      description: 'Allocation exceeds balance',
    },
  ],
  handler: async ({ body, tx, context, audit }) =>
    single(await receivePayment(tx, context, body, audit)),
});
```

## Request lifecycle (organization routes)

1. `resolveAuthentication` asks the `Authenticator` for the session's
   `{ userId, tenantId, organizationId }` and stores it in `res.locals.auth`. The
   default authenticator denies everyone; Task 3 supplies the session implementation.
   No identity or scope is ever read from headers, query, or body.
2. No session → `401 UNAUTHENTICATED` before validation or any database work.
3. Params, query, and body are parsed with their schemas → `422 VALIDATION_ERROR`.
4. `withOrganization` opens one transaction, sets RLS scope, and re-checks the active
   membership → `403 ORGANIZATION_ACCESS_DENIED`. `requirePermission` checks the
   declared permission → `403 FORBIDDEN`.
5. Idempotent routes claim their key (below), then the handler runs with
   `{ params, query, body, tx, context, audit, request, log }`.
6. The result is validated against the response schema (undeclared fields are
   stripped; a contract violation is a 500), the transaction commits, and only then is
   the response sent.

Public routes skip steps 1–2 and 4–5 and additionally receive `req`/`res`.

## Responses and lists

Single resources return `single(data)` → `{ data }`. Lists use
`listQuerySchema({ sortBy, defaultSortBy, filters })` and `paginated(rows, total, query)`
→ `{ data, meta: { page, pageSize, total, totalPages } }`. `pageArgs(query)` gives
Prisma `skip`/`take`. Page size defaults to 20 and is capped at 100. Sorting is limited
to each resource's declared columns. `dateFrom`/`dateTo` are ISO dates. Resource filters
such as `status` or `customerId` are passed in `filters` and must be optional.

Money and quantities are decimal strings (`moneySchema`, `quantitySchema`). Format
Prisma Decimal values with `toMoneyString`/`toQuantityString`. As a fallback, the
runner converts any Decimal/BigInt to strings and Dates to ISO strings.

## Errors

The envelope is `{ error: { code, message, requestId, details?, fields? } }`. `fields`
maps each invalid path to its first message for form binding. `lib/error-mapping.ts`
converts thrown values:

| Source                                  | Status / code                         |
| --------------------------------------- | ------------------------------------- |
| `ApiError`                              | as thrown                             |
| `PermissionDeniedError`                 | 403 `FORBIDDEN`                       |
| `OrganizationAccessDeniedError`         | 403 `ORGANIZATION_ACCESS_DENIED`      |
| `RecordNotFoundError`, Prisma `P2025`   | 404 `NOT_FOUND`                       |
| `MoneyCalculationError`                 | 422 `VALIDATION_ERROR` with the field |
| Prisma `P2002` / SQLSTATE 23505         | 409 `DUPLICATE`                       |
| Prisma `P2003` / 23503                  | 409 `REFERENCE_CONFLICT`              |
| SQLSTATE 23514 (CHECK or guard trigger) | 422 `BUSINESS_RULE_VIOLATION`         |
| SQLSTATE 22003                          | 422 `VALUE_OUT_OF_RANGE`              |
| `P2034`, 40001, 40P01                   | 409 `CONCURRENT_UPDATE` (retry)       |
| `P2028`                                 | 503 `TRY_AGAIN`                       |
| anything else                           | 500 `INTERNAL_ERROR`                  |

Check-violation messages are chosen from the constraint name in plain language
(§106). The SQLSTATE, constraint, and table are logged at `warn`. Failing-row data and
Prisma query arguments are never logged or returned. Throw `ApiError` for business-rule
failures detected in services, with a stable `code` and a plain-language message.

## Idempotency

Routes declared `idempotent: true` require an `Idempotency-Key` header (8–128 of
`A–Z a–z 0–9 _ . : -`; send a UUID) → `428` when missing, `400` when malformed. The
key is claimed with `INSERT … ON CONFLICT` inside the request transaction:

- First request: the work runs and the response status/body is stored in the same
  commit. Failed requests roll back the claim, so the client may retry with the same key.
- Retry with the same key, method, path, and validated input: the stored response is
  replayed with `Idempotent-Replayed: true`. No handler code runs.
- Concurrent duplicates block on the unique index until the first transaction ends,
  then replay its result. This prevents double payments from double taps.
- Same key, different request: `409 IDEMPOTENCY_KEY_REUSED`.
- Keys are private to one member in one organization (RLS) and expire after 24 hours.
  Expired keys are reclaimed on reuse. Purging old rows belongs to the Task 17 jobs.

Membership and permission are checked again before a replay.

## Audit, locking, and money helpers

- `audit(entry)` in handlers, or `recordAudit(tx, context, entry, metadata)` in
  services, appends to `audit_logs` in the same transaction. The actor is always the
  authenticated member. `reason` is a first-class column, and keys that look like
  passwords, tokens, secrets, cookies, or hashes are stored as `[REDACTED]`.
- `lockRows(tx, context, table, ids)` takes `SELECT … FOR UPDATE` locks in ascending ID
  order on an allow-listed table, and raises `RecordNotFoundError` for missing or
  out-of-scope IDs. Lock every row a workflow will change (balances, invoices,
  installments) before reading the values it validates.
- `calculateLineAmounts` and `calculateDocumentTotals` (`@repo/utils`) compute with
  decimal.js using ROUND_HALF_UP, which matches PostgreSQL `round()`:
  `lineTotal = round(qty × unitPrice, 2) − discount + tax`. Header `subtotal` is the
  sum of gross line amounts, `discount`/`tax` include line plus document values, and
  `total = subtotal − discount + tax`. Inputs are validated for sign, scale, and column
  range, with field paths such as `lines.2.discount`. Numbers are rejected; pass strings.

## Logging

Request logs contain the request ID, method, and path without the query string.
Once authenticated they also carry `userId`, `tenantId`, and `organizationId`, both on
`req.log` children and on the completion line. Bodies, cookies, authorization headers,
and password/token fields are never logged.
