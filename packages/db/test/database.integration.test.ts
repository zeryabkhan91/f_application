import { randomUUID } from 'node:crypto';
import { afterAll, describe, expect, it } from 'vitest';
import { createDatabase } from '../src/index.js';

const connectionString =
  process.env.TEST_DATABASE_URL ?? process.env.DATABASE_URL;
if (!connectionString) {
  throw new Error(
    'Set TEST_DATABASE_URL or DATABASE_URL to run database integration tests',
  );
}
const db = createDatabase(connectionString);
afterAll(async () => {
  await db.$disconnect();
});

describe('PostgreSQL and Prisma integration', () => {
  it('queries the real database and round-trips storage metadata', async () => {
    const result = await db.$queryRaw<
      Array<{ value: number }>
    >`SELECT 1::int AS value`;
    expect(result).toEqual([{ value: 1 }]);
    const id = randomUUID();
    try {
      const stored = await db.storedObject.create({
        data: {
          id,
          bucket: 'integration-test',
          objectKey: `tests/${id}`,
          contentType: 'application/pdf',
          sizeBytes: 123n,
        },
      });
      expect(stored.sizeBytes).toBe(123n);
      const fetched = await db.storedObject.findUniqueOrThrow({
        where: { id },
      });
      expect(fetched.objectKey).toBe(`tests/${id}`);
      await expect(
        db.storedObject.create({
          data: {
            bucket: stored.bucket,
            objectKey: stored.objectKey,
            contentType: stored.contentType,
            sizeBytes: 1n,
          },
        }),
      ).rejects.toMatchObject({ code: 'P2002' });
      await expect(
        db.storedObject.create({
          data: {
            bucket: stored.bucket,
            objectKey: `tests/${id}-negative`,
            contentType: stored.contentType,
            sizeBytes: -1n,
          },
        }),
      ).rejects.toThrow();
    } finally {
      await db.storedObject.deleteMany({ where: { id } });
    }
  });
});
