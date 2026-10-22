import { Decimal } from 'decimal.js';
import { describe, expect, it } from 'vitest';
import {
  calculateDocumentTotals,
  calculateLineAmounts,
  MoneyCalculationError,
  parseMoney,
  roundMoney,
  toDecimal,
  toMoneyString,
  toQuantityString,
} from '../src/index.js';

const money = (value: { toString(): string }) => toMoneyString(value);

function failure(work: () => unknown) {
  try {
    work();
  } catch (error) {
    if (error instanceof MoneyCalculationError)
      return { field: error.field, message: error.message };
    throw error;
  }
  throw new Error('Expected a MoneyCalculationError');
}

describe('money rounding', () => {
  it('rounds ties away from zero like PostgreSQL round(numeric, 2)', () => {
    expect(money(roundMoney('0.005'))).toBe('0.01');
    expect(money(roundMoney('2.675'))).toBe('2.68'); // 2.67 with binary floats
    expect(money(roundMoney('1.004999'))).toBe('1.00');
    expect(money(roundMoney('-0.005'))).toBe('-0.01');
  });

  it('rounds the gross line amount before discount and tax', () => {
    const line = calculateLineAmounts({
      quantity: '3.3333',
      unitPrice: '3.33',
      discount: '1.10',
      tax: '0.55',
    });
    expect(money(line.grossAmount)).toBe('11.10'); // 11.099889
    expect(money(line.lineTotal)).toBe('10.55');
  });

  it('sums decimal fractions exactly', () => {
    const totals = calculateDocumentTotals({
      lines: Array.from({ length: 10 }, () => ({
        quantity: '1',
        unitPrice: '0.10',
      })),
    });
    expect(money(totals.subtotal)).toBe('1.00');
    expect(money(totals.total)).toBe('1.00');
  });
});

describe('document totals', () => {
  it('aggregates line and document discounts and taxes', () => {
    const totals = calculateDocumentTotals({
      lines: [
        {
          quantity: '2',
          unitPrice: '500.00',
          discount: '100.00',
          tax: '90.00',
        },
        { quantity: '1.5', unitPrice: '200.00' },
      ],
      discount: '50.00',
      tax: '10.00',
    });
    expect(totals.lines.map((line) => money(line.lineTotal))).toEqual([
      '990.00',
      '300.00',
    ]);
    expect({
      subtotal: money(totals.subtotal),
      discount: money(totals.discount),
      tax: money(totals.tax),
      total: money(totals.total),
    }).toEqual({
      subtotal: '1300.00',
      discount: '150.00',
      tax: '100.00',
      total: '1250.00',
    });
    // Header identity from the database CHECK and the sum of the lines agree.
    expect(money(totals.subtotal.minus(totals.discount).plus(totals.tax))).toBe(
      money(totals.total),
    );
  });

  it('reports the failing line field path', () => {
    expect(
      failure(() =>
        calculateDocumentTotals({
          lines: [
            { quantity: '1', unitPrice: '10.00' },
            { quantity: '1', unitPrice: '10.00', discount: '10.01' },
          ],
        }),
      ),
    ).toEqual({
      field: 'lines.1.discount',
      message: 'Discount cannot be more than the line amount',
    });
  });

  it('rejects document discounts above the subtotal and empty documents', () => {
    expect(
      failure(() =>
        calculateDocumentTotals({
          lines: [{ quantity: '1', unitPrice: '10.00' }],
          discount: '10.01',
        }),
      ).field,
    ).toBe('discount');
    expect(failure(() => calculateDocumentTotals({ lines: [] })).field).toBe(
      'lines',
    );
  });
});

describe('input rejection', () => {
  it('rejects negative amounts, zero quantities, and excess precision', () => {
    const line = { quantity: '1', unitPrice: '10.00' };
    expect(
      failure(() => calculateLineAmounts({ ...line, unitPrice: '-1' })),
    ).toEqual({ field: 'unitPrice', message: 'Amount cannot be negative' });
    expect(
      failure(() => calculateLineAmounts({ ...line, discount: '-0.01' })).field,
    ).toBe('discount');
    expect(
      failure(() => calculateLineAmounts({ ...line, tax: '-5' })).field,
    ).toBe('tax');
    expect(
      failure(() => calculateLineAmounts({ ...line, quantity: '0' })).message,
    ).toBe('Quantity must be greater than zero');
    expect(
      failure(() => calculateLineAmounts({ ...line, quantity: '-2' })).field,
    ).toBe('quantity');
    expect(
      failure(() => calculateLineAmounts({ ...line, unitPrice: '1.001' }))
        .message,
    ).toBe('Amount can have at most 2 decimal places');
    expect(
      failure(() => calculateLineAmounts({ ...line, quantity: '1.00001' }))
        .message,
    ).toBe('Quantity can have at most 4 decimal places');
  });

  it('rejects binary floating-point and malformed input', () => {
    expect(failure(() => toDecimal(0.1 as unknown as string)).message).toBe(
      'Enter a valid number',
    );
    expect(failure(() => parseMoney('ten')).field).toBe('amount');
    expect(failure(() => parseMoney('Infinity')).field).toBe('amount');
  });
});

describe('large values', () => {
  it('accepts the full DECIMAL(18,2) range exactly', () => {
    expect(money(parseMoney('9999999999999999.99'))).toBe(
      '9999999999999999.99',
    );
    const line = calculateLineAmounts({
      quantity: '99999999999999.9999',
      unitPrice: '0.01',
    });
    expect(money(line.lineTotal)).toBe('1000000000000.00');
  });

  it('rejects values that would overflow the database columns', () => {
    expect(failure(() => parseMoney('10000000000000000')).message).toBe(
      'Amount is too large',
    );
    expect(
      failure(() =>
        calculateLineAmounts({
          quantity: '99999999999999.9999',
          unitPrice: '9999999999999999.99',
        }),
      ).field,
    ).toBe('lineTotal');
    expect(
      failure(() =>
        calculateDocumentTotals({
          lines: [
            { quantity: '1', unitPrice: '9000000000000000.00' },
            { quantity: '1', unitPrice: '9000000000000000.00' },
          ],
        }),
      ).field,
    ).toBe('total');
  });
});

describe('serialization', () => {
  it('formats fixed-scale strings and accepts other Decimal instances', () => {
    expect(toMoneyString(new Decimal('1500.5'))).toBe('1500.50');
    expect(toMoneyString('0')).toBe('0.00');
    expect(toQuantityString('12.5')).toBe('12.5000');
    expect(failure(() => toMoneyString('1.005')).message).toContain(
      'round it before serializing',
    );
  });
});
