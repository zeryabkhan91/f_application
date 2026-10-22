import { Decimal } from 'decimal.js';

/**
 * Exact decimal arithmetic for money (DECIMAL(18,2)) and quantities (DECIMAL(18,4)).
 * ROUND_HALF_UP rounds ties away from zero, matching PostgreSQL round(numeric, 2),
 * so service results satisfy the database CHECK constraints exactly.
 */
export const Exact = Decimal.clone({
  precision: 64,
  rounding: Decimal.ROUND_HALF_UP,
  toExpNeg: -64,
  toExpPos: 64,
});
export type ExactDecimal = InstanceType<typeof Exact>;

/** Prisma Decimal and decimal.js values both satisfy this; binary floats are rejected. */
export type DecimalInput = string | { toString(): string };

const MONEY_SCALE = 2;
const QUANTITY_SCALE = 4;
const MONEY_LIMIT = new Exact('1e16');
const QUANTITY_LIMIT = new Exact('1e14');

export class MoneyCalculationError extends Error {
  constructor(
    public readonly field: string,
    message: string,
  ) {
    super(message);
    this.name = 'MoneyCalculationError';
  }
}

export function isDecimalLike(value: unknown): value is ExactDecimal {
  return (
    typeof value === 'object' &&
    value !== null &&
    Object.prototype.toString.call(value) === '[object Decimal]'
  );
}

export function toDecimal(value: DecimalInput, field = 'value'): ExactDecimal {
  if (typeof value !== 'string' && !isDecimalLike(value))
    throw new MoneyCalculationError(field, 'Enter a valid number');
  try {
    const decimal = new Exact(value.toString().trim());
    if (decimal.isFinite()) return decimal;
  } catch {
    // Reported below with the caller's field name.
  }
  throw new MoneyCalculationError(field, 'Enter a valid number');
}

function bounded(
  value: DecimalInput,
  field: string,
  scale: number,
  limit: ExactDecimal,
  label: string,
) {
  const decimal = toDecimal(value, field);
  if (decimal.decimalPlaces() > scale)
    throw new MoneyCalculationError(
      field,
      `${label} can have at most ${scale} decimal places`,
    );
  if (decimal.abs().gte(limit))
    throw new MoneyCalculationError(field, `${label} is too large`);
  return decimal;
}

export function parseMoney(value: DecimalInput, field = 'amount') {
  return bounded(value, field, MONEY_SCALE, MONEY_LIMIT, 'Amount');
}

export function parseQuantity(value: DecimalInput, field = 'quantity') {
  return bounded(value, field, QUANTITY_SCALE, QUANTITY_LIMIT, 'Quantity');
}

function nonNegativeMoney(value: DecimalInput | undefined, field: string) {
  const amount = parseMoney(value ?? '0', field);
  if (amount.isNegative())
    throw new MoneyCalculationError(field, 'Amount cannot be negative');
  return amount;
}

export function roundMoney(value: DecimalInput) {
  return toDecimal(value).toDecimalPlaces(MONEY_SCALE, Exact.ROUND_HALF_UP);
}

export interface LineInput {
  quantity: DecimalInput;
  unitPrice: DecimalInput;
  discount?: DecimalInput;
  tax?: DecimalInput;
}

export interface LineAmounts {
  quantity: ExactDecimal;
  unitPrice: ExactDecimal;
  grossAmount: ExactDecimal;
  discount: ExactDecimal;
  tax: ExactDecimal;
  lineTotal: ExactDecimal;
}

/** lineTotal = round(quantity × unitPrice, 2) − discount + tax, as the line CHECKs require. */
export function calculateLineAmounts(line: LineInput, path = ''): LineAmounts {
  const at = (field: string) => (path ? `${path}.${field}` : field);
  const quantity = parseQuantity(line.quantity, at('quantity'));
  if (!quantity.isPositive() || quantity.isZero())
    throw new MoneyCalculationError(
      at('quantity'),
      'Quantity must be greater than zero',
    );
  const unitPrice = nonNegativeMoney(line.unitPrice, at('unitPrice'));
  const discount = nonNegativeMoney(line.discount, at('discount'));
  const tax = nonNegativeMoney(line.tax, at('tax'));
  const grossAmount = roundMoney(quantity.times(unitPrice));
  if (discount.gt(grossAmount))
    throw new MoneyCalculationError(
      at('discount'),
      'Discount cannot be more than the line amount',
    );
  const lineTotal = grossAmount.minus(discount).plus(tax);
  if (grossAmount.gte(MONEY_LIMIT) || lineTotal.gte(MONEY_LIMIT))
    throw new MoneyCalculationError(at('lineTotal'), 'Line total is too large');
  return { quantity, unitPrice, grossAmount, discount, tax, lineTotal };
}

export interface DocumentInput {
  lines: readonly LineInput[];
  /** Document-level adjustments applied after line discounts and taxes. */
  discount?: DecimalInput;
  tax?: DecimalInput;
}

export interface DocumentTotals {
  lines: LineAmounts[];
  subtotal: ExactDecimal;
  discount: ExactDecimal;
  tax: ExactDecimal;
  total: ExactDecimal;
}

/**
 * subtotal = Σ gross line amounts; discount and tax include every line plus the
 * document-level values, so total = subtotal − discount + tax = Σ lineTotal − document
 * discount + document tax. This satisfies the header CHECK constraints exactly.
 */
export function calculateDocumentTotals(
  document: DocumentInput,
): DocumentTotals {
  if (document.lines.length === 0)
    throw new MoneyCalculationError('lines', 'Add at least one item');
  const lines = document.lines.map((line, index) =>
    calculateLineAmounts(line, `lines.${index}`),
  );
  const sum = (pick: (line: LineAmounts) => ExactDecimal) =>
    lines.reduce((total, line) => total.plus(pick(line)), new Exact(0));
  const documentDiscount = nonNegativeMoney(document.discount, 'discount');
  const documentTax = nonNegativeMoney(document.tax, 'tax');
  const subtotal = sum((line) => line.grossAmount);
  const discount = sum((line) => line.discount).plus(documentDiscount);
  const tax = sum((line) => line.tax).plus(documentTax);
  if (discount.gt(subtotal))
    throw new MoneyCalculationError(
      'discount',
      'Discount cannot be more than the subtotal',
    );
  const total = subtotal.minus(discount).plus(tax);
  if (subtotal.gte(MONEY_LIMIT) || total.gte(MONEY_LIMIT))
    throw new MoneyCalculationError('total', 'Total is too large');
  return { lines, subtotal, discount, tax, total };
}

function fixed(value: DecimalInput, scale: number, label: string) {
  const decimal = toDecimal(value);
  if (decimal.decimalPlaces() > scale)
    throw new MoneyCalculationError(
      'value',
      `${label} has more than ${scale} decimal places; round it before serializing`,
    );
  return decimal.toFixed(scale);
}

/** API money strings always carry two decimal places, e.g. "1500.00". */
export function toMoneyString(value: DecimalInput) {
  return fixed(value, MONEY_SCALE, 'Amount');
}

/** API quantity strings always carry four decimal places, e.g. "12.5000". */
export function toQuantityString(value: DecimalInput) {
  return fixed(value, QUANTITY_SCALE, 'Quantity');
}
