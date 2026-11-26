import Fastify from 'fastify';
import { config } from './config.ts';
import { initSchemaWithRetry, isSchemaReady, pool } from './db.ts';
import { textRoutes } from './texts.ts';

const app = Fastify({ logger: true, bodyLimit: 1024 * 1024 });

// Never leak stack traces or internals to clients.
app.setErrorHandler((err: { statusCode?: number; message?: string }, request, reply) => {
  const status = err.statusCode && err.statusCode < 500 ? err.statusCode : 500;
  if (status >= 500) request.log.error(err);
  reply.code(status).send({ error: status >= 500 ? 'Internal error' : (err.message ?? 'Bad request') });
});

app.get('/healthz', async () => ({ status: 'ok' }));

app.get('/readyz', async (_request, reply) => {
  try {
    if (!isSchemaReady()) throw new Error('schema not ready');
    await pool.query('SELECT 1');
    return { status: 'ready' };
  } catch {
    return reply.code(503).send({ error: 'Database unavailable' });
  }
});

await app.register(textRoutes);

void initSchemaWithRetry();
await app.listen({ host: '0.0.0.0', port: config.port });

for (const signal of ['SIGTERM', 'SIGINT']) {
  process.on(signal, async () => {
    await app.close();
    await pool.end();
    process.exit(0);
  });
}
