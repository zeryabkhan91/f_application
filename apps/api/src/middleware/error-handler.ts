import type { ErrorRequestHandler } from 'express';
import { errorResponseSchema } from '@repo/validation';
import { ApiError } from '../lib/api-error.js';

export const errorHandler: ErrorRequestHandler = (
  error: unknown,
  req,
  res,
  next,
) => {
  if (res.headersSent) return next(error);

  let failure: ApiError;
  if (error instanceof ApiError) {
    failure = error;
  } else if (
    error instanceof SyntaxError &&
    'type' in error &&
    error.type === 'entity.parse.failed'
  ) {
    failure = new ApiError(
      400,
      'INVALID_JSON',
      'Request body is not valid JSON',
    );
  } else if (
    error instanceof Error &&
    'type' in error &&
    error.type === 'entity.too.large'
  ) {
    failure = new ApiError(
      413,
      'PAYLOAD_TOO_LARGE',
      'Request body exceeds 1 MB',
    );
  } else {
    req.log?.error({ err: error }, 'Unhandled request error');
    failure = new ApiError(
      500,
      'INTERNAL_ERROR',
      'An unexpected error occurred',
    );
  }

  const body = errorResponseSchema.parse({
    error: {
      code: failure.code,
      message: failure.message,
      requestId: String(res.locals.requestId ?? req.id ?? 'unknown'),
      ...(failure.details ? { details: failure.details } : {}),
    },
  });
  res.status(failure.status).json(body);
};
