import { randomUUID } from 'node:crypto';

const requestIdPattern = /^[a-zA-Z0-9_-]{1,128}$/;

export function requestId(candidate: unknown): string {
  return typeof candidate === 'string' && requestIdPattern.test(candidate)
    ? candidate
    : randomUUID();
}

export * from './money.js';
export * from './json.js';
