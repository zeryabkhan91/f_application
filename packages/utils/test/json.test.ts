import { Decimal } from 'decimal.js';
import { describe, expect, it } from 'vitest';
import { canonicalJson, toJsonSafe } from '../src/index.js';

describe('JSON serialization', () => {
  it('converts Decimal, BigInt, and Date without floating-point conversion', () => {
    expect(
      toJsonSafe({
        amount: new Decimal('12345678901234567.89'),
        size: 9007199254740993n,
        at: new Date('2026-10-22T08:00:00.000Z'),
        nested: [{ value: new Decimal('0.10') }, undefined],
        skipped: undefined,
        empty: null,
      }),
    ).toEqual({
      amount: '12345678901234567.89',
      size: '9007199254740993',
      at: '2026-10-22T08:00:00.000Z',
      nested: [{ value: '0.1' }, null],
      empty: null,
    });
  });

  it('rejects values JSON cannot represent faithfully', () => {
    expect(() => toJsonSafe(Number.NaN)).toThrow(TypeError);
    expect(() => toJsonSafe(Symbol('x'))).toThrow(TypeError);
  });

  it('produces key-order independent canonical JSON', () => {
    expect(
      canonicalJson({ b: 1, a: { d: [2, { f: 1, e: 0 }], c: null } }),
    ).toBe(canonicalJson({ a: { c: null, d: [2, { e: 0, f: 1 }] }, b: 1 }));
    expect(canonicalJson({ a: 1, b: 2 })).toBe('{"a":1,"b":2}');
  });
});
