import { isDecimalLike } from './money.js';

export type JsonValue =
  string | number | boolean | null | JsonValue[] | { [key: string]: JsonValue };

/**
 * Converts Prisma results into JSON-compatible values: Decimal and BigInt become
 * strings (never floats), Dates become ISO strings, and undefined members are dropped.
 * Services should still format money with toMoneyString for a fixed scale.
 */
export function toJsonSafe(value: unknown): JsonValue | undefined {
  if (value === null) return null;
  if (value === undefined || typeof value === 'function') return undefined;
  if (typeof value === 'bigint') return value.toString();
  if (typeof value === 'number') {
    if (!Number.isFinite(value))
      throw new TypeError('Non-finite numbers cannot be serialized');
    return value;
  }
  if (typeof value === 'string' || typeof value === 'boolean') return value;
  if (isDecimalLike(value)) return value.toFixed();
  if (value instanceof Date) return value.toISOString();
  if (Array.isArray(value))
    return value.map((item) => toJsonSafe(item) ?? null);
  if (typeof value === 'object') {
    const result: { [key: string]: JsonValue } = {};
    for (const [key, member] of Object.entries(value)) {
      const converted = toJsonSafe(member);
      if (converted !== undefined) result[key] = converted;
    }
    return result;
  }
  throw new TypeError(`Unsupported value type: ${typeof value}`);
}

/** Deterministic JSON with sorted object keys, for hashing request fingerprints. */
export function canonicalJson(value: unknown): string {
  return JSON.stringify(sortKeys(toJsonSafe(value) ?? null));
}

function sortKeys(value: JsonValue): JsonValue {
  if (Array.isArray(value)) return value.map(sortKeys);
  if (value !== null && typeof value === 'object')
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, sortKeys(value[key] as JsonValue)]),
    );
  return value;
}
