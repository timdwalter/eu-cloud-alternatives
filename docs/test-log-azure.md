# Test log – Azure

## Step 0 – Project setup (2026-11-26)

**What:** Initialised GitHub Spec Kit for Claude Code and clarified the scope in a "grill-me" interview (results in [decisions.md](decisions.md)).
**How:** CLI (local machine, Windows 11).

**Prerequisites that were not obvious**
- Spec Kit needs `uv`. Installed with `winget install astral-sh.uv`; the shell PATH had to be reloaded before `uvx` was found.
- Local machine had only Node.js. Still missing: az, terraform, kubectl, helm, gh, docker.

**Where the agent was unsure / wrong**
- Used the flag `--ai claude` from older Spec Kit docs; the current CLI uses `--integration claude`. Fixed after reading `specify init --help`.
- Spec Kit's agent check did not find the `claude` binary on PATH; worked around with `--ignore-agent-tools`.

**Scope changes during the interview (noteworthy for the article)**
- Started from a fairly complete enterprise stack (Argo CD, Key Vault + External Secrets, external-dns, remote state, two node pools, monitoring). Cut down deliberately to an "ultra minimal" stack; see the "Dropped on purpose" list in decisions.md.

**Cost research**
- Prices taken from the public Azure Retail Prices API (EUR, germanywestcentral). The API rate-limited
  after a few queries ("Too many requests"); Load Balancer, ACR and PostgreSQL storage are estimates
  until re-checked.
- Surprise: the AKS default OS disk (128 GB Premium, P10) costs ~19 €/node/month – more than a
  `B2als_v2` node's half. Plan sets 32 GB (P4, ~5 €).
- Estimate: ≈ 114 €/month ≈ 3.75 €/day.

**Design change during planning**
- Backend made internal-only (called by the Next.js server) instead of a gateway path split – one public
  route less.

**Time:** ~1.5 h (mostly the scope discussion and planning).

## Step 1 – App code, local stack (2026-11-26)

**What:** Backend (Fastify, 7 endpoints, JWT check), frontend (Next.js 16 + Auth.js v5), Docker Compose
with PostgreSQL and Keycloak, realm import, user script.
**How:** Code only. Docker Desktop was still being installed, so the stack has **not run yet**.

**Checks done without Docker**
- Backend: `tsc --noEmit` clean; started without a database → `/healthz` 200, `/readyz` 503,
  `/texts` 503, `POST /texts` without token 401 (as specified).
- Frontend: `next build` clean, all routes dynamic.

**Where the agent was wrong / unsure**
- Planned Node.js 24 LTS. Wrong for November 2026: Node 26 has been the active LTS since October 2026.
  Switched to `node:26.13.1-alpine` (found when looking up current image tags).
- `npm view typescript` returned 7.0 (the new native compiler). Pinned 5.9.3 to avoid compatibility
  surprises with Next.js – not verified whether 7 would work.
- Auth.js v5 is still published as beta (`5.0.0-beta.32`); used anyway and pinned.
- Unverified: the Keycloak login is built without OIDC discovery (plain OAuth flow, roles read from the
  access token) to avoid the browser-vs-container URL mismatch (research R3). This is the most likely
  place to break once Docker runs.
- First type check failed on Fastify's error handler typing (`err` is `unknown`); fixed with an explicit type.

**Simplification**
- The backend needs no build step: Node 26 runs TypeScript files directly (type stripping), so the
  backend image is a single stage.

## Step 2 – Local validation with Docker Compose (2026-11-26)

**What:** Started the full stack locally (`docker compose up --build`), created test users, checked US1/US2.
**How:** CLI. Docker Desktop 29.9.3 (needed a Windows restart after installation). `local/.env` generated
with random values by the agent (gitignored).

**Results**
- US1: list shows exactly the lorem ipsum seed text, no edit controls without login. ✔
- Login (scripted browser flow: Auth.js → Keycloak → callback → session): editor gets role `editor` and
  sees "New text"; reader without role does not. The discovery-free login from Step 1 worked on the
  first try – the browser/container URL problem (research R3) is solved. ✔
- Backend with real tokens: reader POST/DELETE → 403, editor POST/PUT/DELETE → 201/200/204, empty
  title → 400, 100,000-character body saved, anonymous/fake token → 401, unknown id → 404. ✔
- Backend port is not published on the host. ✔
- Database stopped → friendly "Temporarily unavailable" page, no stack trace; database started again →
  app recovers without restart. ✔

**Where the agent was wrong**
- `APP_NAME=Text Library` without quotes in `.env.example` broke `source .env` in the Bash user script.
  Fixed by quoting.
- First DB-outage test returned an HTML page with only the header: Next.js renders `error.tsx` only in
  the browser. Changed the list page to catch the error on the server so the message is in the HTML.
- A test call sent `content-type: application/json` on DELETE without a body; Fastify rejects that with 400
  before the auth check. Test mistake, not an app bug (the frontend only sets the header with a body).
- The Chrome extension for browser automation was not connected, so the UI forms (server actions) were
  not clicked by the agent – left to a manual check.

**Time:** ~30 min (plus Docker installation and restart).
