import Link from 'next/link';
import { notFound } from 'next/navigation';
import { getEditorSession } from '@/auth';
import { BackendError, getText } from '@/lib/backend';
import { removeText } from '../../actions';

export const dynamic = 'force-dynamic';

async function loadText(id: string) {
  try {
    return await getText(id);
  } catch (err) {
    if (err instanceof BackendError && err.status === 404) notFound();
    throw err;
  }
}

export default async function TextPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ error?: string }>;
}) {
  const [{ id }, { error }] = await Promise.all([params, searchParams]);
  const [text, { isEditor }] = await Promise.all([loadText(id), getEditorSession()]);

  return (
    <article>
      {error && <p className="error">{error}</p>}
      <p>
        <Link href="/">← All texts</Link>
      </p>
      <h1>{text.title}</h1>
      <p className="muted">Updated {new Date(text.updatedAt).toLocaleString('en-GB')}</p>
      <div className="body">{text.body}</div>
      {isEditor && (
        <div className="actions">
          <Link href={`/texts/${text.id}/edit`}>Edit</Link>
          <form action={removeText}>
            <input type="hidden" name="id" value={text.id} />
            <button type="submit" className="danger">
              Delete
            </button>
          </form>
        </div>
      )}
    </article>
  );
}
