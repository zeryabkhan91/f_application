import { parseEnvironment } from '@repo/config';
import { createDatabase, withOrganization } from '@repo/db';
import { pino } from 'pino';
import { createApp } from './app.js';

const config = parseEnvironment(process.env);
const logger = pino({
  level: config.LOG_LEVEL,
  redact: [
    'req.headers.authorization',
    'req.headers.cookie',
    'res.headers.set-cookie',
    'req.body',
    '*.password',
    '*.passwordHash',
    '*.token',
    '*.accessToken',
    '*.refreshToken',
  ],
});
const db = createDatabase(config.DATABASE_URL);
let shuttingDown = false;
const app = createApp({
  config,
  logger,
  checkDatabase: async () => {
    await db.$queryRaw`SELECT 1`;
  },
  isShuttingDown: () => shuttingDown,
  runInOrganization: (selection, work) => withOrganization(db, selection, work),
});

const server = app.listen(config.PORT, config.HOST, () => {
  logger.info({ host: config.HOST, port: config.PORT }, 'API listening');
});
server.on('error', (error) => {
  logger.fatal({ err: error }, 'API failed to listen');
  void db.$disconnect().finally(() => process.exit(1));
});

function shutdown(signal: string) {
  if (shuttingDown) return;
  shuttingDown = true;
  logger.info({ signal }, 'Draining requests');
  const deadline = setTimeout(() => {
    logger.error('Shutdown deadline exceeded');
    process.exit(1);
  }, 25_000);
  deadline.unref();
  server.close((error) => {
    void db
      .$disconnect()
      .then(() => {
        clearTimeout(deadline);
        process.exit(error ? 1 : 0);
      })
      .catch((disconnectError: unknown) => {
        logger.error({ err: disconnectError }, 'Database disconnect failed');
        process.exit(1);
      });
  });
}

process.once('SIGTERM', () => shutdown('SIGTERM'));
process.once('SIGINT', () => shutdown('SIGINT'));
