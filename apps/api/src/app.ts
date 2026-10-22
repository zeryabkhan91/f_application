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
  unavailableHealthSchema,
} from '@repo/validation';
import swaggerUi from 'swagger-ui-express';
import {
  denyAllAuthenticator,
  resolveAuthentication,
  type Authenticator,
} from './http/authentication.js';
import { buildOpenApiPaths } from './http/openapi-paths.js';
import type { ApiRoute } from './http/route.js';
import { createApiRouter, type OrganizationRunner } from './http/router.js';
import { ApiError } from './lib/api-error.js';
import { errorHandler } from './middleware/error-handler.js';
import { apiRoutes } from './modules/index.js';
import { createOpenApiDocument } from './openapi.js';

export interface AppDependencies {
  config: Environment;
  logger: Logger;
  checkDatabase: () => Promise<void>;
  isShuttingDown?: () => boolean;
  /** Resolves the session; defaults to denying every organization route. */
  authenticator?: Authenticator;
  /** Scoped transaction runner; production binds withOrganization to the runtime client. */
  runInOrganization?: OrganizationRunner;
  routes?: readonly ApiRoute[];
}

const databaseNotConfigured: OrganizationRunner = async () => {
  throw new Error('Organization database access is not configured');
};

export function createApp({
  config,
  logger,
  checkDatabase,
  isShuttingDown = () => false,
  authenticator = denyAllAuthenticator,
  runInOrganization = databaseNotConfigured,
  routes = apiRoutes,
}: AppDependencies) {
  // Fails fast on duplicate operations or path/params drift even when docs are off.
  buildOpenApiPaths(routes);
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
      // Bodies are never logged: auth routes carry passwords and tokens.
      customProps: (_req, res) => {
        const auth = (res as express.Response).locals?.auth;
        return auth
          ? {
              userId: auth.userId,
              tenantId: auth.tenantId,
              organizationId: auth.organizationId,
            }
          : {};
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
  app.use(
    '/api/v1',
    resolveAuthentication(authenticator),
    createApiRouter(routes, runInOrganization),
  );

  if (config.apiDocsEnabled) {
    const document = createOpenApiDocument(routes);
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
