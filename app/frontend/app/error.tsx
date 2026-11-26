'use client';

// Friendly error page, e.g. when the backend or the database is down. No technical details.
export default function ErrorPage({ reset }: { error: Error; reset: () => void }) {
  return (
    <>
      <h1>Temporarily unavailable</h1>
      <p className="muted">The texts cannot be loaded right now. Please try again in a moment.</p>
      <button type="button" onClick={() => reset()}>
        Try again
      </button>
    </>
  );
}
