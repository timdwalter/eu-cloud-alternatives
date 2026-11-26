import pg from 'pg';
import { config } from './config.ts';

export const pool = new pg.Pool({
  ...config.db,
  ssl: config.db.ssl ? { rejectUnauthorized: true } : false,
  max: 5,
  connectionTimeoutMillis: 5000,
});

// An idle client losing its connection must not crash the process.
pool.on('error', (err) => console.error('db pool error:', err.message));

const SEED_TITLE = 'Lorem ipsum';
const SEED_BODY = `Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.

Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.`;

let schemaReady = false;
export const isSchemaReady = () => schemaReady;

async function initSchema(): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(`
      CREATE TABLE IF NOT EXISTS texts (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        title text NOT NULL,
        body text NOT NULL,
        updated_at timestamptz NOT NULL DEFAULT now()
      )`);
    await client.query('CREATE TABLE IF NOT EXISTS app_meta (key text PRIMARY KEY, value text NOT NULL)');
    // Seed exactly once – deleting all texts later must not bring the seed back.
    const seeded = await client.query(
      "INSERT INTO app_meta (key, value) VALUES ('seeded', 'true') ON CONFLICT (key) DO NOTHING RETURNING key",
    );
    if (seeded.rowCount === 1) {
      await client.query('INSERT INTO texts (title, body) VALUES ($1, $2)', [SEED_TITLE, SEED_BODY]);
    }
    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    throw err;
  } finally {
    client.release();
  }
}

/** Retries until the database is reachable; the HTTP server runs meanwhile (readyz = 503). */
export async function initSchemaWithRetry(): Promise<void> {
  for (;;) {
    try {
      await initSchema();
      schemaReady = true;
      console.log('database schema ready');
      return;
    } catch (err) {
      console.error('database not ready, retrying in 3 s:', (err as Error).message);
      await new Promise((resolve) => setTimeout(resolve, 3000));
    }
  }
}
