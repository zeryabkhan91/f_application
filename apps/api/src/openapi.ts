import {
  errorResponseSchema,
  liveHealthSchema,
  readyHealthSchema,
  unavailableHealthSchema,
  z,
} from '@repo/validation';
import { buildOpenApiPaths } from './http/openapi-paths.js';
import type { ApiRoute } from './http/route.js';
import { apiRoutes } from './modules/index.js';

/** Health probes live outside /api/v1 and keep their hand-written docs; all API paths are generated. */
export function createOpenApiDocument(routes: readonly ApiRoute[] = apiRoutes) {
  const definitions = {
    ErrorResponse: errorResponseSchema,
    LiveHealth: liveHealthSchema,
    ReadyHealth: readyHealthSchema,
    UnavailableHealth: unavailableHealthSchema,
  };
  const schemas = Object.fromEntries(
    Object.entries(definitions).map(([name, schema]) => [
      name,
      z.toJSONSchema(schema, { target: 'openapi-3.0' }),
    ]),
  );
  const json = (name: keyof typeof definitions) => ({
    'application/json': { schema: { $ref: `#/components/schemas/${name}` } },
  });

  return {
    openapi: '3.0.3',
    info: {
      title: 'F Application API',
      version: '0.1.0',
      description:
        'Factory management API. Organization routes require an authenticated session; each documents its required permission.',
    },
    servers: [{ url: '/' }],
    components: { schemas },
    paths: {
      '/health/live': {
        get: {
          summary: 'Process liveness',
          tags: ['Health'],
          responses: {
            200: {
              description: 'Process is running',
              content: json('LiveHealth'),
            },
          },
        },
      },
      '/health/ready': {
        get: {
          summary: 'Database and process readiness',
          tags: ['Health'],
          responses: {
            200: {
              description: 'Ready for requests',
              content: json('ReadyHealth'),
            },
            503: {
              description: 'Database unavailable or shutting down',
              content: json('UnavailableHealth'),
            },
          },
        },
      },
      ...buildOpenApiPaths(routes),
    },
  };
}
