import type { ApiRoute } from '../http/route.js';
import { systemRoutes } from './system/routes.js';

/** Every /api/v1 route. Registering here also publishes it in OpenAPI. */
export const apiRoutes: readonly ApiRoute[] = [...systemRoutes];
