import type { FastifyInstance, FastifyReply } from 'fastify';
import { requireEditor } from './auth.ts';
import { pool } from './db.ts';

// Limits from specs/001-azure/data-model.md (Text.title, Text.body)
const TITLE_MAX = 200;
const BODY_MAX = 100_000;

type TextRow = { id: string; title: string; body: string; updated_at: Date };
type IdParams = { id: string };

const toText = (row: TextRow) => ({ id: row.id, title: row.title, body: row.body, updatedAt: row.updated_at });

function validate(input: unknown): { title: string; body: string } | string {
  const { title, body } = (input ?? {}) as { title?: unknown; body?: unknown };
  if (typeof title !== 'string' || typeof body !== 'string') return 'Title and content are required';
  const t = title.trim();
  const b = body.trim();
  if (t.length === 0 || b.length === 0) return 'Title and content must not be empty';
  if (t.length > TITLE_MAX) return `Title must be at most ${TITLE_MAX} characters`;
  if (b.length > BODY_MAX) return `Content must be at most ${BODY_MAX} characters`;
  return { title: t, body: b };
}

/** Maps database errors to client responses: invalid UUID = 404, everything else = 503. */
function dbError(reply: FastifyReply, err: unknown) {
  if ((err as { code?: string }).code === '22P02') return reply.code(404).send({ error: 'Not found' });
  reply.log.error(err);
  return reply.code(503).send({ error: 'Database unavailable' });
}

export async function textRoutes(app: FastifyInstance): Promise<void> {
  app.get('/texts', async (_request, reply) => {
    try {
      const { rows } = await pool.query<TextRow>(
        'SELECT id, title, updated_at FROM texts ORDER BY updated_at DESC',
      );
      return rows.map((r) => ({ id: r.id, title: r.title, updatedAt: r.updated_at }));
    } catch (err) {
      return dbError(reply, err);
    }
  });

  app.get<{ Params: IdParams }>('/texts/:id', async (request, reply) => {
    try {
      const { rows } = await pool.query<TextRow>('SELECT * FROM texts WHERE id = $1', [request.params.id]);
      if (rows.length === 0) return reply.code(404).send({ error: 'Not found' });
      return toText(rows[0]);
    } catch (err) {
      return dbError(reply, err);
    }
  });

  app.post('/texts', { preHandler: requireEditor }, async (request, reply) => {
    const input = validate(request.body);
    if (typeof input === 'string') return reply.code(400).send({ error: input });
    try {
      const { rows } = await pool.query<TextRow>(
        'INSERT INTO texts (title, body) VALUES ($1, $2) RETURNING *',
        [input.title, input.body],
      );
      return reply.code(201).send(toText(rows[0]));
    } catch (err) {
      return dbError(reply, err);
    }
  });

  app.put<{ Params: IdParams }>('/texts/:id', { preHandler: requireEditor }, async (request, reply) => {
    const input = validate(request.body);
    if (typeof input === 'string') return reply.code(400).send({ error: input });
    try {
      // Last write wins (no optimistic locking, see spec edge cases)
      const { rows } = await pool.query<TextRow>(
        'UPDATE texts SET title = $1, body = $2, updated_at = now() WHERE id = $3 RETURNING *',
        [input.title, input.body, request.params.id],
      );
      if (rows.length === 0) return reply.code(404).send({ error: 'Not found' });
      return toText(rows[0]);
    } catch (err) {
      return dbError(reply, err);
    }
  });

  app.delete<{ Params: IdParams }>('/texts/:id', { preHandler: requireEditor }, async (request, reply) => {
    try {
      const { rowCount } = await pool.query('DELETE FROM texts WHERE id = $1', [request.params.id]);
      if (rowCount === 0) return reply.code(404).send({ error: 'Not found' });
      return reply.code(204).send();
    } catch (err) {
      return dbError(reply, err);
    }
  });
}
