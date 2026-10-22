import { pino, type Logger } from 'pino';
import { parseEnvironment } from '@repo/config';
import { createApp, type AppDependencies } from '../../src/app.js';
import type { AuthenticatedSelection } from '../../src/http/authentication.js';

export const testConfig = parseEnvironment({
  DATABASE_URL: 'postgresql://test:test@localhost:5432/test',
  NODE_ENV: 'test',
  CORS_ORIGINS: 'http://localhost:3000',
});

/** Test-only session stand-in: identity comes from the test, never from the request. */
export function fixedAuthenticator(
  selection: () => AuthenticatedSelection | null,
) {
  return { authenticate: async () => selection() };
}

export function testApp(
  overrides: Partial<AppDependencies> & { logger?: Logger } = {},
) {
  return createApp({
    config: testConfig,
    logger: pino({ level: 'silent' }),
    checkDatabase: async () => {},
    ...overrides,
  });
}
