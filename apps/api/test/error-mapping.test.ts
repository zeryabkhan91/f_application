import { describe, expect, it } from 'vitest';
import {
  OrganizationAccessDeniedError,
  PermissionDeniedError,
  Prisma,
  RecordNotFoundError,
  UnsafeDatabaseRoleError,
} from '@repo/db';
import { MoneyCalculationError } from '@repo/utils';
import { ApiError } from '../src/lib/api-error.js';
import { toApiError } from '../src/lib/error-mapping.js';

function prismaError(code: string, cause?: Record<string, unknown>) {
  return new Prisma.PrismaClientKnownRequestError('database failure', {
    code,
    clientVersion: 'test',
    meta: cause ? { driverAdapterError: { cause } } : {},
  });
}

function mapped(error: unknown) {
  const { error: apiError, log } = toApiError(error);
  return {
    status: apiError.status,
    code: apiError.code,
    message: apiError.message,
    level: log?.level,
  };
}

const failingRow =
  'Failing row contains (secret-row-value, private@example.com, -1.00).';

describe('error mapping', () => {
  it('maps authorization failures to 403', () => {
    expect(mapped(new PermissionDeniedError())).toMatchObject({
      status: 403,
      code: 'FORBIDDEN',
    });
    expect(mapped(new OrganizationAccessDeniedError())).toMatchObject({
      status: 403,
      code: 'ORGANIZATION_ACCESS_DENIED',
    });
  });

  it('maps unique, foreign-key, and missing-record errors', () => {
    expect(
      mapped(
        prismaError('P2002', {
          originalCode: '23505',
          originalMessage:
            'duplicate key value violates unique constraint "units_tenant_id_organization_id_code_key"',
        }),
      ),
    ).toMatchObject({ status: 409, code: 'DUPLICATE', level: 'warn' });
    expect(
      mapped(
        prismaError('P2003', {
          originalCode: '23503',
          originalMessage:
            'update or delete on table "customers" violates foreign key constraint "x" on table "sales_orders"',
        }),
      ),
    ).toMatchObject({
      status: 409,
      code: 'REFERENCE_CONFLICT',
      message:
        'This record is linked to other records, so it cannot be changed or removed.',
    });
    expect(mapped(prismaError('P2003'))).toMatchObject({
      status: 409,
      message:
        'A selected record is no longer available. Refresh and try again.',
    });
    expect(mapped(prismaError('P2025'))).toMatchObject({
      status: 404,
      code: 'NOT_FOUND',
    });
    expect(mapped(new RecordNotFoundError('customers'))).toMatchObject({
      status: 404,
      code: 'NOT_FOUND',
    });
  });

  it('maps check violations to plain-language 422 messages without row data', () => {
    const cases: Array<[string, string]> = [
      ['customer_credit_limit_nonnegative', 'This value cannot be negative.'],
      [
        'sales_invoices_totals_valid',
        'The amounts do not add up. Check the quantities, prices, discounts, and tax.',
      ],
      ['expenses_void_reason_required', 'Please give a reason.'],
      [
        'sales_invoices_dates_valid',
        'Check the dates. A due date cannot be before the document date.',
      ],
      [
        'customer_payments_amount_positive',
        'Amounts and quantities must be greater than zero.',
      ],
      [
        'some_future_rule',
        'This change is not allowed. Please check the details and try again.',
      ],
    ];
    for (const [constraint, message] of cases) {
      const error = prismaError('P2010', {
        originalCode: '23514',
        originalMessage: `new row for relation "t" violates check constraint "${constraint}"`,
        detail: failingRow,
      });
      const result = toApiError(error);
      expect(result.error).toMatchObject({
        status: 422,
        code: 'BUSINESS_RULE_VIOLATION',
        message,
      });
      expect(result.log?.detail).toMatchObject({
        sqlState: '23514',
        constraint,
      });
      expect(JSON.stringify(result)).not.toContain('secret-row-value');
    }
    expect(
      mapped(
        prismaError('P2010', {
          originalCode: '23514',
          originalMessage: 'Negative stock is disabled for this organization',
        }),
      ).message,
    ).toBe(
      'There is not enough stock for this. Check the stock level and try again.',
    );
  });

  it('maps concurrency and timeouts to retryable errors', () => {
    expect(mapped(prismaError('P2034'))).toMatchObject({
      status: 409,
      code: 'CONCURRENT_UPDATE',
    });
    expect(
      mapped(
        prismaError('P2010', {
          originalCode: '40P01',
          originalMessage: 'deadlock detected',
        }),
      ),
    ).toMatchObject({ status: 409, code: 'CONCURRENT_UPDATE' });
    expect(mapped(prismaError('P2028'))).toMatchObject({
      status: 503,
      code: 'TRY_AGAIN',
    });
  });

  it('maps money errors to field-level validation errors', () => {
    const { error } = toApiError(
      new MoneyCalculationError(
        'lines.0.discount',
        'Discount cannot be more than the line amount',
      ),
    );
    expect(error.status).toBe(422);
    expect(error.fields).toEqual({
      'lines.0.discount': 'Discount cannot be more than the line amount',
    });
  });

  it('hides internal and unknown failures behind a generic 500', () => {
    for (const error of [
      new UnsafeDatabaseRoleError(),
      new Error('private detail'),
      prismaError('P2010', {
        originalCode: '22012',
        originalMessage: 'division by zero',
      }),
      new Prisma.PrismaClientValidationError(
        'Invalid `prisma.user.create()` invocation:\n\n{ passwordHash: "secret" }',
        { clientVersion: 'test' },
      ),
    ]) {
      const result = toApiError(error);
      expect(result.error).toMatchObject({
        status: 500,
        code: 'INTERNAL_ERROR',
      });
      expect(result.error.message).not.toContain('private');
      expect(result.log?.level).toBe('error');
    }
    const validation = toApiError(
      new Prisma.PrismaClientValidationError(
        'Invalid call:\n{ passwordHash: "secret" }',
        {
          clientVersion: 'test',
        },
      ),
    );
    expect(JSON.stringify(validation.log)).not.toContain('secret');
  });

  it('derives the fields map from validation details, first message wins', () => {
    const error = new ApiError(422, 'VALIDATION_ERROR', 'Invalid', [
      { path: 'name', message: 'Required' },
      { path: 'name', message: 'Too short' },
      { path: 'lines.0.quantity', message: 'Must be positive' },
    ]);
    expect(error.fields).toEqual({
      name: 'Required',
      'lines.0.quantity': 'Must be positive',
    });
    expect(new ApiError(404, 'NOT_FOUND', 'Missing').fields).toBeUndefined();
  });
});
