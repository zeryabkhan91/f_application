import type { ErrorRequestHandler } from 'express';
import { errorResponseSchema } from '@repo/validation';
import { toApiError } from '../lib/error-mapping.js';

export const errorHandler: ErrorRequestHandler = (
  error: unknown,
  req,
  res,
  next,
) => {
  if (res.headersSent) return next(error);

  const { error: failure, log } = toApiError(error);
  if (log)
    req.log?.[log.level](
      log.detail,
      log.level === 'error' ? 'Unhandled request error' : 'Request rejected',
    );

  const body = errorResponseSchema.parse({
    error: {
      code: failure.code,
      message: failure.message,
      requestId: String(res.locals.requestId ?? req.id ?? 'unknown'),
      ...(failure.details ? { details: failure.details } : {}),
      ...(failure.fields ? { fields: failure.fields } : {}),
    },
  });
  res.status(failure.status).json(body);
};
