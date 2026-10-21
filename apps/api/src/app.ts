import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { rateLimit } from 'express-rate-limit';
import { pinoHttp } from 'pino-http';
import type { Logger } from 'pino';
import type { Environment } from '@repo/config';
import { requestId } from '@repo/utils';
import {
  errorResponseSchema,
  liveHealthSchema,
  readyHealthSchema,
  serviceInfoSchema,
  unavailableHealthSchema,
} from '@repo/validation';
import swaggerUi from 'swagger-ui-express';
import { ApiError } from './lib/api-error.js';
import { errorHandler } from './middleware/error-handler.js';
import { createOpenApiDocument } from './openapi.js';

export interface AppDependencies {
  config: Environment;
  logger: Logger;
  checkDatabase: () => Promise<void>;
  isShuttingDown?: () => boolean;
}

export function createApp({
  config,
  logger,
  checkDatabase,
  isShuttingDown = () => false,
}: AppDependencies) {
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', config.TRUST_PROXY_HOPS);
  app.use(
    pinoHttp({
      logger,
      genReqId: (req, res) => {
        const id = requestId(req.headers['x-request-id']);
        res.setHeader('X-Request-Id', id);
        return id;
      },
      serializers: {
        req: (req) => ({
          id: req.id,
          method: req.method,
          url: req.url?.split('?')[0],
        }),
      },
      autoLogging: { ignore: (req) => req.url === '/health/live' },
    }),
  );
  app.use((req, res, next) => {
    res.locals.requestId = String(req.id);
    next();
  });
  app.use(helmet());
  app.use(
    cors({
      origin: (origin, callback) => {
        if (!origin || config.corsOrigins.includes(origin))
          return callback(null, true);
        callback(
          new ApiError(403, 'ORIGIN_NOT_ALLOWED', 'Origin is not allowed'),
        );
      },
      exposedHeaders: ['X-Request-Id'],
      maxAge: 600,
    }),
  );
  app.use(express.json({ limit: '1mb' }));

  app.get('/health/live', (_req, res) => {
    res.setHeader('Cache-Control', 'no-store');
    res.json(liveHealthSchema.parse({ status: 'ok' }));
  });
  app.get('/health/ready', async (req, res) => {
    res.setHeader('Cache-Control', 'no-store');
    if (isShuttingDown()) {
      res
        .status(503)
        .json(unavailableHealthSchema.parse({ status: 'not_ready' }));
      return;
    }
    try {
      await checkDatabase();
      res.json(readyHealthSchema.parse({ status: 'ready' }));
    } catch {
      req.log.warn('Database readiness check failed');
      res
        .status(503)
        .json(unavailableHealthSchema.parse({ status: 'not_ready' }));
    }
  });

  app.use(
    '/api',
    rateLimit({
      windowMs: 60_000,
      limit: 120,
      standardHeaders: 'draft-8',
      legacyHeaders: false,
      handler: (_req, res) => {
        res.status(429).json(
          errorResponseSchema.parse({
            error: {
              code: 'RATE_LIMITED',
              message: 'Too many requests. Try again later.',
              requestId: res.locals.requestId,
            },
          }),
        );
      },
    }),
  );
  app.get('/api/v1', (_req, res) => {
    res.json(
      serviceInfoSchema.parse({ name: 'f-application-api', version: '0.1.0' }),
    );
  });

  if (config.apiDocsEnabled) {
    const document = createOpenApiDocument();
    app.get('/openapi.json', (_req, res) => res.json(document));
    app.use(
      '/docs',
      helmet.contentSecurityPolicy({
        directives: {
          scriptSrc: ["'self'", "'unsafe-inline'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
        },
      }),
      swaggerUi.serve,
      swaggerUi.setup(document, { swaggerOptions: { validatorUrl: null } }),
    );
  }

  app.use((_req, _res, next) => {
    next(new ApiError(404, 'NOT_FOUND', 'Route not found'));
  });
  app.use(errorHandler);
  return app;
}
