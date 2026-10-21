import type { ValidationIssue } from '@repo/types';

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    message: string,
    public readonly details?: ValidationIssue[],
  ) {
    super(message);
    this.name = 'ApiError';
  }
}
