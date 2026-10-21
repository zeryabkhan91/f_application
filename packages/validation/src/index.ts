import { z } from 'zod';

export const serviceInfoSchema = z.object({
  name: z.literal('f-application-api'),
  version: z.string(),
});

export const liveHealthSchema = z.object({ status: z.literal('ok') });
export const readyHealthSchema = z.object({ status: z.literal('ready') });
export const unavailableHealthSchema = z.object({
  status: z.literal('not_ready'),
});

export const validationIssueSchema = z.object({
  path: z.string(),
  message: z.string(),
});

export const errorResponseSchema = z.object({
  error: z.object({
    code: z.string(),
    message: z.string(),
    requestId: z.string(),
    details: z.array(validationIssueSchema).optional(),
  }),
});

// Re-export one Zod instance so schemas stay consistent across workspaces.
export { z };
