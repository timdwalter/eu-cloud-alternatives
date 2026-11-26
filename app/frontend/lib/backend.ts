// Server-side client for the internal backend (never called from the browser, see research.md R2).
const BACKEND_URL = process.env.BACKEND_URL ?? 'http://localhost:8080';

export type TextSummary = { id: string; title: string; updatedAt: string };
export type Text = TextSummary & { body: string };

export class BackendError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
  }
}

async function call<T>(path: string, init: RequestInit = {}, token?: string): Promise<T> {
  let res: Response;
  try {
    res = await fetch(`${BACKEND_URL}${path}`, {
      ...init,
      cache: 'no-store',
      headers: {
        ...(init.body ? { 'content-type': 'application/json' } : {}),
        ...(token ? { authorization: `Bearer ${token}` } : {}),
      },
    });
  } catch {
    throw new BackendError(503, 'The service is temporarily unavailable.');
  }
  if (res.status === 204) return undefined as T;
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new BackendError(res.status, (data as { error?: string }).error ?? 'Request failed');
  return data as T;
}

export const listTexts = () => call<TextSummary[]>('/texts');
export const getText = (id: string) => call<Text>(`/texts/${encodeURIComponent(id)}`);

export const createText = (input: { title: string; body: string }, token: string) =>
  call<Text>('/texts', { method: 'POST', body: JSON.stringify(input) }, token);

export const updateText = (id: string, input: { title: string; body: string }, token: string) =>
  call<Text>(`/texts/${encodeURIComponent(id)}`, { method: 'PUT', body: JSON.stringify(input) }, token);

export const deleteText = (id: string, token: string) =>
  call<void>(`/texts/${encodeURIComponent(id)}`, { method: 'DELETE' }, token);
