import { describe, expect, it } from 'vitest';
import { domainEnums } from '@repo/validation';
import * as databaseEnums from '../src/generated/prisma/enums.js';
import { defaultPermissions } from '../src/seeds/organization-defaults.js';

describe('shared domain definitions', () => {
  it('keeps every shared enum aligned with Prisma', () => {
    for (const [name, values] of Object.entries(domainEnums)) {
      const actual = databaseEnums[name as keyof typeof databaseEnums];
      expect(Object.values(actual).sort(), name).toEqual([...values].sort());
    }
    expect(Object.keys(databaseEnums).sort()).toEqual(
      Object.keys(domainEnums).sort(),
    );
  });

  it('gives viewers read permissions and leaves custom roles unprivileged', () => {
    expect(
      defaultPermissions('VIEWER').every((permission) =>
        permission.endsWith('.read'),
      ),
    ).toBe(true);
    expect(defaultPermissions('CUSTOM')).toEqual([]);
    expect(defaultPermissions('OWNER')).toContain('tenant.write');
    expect(defaultPermissions('ADMIN')).not.toContain('tenant.write');
  });
});
