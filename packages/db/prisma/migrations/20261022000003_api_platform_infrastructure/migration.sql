-- Shared API platform: audit reasons and member-private idempotency records.
BEGIN;

-- Void/cancel/adjustment reasons are first-class audit data, not hidden in JSON.
ALTER TABLE "audit_logs" ADD COLUMN "reason" TEXT;
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_reason_length" CHECK (
  reason IS NULL OR length(btrim(reason)) BETWEEN 1 AND 1000
);

CREATE TABLE "idempotency_keys" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "key" VARCHAR(128) NOT NULL,
    "request_method" VARCHAR(10) NOT NULL,
    "request_path" VARCHAR(500) NOT NULL,
    "request_hash" CHAR(64) NOT NULL,
    "response_status" SMALLINT,
    "response_body" JSONB,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "idempotency_keys_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "idempotency_keys_expires_at_idx" ON "idempotency_keys"("expires_at");
CREATE UNIQUE INDEX "idempotency_keys_scope_key_key" ON "idempotency_keys"("tenant_id", "organization_id", "user_id", "key");

ALTER TABLE "idempotency_keys" ADD CONSTRAINT "idempotency_keys_actor_fkey" FOREIGN KEY ("tenant_id", "organization_id", "user_id") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE "idempotency_keys" ADD CONSTRAINT "idempotency_keys_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE "idempotency_keys" ADD CONSTRAINT "idempotency_keys_values_valid" CHECK (
  key ~ '^[A-Za-z0-9_.:-]{8,128}$'
  AND request_hash ~ '^[0-9a-f]{64}$'
  AND (response_status IS NULL OR response_status BETWEEN 200 AND 299)
  AND expires_at > created_at
);

-- Keys are private to the member who sent them: another member of the same
-- organization must not be able to replay or probe someone else's request.
ALTER TABLE "idempotency_keys" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "idempotency_keys" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "idempotency_keys" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND user_id = NULLIF(current_setting('app.user_id', true), '')::uuid) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND user_id = NULLIF(current_setting('app.user_id', true), '')::uuid);

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "idempotency_keys" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

COMMIT;
