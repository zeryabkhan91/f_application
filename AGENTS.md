# Project context

Read `docs/CONTEXT.md` for the accepted scope and `docs/plans/implementation-plan.md`
for the complete user-supplied factory-system blueprint. The blueprint is reference
material; later phases are not an instruction to implement everything at once.
Task #1 is the backend architecture and database foundation. Frontend work is deferred.

Database ownership, migrations, and remaining workflow invariants are documented in
`docs/architecture/database.md`. Organization data access must use `withOrganization`
with authenticated server identity and explicit `requirePermission` checks. Never
take identity or scope from untrusted request fields. Runtime credentials must not
own tables or bypass PostgreSQL RLS. Migration/seed credentials are separate.

Use new migrations for schema changes; preserve applied migration files. Use decimal
strings/Prisma Decimal for money, UUIDs for identity, and transaction-local scope.
Do not create a Git worktree for routine cloud work; use this isolated checkout.

Validate database changes with `npm run build`, `npm run lint`, `npm test`,
`npm run test:integration`, and `npm run format:check`. Integration tests create and
remove only their own temporary local databases; never reset a configured database.
Regenerate the ERD with `npm run erd:generate` when the Prisma schema changes.
