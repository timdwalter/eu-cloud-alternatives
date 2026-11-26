import { notFound } from 'next/navigation';
import { getEditorSession } from '@/auth';
import { BackendError, getText } from '@/lib/backend';
import { NotEditor, TextForm } from '../../text-form';

export const dynamic = 'force-dynamic';

export default async function EditTextPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ error?: string }>;
}) {
  const [{ id }, { error }, { isEditor }] = await Promise.all([params, searchParams, getEditorSession()]);
  if (!isEditor) return <NotEditor />;

  let text;
  try {
    text = await getText(id);
  } catch (err) {
    if (err instanceof BackendError && err.status === 404) notFound();
    throw err;
  }

  return (
    <>
      <h1>Edit text</h1>
      <TextForm text={text} error={error} />
    </>
  );
}
