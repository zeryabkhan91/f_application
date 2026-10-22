import type { Request, RequestHandler } from 'express';
import type { OrganizationSelection } from '@repo/types';

/** Identity resolved by the server from a verified session; never from request fields. */
export type AuthenticatedSelection = OrganizationSelection;

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Locals {
      auth?: Readonly<AuthenticatedSelection>;
    }
  }
}

/**
 * Task 3 implements this with verified session cookies. Implementations must
 * derive the user and active organization from server-side session state.
 */
export interface Authenticator {
  authenticate(req: Request): Promise<AuthenticatedSelection | null>;
}

/** Default until sessions exist: every organization route answers 401. */
export const denyAllAuthenticator: Authenticator = {
  authenticate: async () => null,
};

export function resolveAuthentication(
  authenticator: Authenticator,
): RequestHandler {
  return async (req, res, next) => {
    const selection = await authenticator.authenticate(req);
    if (selection) {
      res.locals.auth = Object.freeze({ ...selection });
      req.log = req.log.child({
        userId: selection.userId,
        tenantId: selection.tenantId,
        organizationId: selection.organizationId,
      });
    }
    next();
  };
}
