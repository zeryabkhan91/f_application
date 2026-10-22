import type { ValidationIssue } from '@repo/types';

export class ApiError extends Error {
  /** First message per path, derived from details so the two never disagree. */
  public readonly fields?: Record<string, string>;

  constructor(
    public readonly status: number,
    public readonly code: string,
    message: string,
    public readonly details?: ValidationIssue[],
  ) {
    super(message);
    this.name = 'ApiError';
    if (details?.length) {
      const fields: Record<string, string> = {};
      for (const issue of details) fields[issue.path] ??= issue.message;
      this.fields = fields;
    }
  }
}
