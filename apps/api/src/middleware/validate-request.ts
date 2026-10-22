import { z } from '@repo/validation';
import type { RequestHandler } from 'express';
import { ApiError } from '../lib/api-error.js';

export type RequestSource = 'body' | 'query' | 'params';

/** Parses one request part or throws the standard 422 with per-field messages. */
export function parseRequestPart<S extends z.ZodType>(
  schema: S,
  value: unknown,
): z.output<S> {
  const result = schema.safeParse(value);
  if (result.success) return result.data;
  throw new ApiError(
    422,
    'VALIDATION_ERROR',
    'Please correct the highlighted fields.',
    result.error.issues.map((issue) => ({
      path: issue.path.map(String).join('.'),
      message: issue.message,
    })),
  );
}

/** Validated data is stored in res.locals; Express 5 request.query is read-only. */
export function validateRequest(
  schema: z.ZodType,
  source: RequestSource = 'body',
): RequestHandler {
  return (req, res, next) => {
    try {
      res.locals[source] = parseRequestPart(schema, req[source]);
      next();
    } catch (error) {
      next(error);
    }
  };
}
