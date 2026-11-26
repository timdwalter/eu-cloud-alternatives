import { getEditorSession } from '@/auth';
import { NotEditor, TextForm } from '../text-form';

export const dynamic = 'force-dynamic';

export default async function NewTextPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const [{ error }, { isEditor }] = await Promise.all([searchParams, getEditorSession()]);
  return (
    <>
      <h1>New text</h1>
      {isEditor ? <TextForm error={error} /> : <NotEditor />}
    </>
  );
}
