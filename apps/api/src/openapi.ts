import {
  errorResponseSchema,
  liveHealthSchema,
  readyHealthSchema,
  serviceInfoSchema,
  unavailableHealthSchema,
  z,
} from '@repo/validation';

export function createOpenApiDocument() {
  const definitions = {
    ErrorResponse: errorResponseSchema,
    LiveHealth: liveHealthSchema,
    ReadyHealth: readyHealthSchema,
    UnavailableHealth: unavailableHealthSchema,
    ServiceInfo: serviceInfoSchema,
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
        'Backend foundation. Business and authentication endpoints will be added as requirements are defined.',
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
      '/api/v1': {
        get: {
          summary: 'API identity and version',
          tags: ['System'],
          responses: {
            200: {
              description: 'Service information',
              content: json('ServiceInfo'),
            },
            429: {
              description: 'Rate limit exceeded',
              content: json('ErrorResponse'),
            },
            500: {
              description: 'Internal error',
              content: json('ErrorResponse'),
            },
          },
        },
      },
    },
  };
}
