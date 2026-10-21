import { describe, expect, it } from 'vitest';
import { parseEnvironment } from '../src/index.js';

const base = { DATABASE_URL: 'postgresql://local:local@localhost:5432/test' };

describe('environment configuration', () => {
  it('parses ports, booleans and allowlisted origins', () => {
    const config = parseEnvironment({
      ...base,
      PORT: '4321',
      ENABLE_API_DOCS: 'false',
      CORS_ORIGINS: 'https://one.example,https://two.example',
    });
    expect(config.PORT).toBe(4321);
    expect(config.apiDocsEnabled).toBe(false);
    expect(config.corsOrigins).toEqual([
      'https://one.example',
      'https://two.example',
    ]);
  });

  it('requires a database and explicit production origins without exposing values', () => {
    expect(() => parseEnvironment({})).toThrow('DATABASE_URL');
    expect(() => parseEnvironment({ ...base, NODE_ENV: 'production' })).toThrow(
      'CORS_ORIGINS',
    );
    expect(() => parseEnvironment({ ...base, CORS_ORIGINS: '*' })).toThrow(
      'CORS_ORIGINS',
    );
    expect(() =>
      parseEnvironment({ ...base, CORS_ORIGINS: 'https://site.example/path' }),
    ).toThrow('CORS_ORIGINS');
    expect(() =>
      parseEnvironment({ ...base, DATABASE_URL: 'private-password' }),
    ).toThrow('Invalid environment variables: DATABASE_URL');
  });
});
