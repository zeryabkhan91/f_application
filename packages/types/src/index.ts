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

import type {
  organizationSelectionSchema,
  organizationContextSchema,
  roleCodeSchema,
  permissionCodeSchema,
  numberSequenceTypeSchema,
} from '@repo/validation';

export type OrganizationSelection = z.infer<typeof organizationSelectionSchema>;
export type OrganizationContext = Readonly<
  Omit<z.infer<typeof organizationContextSchema>, 'permissions'> & {
    permissions: readonly PermissionCode[];
  }
>;
export type RoleCode = z.infer<typeof roleCodeSchema>;
export type PermissionCode = z.infer<typeof permissionCodeSchema>;
export type NumberSequenceType = z.infer<typeof numberSequenceTypeSchema>;
