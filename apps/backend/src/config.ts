function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing environment variable ${name}`);
  return value;
}

export const config = {
  port: Number(process.env.PORT ?? 8080),
  db: {
    host: required('DB_HOST'),
    port: Number(process.env.DB_PORT ?? 5432),
    database: required('DB_NAME'),
    user: required('DB_USER'),
    password: required('DB_PASSWORD'),
    // "true" = TLS with certificate verification, "require" = TLS without verification (provider CA not
    // publicly trusted, e.g. Scaleway), anything else = no TLS (local)
    ssl: (process.env.DB_SSL ?? 'false') as 'true' | 'require' | string,
  },
  oidc: {
    // Issuer as it appears in the token (public URL)
    issuer: required('OIDC_ISSUER'),
    // Where the backend fetches the signing keys (may be an internal URL)
    jwksUrl: required('OIDC_JWKS_URL'),
  },
};
