import { z } from 'zod';

const booleanFromEnv = z.enum(['true', 'false']).transform((v) => v === 'true');

const environmentSchema = z
  .object({
    NODE_ENV: z
      .enum(['development', 'test', 'production'])
      .default('development'),
    HOST: z.string().min(1).default('127.0.0.1'),
    PORT: z.coerce.number().int().min(1).max(65_535).default(4000),
    DATABASE_URL: z.url().refine((value) => /^postgres(ql)?:\/\//.test(value), {
      message: 'Must be a PostgreSQL connection URL',
    }),
    LOG_LEVEL: z
      .enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent'])
      .default('info'),
    CORS_ORIGINS: z.string().optional(),
    TRUST_PROXY_HOPS: z.coerce.number().int().min(0).max(5).default(0),
    ENABLE_API_DOCS: booleanFromEnv.optional(),
    AWS_REGION: z.string().min(1).default('us-east-1'),
    S3_BUCKET: z.string().min(1).optional(),
    S3_ENDPOINT: z.url().optional(),
    S3_FORCE_PATH_STYLE: booleanFromEnv.default(false),
  })
  .superRefine((value, ctx) => {
    if (value.NODE_ENV === 'production' && !value.CORS_ORIGINS?.trim()) {
      ctx.addIssue({
        code: 'custom',
        path: ['CORS_ORIGINS'],
        message: 'Explicit CORS origins are required in production',
      });
    }
    const origins = value.CORS_ORIGINS?.split(',').map((v) => v.trim()) ?? [];
    for (const origin of origins) {
      try {
        const url = new URL(origin);
        if (
          !['http:', 'https:'].includes(url.protocol) ||
          url.origin !== origin
        ) {
          throw new Error('Invalid origin');
        }
      } catch {
        ctx.addIssue({
          code: 'custom',
          path: ['CORS_ORIGINS'],
          message: 'Use comma-separated HTTP(S) origins without paths',
        });
      }
    }
  });

export function parseEnvironment(input: Record<string, string | undefined>) {
  const parsed = environmentSchema.safeParse(input);
  if (!parsed.success) {
    // Report variable names only: a validation error must not reveal values.
    const names = [
      ...new Set(parsed.error.issues.map((v) => v.path.join('.'))),
    ];
    throw new Error(`Invalid environment variables: ${names.join(', ')}`);
  }
  const env = parsed.data;
  return {
    ...env,
    corsOrigins: (env.CORS_ORIGINS ?? 'http://localhost:3000')
      .split(',')
      .map((v) => v.trim()),
    apiDocsEnabled: env.ENABLE_API_DOCS ?? env.NODE_ENV !== 'production',
  };
}

export type Environment = ReturnType<typeof parseEnvironment>;
