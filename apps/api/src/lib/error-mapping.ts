import {
  OrganizationAccessDeniedError,
  PermissionDeniedError,
  Prisma,
  RecordNotFoundError,
} from '@repo/db';
import { MoneyCalculationError } from '@repo/utils';
import { ApiError } from './api-error.js';

export interface MappedError {
  error: ApiError;
  /** Server-side detail for logs; never sent to clients and never contains row data. */
  log?: { level: 'warn' | 'error'; detail: Record<string, unknown> };
}

const TRY_AGAIN = 'Something changed at the same time. Please try again.';

// Matched against constraint names from the migrations, most specific first (§106).
const constraintMessages: Array<[RegExp, string]> = [
  [/reason/, 'Please give a reason.'],
  [
    /totals_valid|amounts_valid/,
    'The amounts do not add up. Check the quantities, prices, discounts, and tax.',
  ],
  [
    /dates_valid/,
    'Check the dates. A due date cannot be before the document date.',
  ],
  [/nonnegative/, 'This value cannot be negative.'],
  [
    /positive|quantit|values_valid/,
    'Amounts and quantities must be greater than zero.',
  ],
];
const BUSINESS_RULE_FALLBACK =
  'This change is not allowed. Please check the details and try again.';

function databaseCause(error: Prisma.PrismaClientKnownRequestError) {
  const adapter = (error.meta as { driverAdapterError?: { cause?: unknown } })
    ?.driverAdapterError?.cause as
    | { originalCode?: string; originalMessage?: string; table?: string }
    | undefined;
  const message = adapter?.originalMessage ?? '';
  return {
    sqlState: adapter?.originalCode,
    message,
    constraint: /constraint "([^"]+)"/.exec(message)?.[1],
    table: adapter?.table ?? /relation "([^"]+)"/.exec(message)?.[1],
  };
}

function checkViolationMessage(
  constraint: string | undefined,
  message: string,
) {
  if (/negative stock/i.test(message))
    return 'There is not enough stock for this. Check the stock level and try again.';
  if (!constraint) return BUSINESS_RULE_FALLBACK;
  return (
    constraintMessages.find(([pattern]) => pattern.test(constraint))?.[1] ??
    BUSINESS_RULE_FALLBACK
  );
}

function mapPrismaError(
  error: Prisma.PrismaClientKnownRequestError,
): MappedError {
  const cause = databaseCause(error);
  const detail = { prismaCode: error.code, ...cause };
  const warn = (apiError: ApiError): MappedError => ({
    error: apiError,
    log: { level: 'warn', detail },
  });
  if (error.code === 'P2025')
    return warn(
      new ApiError(
        404,
        'NOT_FOUND',
        'The requested record could not be found.',
      ),
    );
  if (error.code === 'P2002' || cause.sqlState === '23505')
    return warn(
      new ApiError(
        409,
        'DUPLICATE',
        'A record with these details already exists.',
      ),
    );
  if (error.code === 'P2003' || cause.sqlState === '23503') {
    const inUse = /update or delete on table/.test(cause.message);
    return warn(
      new ApiError(
        409,
        'REFERENCE_CONFLICT',
        inUse
          ? 'This record is linked to other records, so it cannot be changed or removed.'
          : 'A selected record is no longer available. Refresh and try again.',
      ),
    );
  }
  if (cause.sqlState === '23514')
    return warn(
      new ApiError(
        422,
        'BUSINESS_RULE_VIOLATION',
        checkViolationMessage(cause.constraint, cause.message),
      ),
    );
  if (cause.sqlState === '22003')
    return warn(
      new ApiError(422, 'VALUE_OUT_OF_RANGE', 'A number is too large.'),
    );
  if (
    error.code === 'P2034' ||
    cause.sqlState === '40001' ||
    cause.sqlState === '40P01'
  )
    return warn(new ApiError(409, 'CONCURRENT_UPDATE', TRY_AGAIN));
  if (error.code === 'P2028')
    return warn(
      new ApiError(503, 'TRY_AGAIN', 'The server is busy. Please try again.'),
    );
  return {
    error: internalError(),
    log: { level: 'error', detail },
  };
}

function internalError() {
  return new ApiError(500, 'INTERNAL_ERROR', 'An unexpected error occurred');
}

/** Converts any thrown value into the public error contract. */
export function toApiError(error: unknown): MappedError {
  if (error instanceof ApiError) return { error };
  if (
    error instanceof SyntaxError &&
    'type' in error &&
    error.type === 'entity.parse.failed'
  )
    return {
      error: new ApiError(
        400,
        'INVALID_JSON',
        'Request body is not valid JSON',
      ),
    };
  if (
    error instanceof Error &&
    'type' in error &&
    error.type === 'entity.too.large'
  )
    return {
      error: new ApiError(
        413,
        'PAYLOAD_TOO_LARGE',
        'Request body exceeds 1 MB',
      ),
    };
  if (error instanceof PermissionDeniedError)
    return {
      error: new ApiError(
        403,
        'FORBIDDEN',
        'You do not have permission to do this.',
      ),
    };
  if (error instanceof OrganizationAccessDeniedError)
    return {
      error: new ApiError(
        403,
        'ORGANIZATION_ACCESS_DENIED',
        'You do not have access to this organization.',
      ),
    };
  if (error instanceof RecordNotFoundError)
    return {
      error: new ApiError(
        404,
        'NOT_FOUND',
        'The requested record could not be found.',
      ),
    };
  if (error instanceof MoneyCalculationError)
    return {
      error: new ApiError(
        422,
        'VALIDATION_ERROR',
        'Please correct the highlighted fields.',
        [{ path: error.field, message: error.message }],
      ),
    };
  if (error instanceof Prisma.PrismaClientKnownRequestError)
    return mapPrismaError(error);
  if (
    error instanceof Prisma.PrismaClientValidationError ||
    error instanceof Prisma.PrismaClientUnknownRequestError
  )
    // These messages embed query arguments, which can include private values.
    return {
      error: internalError(),
      log: {
        level: 'error',
        detail: { name: error.name, message: error.message.split('\n')[0] },
      },
    };
  return {
    error: internalError(),
    log: { level: 'error', detail: { err: error } },
  };
}
