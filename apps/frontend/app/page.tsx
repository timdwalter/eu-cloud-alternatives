import Link from 'next/link';
import { getEditorSession } from '@/auth';
import { listTexts, type TextSummary } from '@/lib/backend';

export const dynamic = 'force-dynamic';

export default async function HomePage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const [{ error }, { isEditor }] = await Promise.all([searchParams, getEditorSession()]);

  let texts: TextSummary[];
  try {
    texts = await listTexts();
  } catch {
    // Rendered on the server, so the message is visible even without JavaScript.
    return (
      <>
        <h1>Temporarily unavailable</h1>
        <p className="muted">The texts cannot be loaded right now. Please try again in a moment.</p>
      </>
    );
  }

  return (
    <>
      {error && <p className="error">{error}</p>}
      <div className="actions">
        <h1 style={{ margin: 0 }}>Texts</h1>
        {isEditor && <Link href="/texts/new">New text</Link>}
      </div>
      {texts.length === 0 ? (
        <p className="muted">No texts yet.</p>
      ) : (
        <ul className="texts">
          {texts.map((t) => (
            <li key={t.id}>
              <Link href={`/texts/${t.id}`}>{t.title}</Link>
              <div className="muted">Updated {new Date(t.updatedAt).toLocaleDateString('en-GB')}</div>
            </li>
          ))}
        </ul>
      )}
    </>
  );
}
