import NextAuth from 'next-auth';

// Public issuer = what the browser uses and what appears in tokens (iss).
// Internal issuer = how this server reaches Keycloak (e.g. http://keycloak:8080/realms/x in Docker).
// Discovery is not used on purpose: the public URL is not reachable from inside the container network
// (see specs/001-azure/research.md R3), so all endpoints are configured explicitly.
const issuer = process.env.AUTH_KEYCLOAK_ISSUER ?? '';
const internal = process.env.AUTH_KEYCLOAK_INTERNAL_ISSUER || issuer;

type AccessTokenClaims = {
  sub: string;
  preferred_username?: string;
  email?: string;
  exp?: number;
  realm_access?: { roles?: string[] };
};

function decodeJwt(token: string): AccessTokenClaims {
  return JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString('utf8'));
}

declare module 'next-auth' {
  interface Session {
    accessToken?: string;
    roles: string[];
    expired: boolean;
  }
}

export const { handlers, auth, signIn, signOut } = NextAuth({
  trustHost: true,
  providers: [
    {
      id: 'keycloak',
      name: 'Keycloak',
      type: 'oauth',
      clientId: process.env.AUTH_KEYCLOAK_ID,
      clientSecret: process.env.AUTH_KEYCLOAK_SECRET,
      // No "openid" scope: plain OAuth 2.0 flow without ID token, profile is read from the access token.
      authorization: { url: `${issuer}/protocol/openid-connect/auth`, params: { scope: 'profile email' } },
      token: `${internal}/protocol/openid-connect/token`,
      userinfo: {
        url: `${internal}/protocol/openid-connect/userinfo`,
        async request({ tokens }: { tokens: { access_token?: string } }) {
          return decodeJwt(tokens.access_token ?? '');
        },
      },
      checks: ['pkce', 'state'],
      profile(claims: AccessTokenClaims) {
        return { id: claims.sub, name: claims.preferred_username ?? claims.sub, email: claims.email };
      },
    },
  ],
  callbacks: {
    jwt({ token, account }) {
      if (account?.access_token) {
        const claims = decodeJwt(account.access_token);
        token.accessToken = account.access_token;
        token.expiresAt = claims.exp ?? 0;
        token.roles = claims.realm_access?.roles ?? [];
      }
      return token;
    },
    session({ session, token }) {
      const expiresAt = (token.expiresAt as number | undefined) ?? 0;
      session.accessToken = token.accessToken as string | undefined;
      session.roles = (token.roles as string[] | undefined) ?? [];
      // No refresh flow (kept minimal): an expired access token means "log in again".
      session.expired = expiresAt * 1000 < Date.now();
      return session;
    },
  },
});

export async function getEditorSession() {
  const session = await auth();
  const isEditor = !!session && !session.expired && session.roles.includes('editor');
  return { session, isEditor };
}
