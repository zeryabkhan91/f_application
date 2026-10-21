import { describe, expect, it } from 'vitest';
import { requestId } from '../src/index.js';

describe('request IDs', () => {
  it('preserves safe correlation IDs and replaces malformed inputs', () => {
    expect(requestId('safe_123-abc')).toBe('safe_123-abc');
    for (const value of [
      undefined,
      ['one', 'two'],
      'bad\r\nheader',
      'x'.repeat(129),
    ]) {
      expect(requestId(value)).toMatch(/^[a-f0-9-]{36}$/);
    }
  });
});
