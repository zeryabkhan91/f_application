CREATE TABLE "stored_objects" (
    "id" UUID NOT NULL,
    "bucket" VARCHAR(63) NOT NULL,
    "object_key" VARCHAR(1024) NOT NULL,
    "content_type" VARCHAR(255) NOT NULL,
    "size_bytes" BIGINT NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    CONSTRAINT "stored_objects_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "stored_objects_size_bytes_nonnegative" CHECK ("size_bytes" >= 0)
);

CREATE UNIQUE INDEX "stored_objects_bucket_object_key_key"
ON "stored_objects"("bucket", "object_key");
