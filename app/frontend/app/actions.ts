'use server';

import { redirect } from 'next/navigation';
import { getEditorSession, signIn, signOut } from '@/auth';
import { BackendError, createText, deleteText, updateText } from '@/lib/backend';

export async function login() {
  await signIn('keycloak');
}

export async function logout() {
  await signOut({ redirectTo: '/' });
}

const withError = (path: string, message: string) => `${path}?error=${encodeURIComponent(message)}`;

/** Returns the access token or redirects back with a message. The backend checks the role again. */
async function requireToken(back: string): Promise<string> {
  const { session, isEditor } = await getEditorSession();
  if (!session) redirect(withError(back, 'Please log in.'));
  if (session.expired || !session.accessToken) {
    redirect(withError(back, 'Your session has expired. Please log in again.'));
  }
  if (!isEditor) redirect(withError(back, 'Editor role required.'));
  return session.accessToken;
}

function messageFor(err: unknown): string {
  if (err instanceof BackendError) {
    if (err.status === 401) return 'Your session has expired. Please log in again.';
    if (err.status === 403) return 'Editor role required.';
    return err.message;
  }
  return 'Something went wrong.';
}

export async function saveText(formData: FormData) {
  const id = String(formData.get('id') ?? '');
  const input = { title: String(formData.get('title') ?? ''), body: String(formData.get('body') ?? '') };
  const back = id ? `/texts/${id}/edit` : '/texts/new';
  const token = await requireToken(back);

  let target: string;
  try {
    const text = id ? await updateText(id, input, token) : await createText(input, token);
    target = `/texts/${text.id}`;
  } catch (err) {
    target = withError(back, messageFor(err));
  }
  redirect(target); // outside try/catch: redirect() works by throwing
}

export async function removeText(formData: FormData) {
  const id = String(formData.get('id') ?? '');
  const token = await requireToken(`/texts/${id}`);

  let target = '/';
  try {
    await deleteText(id, token);
  } catch (err) {
    target = withError(`/texts/${id}`, messageFor(err));
  }
  redirect(target);
}
