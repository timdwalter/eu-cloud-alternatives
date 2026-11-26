import type { ReactNode } from 'react';
import Link from 'next/link';
import { auth } from '@/auth';
import { login, logout } from './actions';
import './globals.css';

// Everything is rendered per request (data comes from the backend at runtime, not at build time).
export const dynamic = 'force-dynamic';

const appName = () => process.env.APP_NAME || 'Text Library';

export async function generateMetadata() {
  return { title: appName() };
}

export default async function RootLayout({ children }: { children: ReactNode }) {
  const session = await auth();
  return (
    <html lang="en">
      <body>
        <header>
          <Link href="/" className="brand">
            {appName()}
          </Link>
          {session ? (
            <form action={logout}>
              <span className="user">{session.user?.name}</span>
              <button type="submit">Log out</button>
            </form>
          ) : (
            <form action={login}>
              <button type="submit">Log in</button>
            </form>
          )}
        </header>
        <main>{children}</main>
      </body>
    </html>
  );
}
