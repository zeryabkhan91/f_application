import type {
  errorResponseSchema,
  liveHealthSchema,
  readyHealthSchema,
  serviceInfoSchema,
  unavailableHealthSchema,
  validationIssueSchema,
  z,
} from '@repo/validation';

export type ServiceInfo = z.infer<typeof serviceInfoSchema>;
export type LiveHealth = z.infer<typeof liveHealthSchema>;
export type ReadyHealth = z.infer<typeof readyHealthSchema>;
export type UnavailableHealth = z.infer<typeof unavailableHealthSchema>;
export type ValidationIssue = z.infer<typeof validationIssueSchema>;
export type ErrorResponse = z.infer<typeof errorResponseSchema>;
