# F Application backend

TypeScript monorepo for the system backend: Node.js 24, Express 5, Zod,
PostgreSQL 17, Prisma 7, OpenAPI, and AWS S3. npm workspaces link shared packages.
This is the backend foundation; product-specific routes, authentication, and
authorization require the system's business requirements.

## Quick start

Prerequisites: Node **24.19.0**, npm **11**, Docker Engine and Docker Compose v2.
The cloud environment already has Node and Docker.

```sh
npm ci
npm run setup:local
npm run db:up
npm run db:deploy
npm run build
npm run dev
```

`setup:local` creates an ignored `.env` with a random local database password and
leaves an existing `.env` unchanged. Database data persists in a Docker volume;
`npm run db:down` stops PostgreSQL without removing data. Keep the password in
`.env` consistent with the existing volume. Edit `.env` for an external database.
Docker Compose is for local PostgreSQL only.

The API uses port 4000. Available paths:

| Path                | Purpose                                                          |
| ------------------- | ---------------------------------------------------------------- |
| `GET /health/live`  | Process liveness                                                 |
| `GET /health/ready` | Runs a real PostgreSQL query; returns 503 on failure or shutdown |
| `GET /api/v1`       | Service identity and version                                     |
| `GET /openapi.json` | Generated OpenAPI contract in development                        |
| `GET /docs/`        | Swagger UI in development                                        |

Local verification: `curl --fail http://127.0.0.1:4000/health/ready` and
`curl --fail http://127.0.0.1:4000/api/v1`. Documentation routes default to off in
production; set `ENABLE_API_DOCS=true` explicitly if required.

`npm run smoke` checks the live API and database readiness. In the Codex cloud
workspace, `bash scripts/cloud-install.sh` repeats dependency installation,
local database startup, migrations, and compilation. Each cloud task is already
isolated; use its existing checkout without creating a Git worktree.

## Layout

```text
apps/
  api/          Express API, middleware, S3 service, tests, Dockerfile
  web/          Reserved for Next.js frontend
packages/
  db/           Prisma schema, migrations, generated client factory
  types/        Shared DTOs derived from Zod schemas
  validation/   Shared request/response schemas and enums
  ui/           Reserved for reusable frontend components
  config/       Validated environment and shared TypeScript settings
  utils/        Shared backend utilities
docs/
  openapi.json  Generated and checked-in API specification
```

Frontend dependencies are deferred until `apps/web` is implemented. Its planned
stack is Next.js, TypeScript, Tailwind, PWA support, React Hook Form, Zod, and
TanStack Query. API modules belong in `apps/api`; shared DTOs, enums, and schemas
belong in `packages`. Add a Zod schema, request validator, response validator,
OpenAPI registration, and tests with each business endpoint.

## Development commands

| Command                    | Purpose                                                          |
| -------------------------- | ---------------------------------------------------------------- |
| `npm run dev`              | Initial build, shared-package compilation watch, API reload      |
| `npm run build`            | Generate Prisma client and compile all backend packages          |
| `npm start`                | Run compiled API; run `build` first                              |
| `npm run typecheck`        | Check TypeScript project references                              |
| `npm run lint`             | ESLint                                                           |
| `npm test`                 | Unit and HTTP tests, including validation and offline S3 signing |
| `npm run test:integration` | Real PostgreSQL/Prisma round-trip and constraint checks          |
| `npm run db:migrate`       | Create and apply a development migration                         |
| `npm run db:deploy`        | Apply checked-in migrations without resetting data               |
| `npm run db:studio`        | Inspect the local database                                       |
| `npm run openapi:generate` | Refresh `docs/openapi.json`                                      |
| `npm run format:check`     | Check formatting                                                 |

Create new migrations from the repository root with
`npm run migrate:dev --workspace=@repo/db -- --name your_change`.
Never run migration reset against shared or production databases. Integration tests
use `TEST_DATABASE_URL` when set, otherwise `DATABASE_URL`; they create and remove
their own uniquely named test row and never reset the database. The initial
`StoredObject` model holds private document metadata; it is not exposed as a
public upload API. Prisma's `BigInt` size must be serialized explicitly when a
document DTO is added.

## Configuration and storage

See `.env.example` and `packages/config/src/index.ts`. Required at runtime:
`DATABASE_URL`; production also requires explicit `CORS_ORIGINS`. Values are
validated at startup, and validation errors report variable names only.
`TRUST_PROXY_HOPS=0` is the local default. For a single trusted AWS ALB, use `1`
and restrict API ingress to the ALB security group so clients cannot bypass it.

S3 is optional for the initial API. To use the internal storage service, configure
`AWS_REGION` and `S3_BUCKET`, create a client with `createS3Client`, and pass it to
`createObjectStorage`. AWS SDK uses its standard credential chain; prefer ECS task
roles in AWS. Do not commit AWS access keys. Optional `S3_ENDPOINT` and
`S3_FORCE_PATH_STYLE` support compatible local storage.

The helper signs short-lived private upload/download URLs and deletes objects.
Uploads return `{ url, headers }`; send all returned headers with the upload body.
Authorize ownership and generate scoped object keys before calling it. Signed
uploads request S3-managed encryption; keep S3 Block Public Access enabled and
configure bucket CORS for your frontend origins. Upload size and document type
policy must be enforced by the future document workflow; signing alone does not
enforce a file-size limit. Real AWS storage operations need a bucket and IAM
permissions and are not part of offline tests.

## AWS deployment

See [deployment notes](docs/deployment.md). The Dockerfile includes API runtime
and separate migration targets. Deployment infrastructure is not provisioned by
this scaffold. The repository includes CI for build, lint, format, tests,
migrations, and OpenAPI drift.
