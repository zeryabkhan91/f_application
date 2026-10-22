import type { Request, Response } from 'express';
import type { Logger } from 'pino';
import type { AuditEntry, AuditRequestMetadata, Prisma } from '@repo/db';
import type { OrganizationContext, PermissionCode } from '@repo/types';
import type { z } from '@repo/validation';

export type HttpMethod = 'get' | 'post' | 'put' | 'patch' | 'delete';
export type SuccessStatus = 200 | 201 | 204;

/** A route-specific failure, documented in OpenAPI beside the standard errors. */
export interface RouteError {
  status: number;
  code: string;
  description: string;
}

type Schema = z.ZodType | undefined;
type Parsed<S extends Schema> = S extends z.ZodType ? z.output<S> : undefined;
type Returned<S extends Schema> = S extends z.ZodType ? z.input<S> : void;

interface RouteShape<
  P extends Schema,
  Q extends Schema,
  B extends Schema,
  R extends Schema,
> {
  method: HttpMethod;
  /** Express path relative to /api/v1, e.g. "/customers/:id". */
  path: string;
  /** Unique, stable OpenAPI operationId used by generated clients. */
  operationId: string;
  summary: string;
  description?: string;
  tags: readonly string[];
  params?: P;
  query?: Q;
  body?: B;
  response: {
    status: SuccessStatus;
    description: string;
    /** The full response body (use dataEnvelope/listEnvelope); omit for 204. */
    schema?: R;
  };
  errors?: readonly RouteError[];
}

interface HandlerInput<P extends Schema, Q extends Schema, B extends Schema> {
  params: Parsed<P>;
  query: Parsed<Q>;
  body: Parsed<B>;
  request: AuditRequestMetadata;
  log: Logger;
}

export interface OrganizationHandlerInput<
  P extends Schema,
  Q extends Schema,
  B extends Schema,
> extends HandlerInput<P, Q, B> {
  /** Scoped transaction: RLS, membership, and permission are already enforced. */
  tx: Prisma.TransactionClient;
  context: OrganizationContext;
  /** Records an audit entry in this transaction with the request metadata. */
  audit(entry: AuditEntry): Promise<void>;
}

export interface PublicHandlerInput<
  P extends Schema,
  Q extends Schema,
  B extends Schema,
> extends HandlerInput<P, Q, B> {
  req: Request;
  res: Response;
}

export interface OrganizationRouteDefinition<
  P extends Schema = Schema,
  Q extends Schema = Schema,
  B extends Schema = Schema,
  R extends Schema = Schema,
> extends RouteShape<P, Q, B, R> {
  access: 'organization';
  /** Checked against the member's role mappings before the handler runs. */
  permission: PermissionCode;
  /** Requires an Idempotency-Key header and replays the committed response on retry. */
  idempotent?: boolean;
  /** The controller: map input to a service call and return the response body. */
  handler(input: OrganizationHandlerInput<P, Q, B>): Promise<Returned<R>>;
}

export interface PublicRouteDefinition<
  P extends Schema = Schema,
  Q extends Schema = Schema,
  B extends Schema = Schema,
  R extends Schema = Schema,
> extends RouteShape<P, Q, B, R> {
  access: 'public';
  handler(input: PublicHandlerInput<P, Q, B>): Promise<Returned<R>>;
}

export type ApiRoute = OrganizationRouteDefinition | PublicRouteDefinition;

/** Declares an authenticated, organization-scoped route; see docs/architecture/api.md. */
export function organizationRoute<
  P extends Schema = undefined,
  Q extends Schema = undefined,
  B extends Schema = undefined,
  R extends Schema = undefined,
>(route: Omit<OrganizationRouteDefinition<P, Q, B, R>, 'access'>): ApiRoute {
  return { ...route, access: 'organization' } as OrganizationRouteDefinition;
}

/** Declares a route that needs no session, such as login or service information. */
export function publicRoute<
  P extends Schema = undefined,
  Q extends Schema = undefined,
  B extends Schema = undefined,
  R extends Schema = undefined,
>(route: Omit<PublicRouteDefinition<P, Q, B, R>, 'access'>): ApiRoute {
  return { ...route, access: 'public' } as PublicRouteDefinition;
}
