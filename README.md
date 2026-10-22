# Factory Management System backend

Backend foundation for the factory-system blueprint: Node.js 24, TypeScript,
Express 5, Zod, PostgreSQL 17, Prisma 7, OpenAPI, and AWS S3. npm workspaces link
shared backend packages. **No frontend is implemented.**

The complete uploaded plan is saved in [docs/plans/implementation-plan.md](docs/plans/implementation-plan.md).
Read [project context and Task #1 scope](docs/CONTEXT.md),
[architecture/database decisions](docs/architecture/database.md), and the
[ERD](docs/architecture/erd.md) before adding modules. The database covers all core
factory domains; business APIs, authentication flows, and posting engines are later tasks.

## Quick start

Prerequisites: Node **24.19.0**, npm **11**, Docker Engine, and Docker Compose v2.

```sh
npm ci
npm run setup:local
npm run db:up
npm run db:deploy
npm run db:provision
npm run build
npm run db:seed
# Optional development master data:
npm run db:seed:demo
npm run dev
```

`setup:local` creates an ignored `.env` with a generated local PostgreSQL password
and leaves an existing file unchanged. `db:provision` upgrades local configuration
to separate administrative `MIGRATION_DATABASE_URL` and restricted runtime
`DATABASE_URL` bindings. It preserves a private ignored `.env.before-tenancy`
backup, retains the password on repeat runs, and refuses remote/production
servers. PostgreSQL data persists in a Docker volume. `npm run db:down` stops it
without deleting data. Keep the configured password consistent with that volume.

`db:seed` creates reference catalogs. `db:seed:demo` also creates Demo Factory,
its invited owner, default roles/settings/warehouse/units/sequences, expense
categories, ABC Raw Materials, XYZ Traders, Cotton, and Finished Fabric.
Seeds preserve existing values and counters; no fixed tenant IDs or usable demo
password are stored. Login/registration is a later task.

## API runtime

The API uses port 4000. Existing routes remain:

| Path                | Purpose                                         |
| ------------------- | ----------------------------------------------- |
| `GET /health/live`  | Process liveness                                |
| `GET /health/ready` | Real database query; 503 on failure or shutdown |
| `GET /api/v1`       | Service identity and version                    |
| `GET /openapi.json` | Development OpenAPI contract                    |
| `GET /docs/`        | Development Swagger UI                          |

Run `npm run smoke` against a running API. Set `API_BASE_URL` to test a different
local port. Docs default to disabled in production. Set `ENABLE_API_DOCS=true`
explicitly if needed. No business endpoints accept unverified tenant/user IDs.

## Layout

```text
apps/
  api/          HTTP runtime, middleware, S3 helper, tests, Dockerfile
  web/          Existing placeholder; frontend deferred
packages/
  db/           51 models, migrations, tenancy, audit, locking, idempotency, seeds
  types/        Shared DTO/context/permission types
  validation/   Shared Zod contracts and 26 domain enums
  ui/           Existing placeholder; frontend deferred
  config/       Environment validation and TypeScript configuration
  utils/        Shared backend utilities
docs/
  CONTEXT.md    Accepted scope and implementation decisions
  plans/        Original user-supplied blueprint
  architecture/ Database decisions, domain ERD, full generated ERD
  openapi.json Existing API contract
```

## Development commands

| Command                    | Purpose                                                      |
| -------------------------- | ------------------------------------------------------------ |
| `npm run dev`              | Initial build, shared-package watcher, API reload            |
| `npm run build`            | Generate Prisma client and compile backend packages          |
| `npm start`                | Run the compiled API                                         |
| `npm run typecheck`        | Validate TypeScript project references                       |
| `npm run lint`             | ESLint                                                       |
| `npm test`                 | Unit/HTTP, shared contracts, and enum consistency tests      |
| `npm run test:integration` | Fresh migrations, real PostgreSQL isolation/integrity tests  |
| `npm run db:validate`      | Validate the Prisma schema                                   |
| `npm run db:deploy`        | Apply checked-in migrations using administrative credentials |
| `npm run db:provision`     | Provision the restricted local runtime role                  |
| `npm run db:seed`          | Seed platform reference data                                 |
| `npm run db:seed:demo`     | Opt-in development organization and master data              |
| `npm run db:studio`        | Inspect database data with configured administrative access  |
| `npm run erd:generate`     | Regenerate the complete schema ERD                           |
| `npm run openapi:generate` | Refresh the existing API contract                            |
| `npm run format:check`     | Check formatting                                             |

Create migrations with
`npm run migrate:dev --workspace=@repo/db -- --name your_change`.
Never edit applied migrations or reset a shared database. Integration tests use
`TEST_MIGRATION_DATABASE_URL`, falling back to `MIGRATION_DATABASE_URL`, and require
a local administrator with CREATEDB/CREATEROLE/CITEXT rights. They create and drop
only their own random temporary database/role; they never reset the configured
local database. CI exercises the same workflow and checks ERD/OpenAPI drift.

In the Codex cloud workspace, `bash scripts/cloud-install.sh` repeats installation,
migrations, local role provisioning, compilation, and catalog seeding. Use the
existing isolated checkout without creating a Git worktree.

## Tenancy and financial data

Use `withOrganization` with authenticated server identity, then `requirePermission`
inside the transaction. The helper verifies active memberships and rejects
privileged connections; forced PostgreSQL RLS provides scope isolation. Tenant and
organization foreign keys also prevent cross-scope relationships. Money/quantity
contracts use decimal strings. Financial balances and stock availability are
read models; audit and stock history are append-only. Full rules and remaining
transactional workflow responsibilities are in the architecture document.

## Storage and deployment

S3 remains optional for the initial API. Configure `AWS_REGION` and `S3_BUCKET`,
create the client with `createS3Client`, and pass it to `createObjectStorage`.
Use ECS task roles or the AWS standard credential chain. Keep buckets private and
Block Public Access enabled; do not commit access keys. The helper returns upload
`{ url, headers }`; send every returned header with the body. Authorize ownership,
generate organization-scoped keys, and enforce document size/type policy in the
future attachment workflow. Signed URLs alone do not enforce upload size limits.
Live AWS operations need a real bucket and permissions and are not offline tests.

Runtime configuration is in `.env.example` and `packages/config/src/index.ts`.
Production needs a restricted `DATABASE_URL` and explicit `CORS_ORIGINS`. Set
`TRUST_PROXY_HOPS=1` only for a single trusted ALB with ingress restricted to it.
Keep administrative migration/seed credentials out of API tasks.
[Deployment notes](docs/deployment.md) cover Docker/ECS/RDS/S3; no AWS infrastructure
or frontend deployment is provisioned by this task.
