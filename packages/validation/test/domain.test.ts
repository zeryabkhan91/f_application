import { describe, expect, it } from 'vitest';
import {
  moneySchema,
  quantitySchema,
  organizationSelectionSchema,
} from '../src/domain.js';

describe('database foundation contracts', () => {
  it('uses precise decimal strings and rejects floating point and excess precision', () => {
    expect(moneySchema.parse('9999999999999999.99')).toBe(
      '9999999999999999.99',
    );
    expect(moneySchema.parse('-0.01')).toBe('-0.01');
    expect(quantitySchema.parse('99999999999999.9999')).toBe(
      '99999999999999.9999',
    );
    for (const invalid of [0.3, '1.001', '10000000000000000.00', '1e2']) {
      expect(moneySchema.safeParse(invalid).success).toBe(false);
    }
    expect(quantitySchema.safeParse('0.00001').success).toBe(false);
  });

  it('requires server scope UUIDs and rejects caller-supplied permissions', () => {
    const selection = {
      userId: 'd3be513d-a672-4194-bc19-3ac3c05425fe',
      tenantId: '72f9d9e2-61fe-48ec-b030-ff33eaa662b9',
      organizationId: '68e6e98f-3692-451a-a94c-7cb83a38aba1',
    };
    expect(organizationSelectionSchema.safeParse(selection).success).toBe(true);
    expect(
      organizationSelectionSchema.safeParse({
        ...selection,
        permissions: ['tenant.write'],
      }).success,
    ).toBe(false);
    expect(
      organizationSelectionSchema.safeParse({
        ...selection,
        tenantId: 'not-a-uuid',
      }).success,
    ).toBe(false);
  });
});
