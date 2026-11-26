import Link from 'next/link';
import { saveText } from '../actions';

// Limits from specs/001-azure/data-model.md (Text.title, Text.body); the backend enforces them again.
export function TextForm({
  text,
  error,
}: {
  text?: { id: string; title: string; body: string };
  error?: string;
}) {
  return (
    <form action={saveText}>
      {error && <p className="error">{error}</p>}
      {text && <input type="hidden" name="id" value={text.id} />}
      <label htmlFor="title">Title</label>
      <input id="title" name="title" required maxLength={200} defaultValue={text?.title} />
      <label htmlFor="body">Content</label>
      <textarea id="body" name="body" required maxLength={100000} defaultValue={text?.body} />
      <div className="actions">
        <button type="submit">Save</button>
        <Link href={text ? `/texts/${text.id}` : '/'}>Cancel</Link>
      </div>
    </form>
  );
}

export function NotEditor() {
  return (
    <p className="error">
      Editing requires the editor role. <Link href="/">Back to all texts</Link>
    </p>
  );
}
