import type { FastifyReply, FastifyRequest } from 'fastify';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { config } from './config.ts';

const EDITOR_ROLE = 'editor';
const jwks = createRemoteJWKSet(new URL(config.oidc.jwksUrl));

/**
 * preHandler for write routes: 401 without/invalid token, 403 without the editor role.
 * Checks signature (JWKS), issuer and expiry.
 */
export async function requireEditor(request: FastifyRequest, reply: FastifyReply): Promise<void> {
  const header = request.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return reply.code(401).send({ error: 'Login required' });
  }
  try {
    const { payload } = await jwtVerify(header.slice(7), jwks, { issuer: config.oidc.issuer });
    const roles = (payload.realm_access as { roles?: string[] } | undefined)?.roles ?? [];
    if (!roles.includes(EDITOR_ROLE)) {
      return reply.code(403).send({ error: 'Editor role required' });
    }
  } catch (err) {
    request.log.info({ reason: (err as Error).message }, 'token rejected');
    return reply.code(401).send({ error: 'Invalid or expired token' });
  }
}
