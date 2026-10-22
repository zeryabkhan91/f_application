import { z } from '@repo/validation';
import type { ApiRoute, RouteError } from './route.js';
import { IDEMPOTENCY_HEADER } from './router.js';

export const API_PREFIX = '/api/v1';
const ERROR_REF = { $ref: '#/components/schemas/ErrorResponse' };

type JsonSchema = Record<string, unknown>;

function jsonSchema(schema: z.ZodType, io: 'input' | 'output'): JsonSchema {
  return z.toJSONSchema(schema, {
    target: 'openapi-3.0',
    io,
    unrepresentable: 'any',
  }) as JsonSchema;
}

function openApiPath(path: string) {
  const full = path === '/' ? API_PREFIX : `${API_PREFIX}${path}`;
  return full.replace(/:([A-Za-z0-9_]+)/g, '{$1}');
}

function parameters(schema: z.ZodType | undefined, location: 'path' | 'query') {
  if (!schema) return [];
  if (!(schema instanceof z.ZodObject))
    throw new Error(`${location} schemas must be z.object() schemas`);
  return Object.entries(schema.shape as Record<string, z.ZodType>).map(
    ([name, field]) => {
      const { description, ...fieldSchema } = jsonSchema(field, 'input');
      return {
        name,
        in: location,
        required: location === 'path' || !field.safeParse(undefined).success,
        schema: fieldSchema,
        ...(typeof description === 'string' ? { description } : {}),
      };
    },
  );
}

/** Standard failures every route of this kind can return, plus its own errors. */
function errorsFor(route: ApiRoute): RouteError[] {
  const errors: RouteError[] = [];
  if (route.body)
    errors.push(
      {
        status: 400,
        code: 'INVALID_JSON',
        description: 'Body is not valid JSON',
      },
      {
        status: 413,
        code: 'PAYLOAD_TOO_LARGE',
        description: 'Body exceeds 1 MB',
      },
    );
  if (route.access === 'organization')
    errors.push(
      { status: 401, code: 'UNAUTHENTICATED', description: 'No valid session' },
      {
        status: 403,
        code: 'FORBIDDEN',
        description: `Membership lacks \`${route.permission}\``,
      },
      {
        status: 403,
        code: 'ORGANIZATION_ACCESS_DENIED',
        description: 'Membership, organization, or account is not active',
      },
    );
  if (route.access === 'organization' && route.idempotent)
    errors.push(
      {
        status: 400,
        code: 'INVALID_IDEMPOTENCY_KEY',
        description: 'Idempotency-Key header is malformed',
      },
      {
        status: 409,
        code: 'IDEMPOTENCY_KEY_REUSED',
        description: 'Key was already used with a different request',
      },
      {
        status: 428,
        code: 'IDEMPOTENCY_KEY_REQUIRED',
        description: 'Idempotency-Key header is missing',
      },
    );
  if (route.params || route.query || route.body)
    errors.push({
      status: 422,
      code: 'VALIDATION_ERROR',
      description: 'Input failed validation; see error.fields',
    });
  errors.push(
    { status: 429, code: 'RATE_LIMITED', description: 'Too many requests' },
    {
      status: 500,
      code: 'INTERNAL_ERROR',
      description: 'Unexpected server error',
    },
  );
  return [...errors, ...(route.errors ?? [])];
}

function operation(route: ApiRoute) {
  const responses: Record<string, unknown> = {
    [route.response.status]: {
      description: route.response.description,
      ...(route.response.schema
        ? {
            content: {
              'application/json': {
                schema: jsonSchema(route.response.schema, 'output'),
              },
            },
          }
        : {}),
    },
  };
  const byStatus = new Map<number, RouteError[]>();
  for (const error of errorsFor(route))
    byStatus.set(error.status, [...(byStatus.get(error.status) ?? []), error]);
  for (const [status, errors] of [...byStatus].sort(([a], [b]) => a - b))
    responses[status] = {
      description: errors
        .map((e) => `\`${e.code}\`: ${e.description}`)
        .join('. '),
      content: { 'application/json': { schema: ERROR_REF } },
    };

  const permission =
    route.access === 'organization'
      ? `Requires an active organization membership with permission \`${route.permission}\`.`
      : undefined;
  const description = [route.description, permission]
    .filter(Boolean)
    .join('\n\n');
  const idempotencyHeader =
    route.access === 'organization' && route.idempotent
      ? [
          {
            name: IDEMPOTENCY_HEADER,
            in: 'header',
            required: true,
            description:
              'Client-generated key (UUID recommended). Retries with the same key and body replay the original response for 24 hours.',
            schema: { type: 'string', pattern: '^[A-Za-z0-9_.:-]{8,128}$' },
          },
        ]
      : [];
  const params = [
    ...parameters(route.params, 'path'),
    ...parameters(route.query, 'query'),
    ...idempotencyHeader,
  ];
  return {
    operationId: route.operationId,
    summary: route.summary,
    ...(description ? { description } : {}),
    tags: [...route.tags],
    ...(params.length ? { parameters: params } : {}),
    ...(route.body
      ? {
          requestBody: {
            required: true,
            content: {
              'application/json': { schema: jsonSchema(route.body, 'input') },
            },
          },
        }
      : {}),
    responses,
    ...(route.access === 'organization'
      ? { 'x-permission': route.permission }
      : {}),
  };
}

/** Builds OpenAPI paths from the same definitions that register the handlers. */
export function buildOpenApiPaths(routes: readonly ApiRoute[]) {
  const paths: Record<string, Record<string, unknown>> = {};
  const operationIds = new Set<string>();
  for (const route of routes) {
    const path = openApiPath(route.path);
    if (operationIds.has(route.operationId))
      throw new Error(`Duplicate operationId ${route.operationId}`);
    operationIds.add(route.operationId);
    if (paths[path]?.[route.method])
      throw new Error(`Duplicate route ${route.method.toUpperCase()} ${path}`);
    const declared = Object.keys(
      route.params instanceof z.ZodObject ? route.params.shape : {},
    ).sort();
    const placeholders = [...route.path.matchAll(/:([A-Za-z0-9_]+)/g)]
      .map((match) => match[1])
      .sort();
    if (declared.join() !== placeholders.join())
      throw new Error(
        `${route.operationId}: params schema must declare exactly ${placeholders.join(', ') || 'no keys'}`,
      );
    paths[path] = { ...paths[path], [route.method]: operation(route) };
  }
  return paths;
}
