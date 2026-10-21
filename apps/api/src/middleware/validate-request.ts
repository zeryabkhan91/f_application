import { z } from '@repo/validation';
import type { RequestHandler } from 'express';
import { ApiError } from '../lib/api-error.js';

/** Validated data is stored in res.locals; Express 5 request.query is read-only. */
export function validateRequest(
  schema: z.ZodType,
  source: 'body' | 'query' | 'params' = 'body',
): RequestHandler {
  return (req, res, next) => {
    const result = schema.safeParse(req[source]);
    if (!result.success) {
      return next(
        new ApiError(
          422,
          'VALIDATION_ERROR',
          'Request validation failed',
          result.error.issues.map((issue) => ({
            path: issue.path.map(String).join('.'),
            message: issue.message,
          })),
        ),
      );
    }
    res.locals[source] = result.data;
    next();
  };
}
