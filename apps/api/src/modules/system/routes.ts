import { serviceInfoSchema } from '@repo/validation';
import { publicRoute } from '../../http/route.js';

export const systemRoutes = [
  publicRoute({
    method: 'get',
    path: '/',
    operationId: 'getServiceInfo',
    summary: 'API identity and version',
    tags: ['System'],
    response: {
      status: 200,
      description: 'Service information',
      schema: serviceInfoSchema,
    },
    handler: async () => ({
      name: 'f-application-api' as const,
      version: '0.1.0',
    }),
  }),
];
