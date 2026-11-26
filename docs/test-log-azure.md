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

## Step 3 – Local tools for Azure (2026-11-26)

**What:** Installed az 2.93.0, Terraform 1.17.2, kubectl 1.37.3, Helm 4.3.2, gh 2.105.0 via winget;
re-checked the prices that had been rate-limited.
**How:** CLI (winget). No Azure login yet.

**Surprises / problems**
- Terraform and Helm (portable zip packages) failed with "a portable package from a different source
  already exists" although neither was installed. `winget install --force` fixed it.
- Docker Desktop ships its own kubectl (1.36.1), which comes first in PATH and shadows the winget one.
  Fine as long as the AKS version is within ±1 minor of it – to check after login.
- Agent knowledge was outdated again: planned Terraform 1.14 and Helm 3; current are 1.17 and 4.
- Final cost estimate with API prices: ≈ 112 €/month ≈ 3.70 €/day (Load Balancer 16.35 €,
  ACR Basic 4.55 €, PostgreSQL storage 3.94 €).

**Time:** ~15 min.

## Step 4 – Azure login and read-only checks (2026-11-26)

**What:** `az login`, checked subscription, role, existing resources, resource providers, quota, AKS versions.
**How:** CLI (read-only), except the provider registration (with the user's OK).

**Findings**
- Login needed a second attempt with `--tenant <id>`: the tenant enforces MFA, and the first login
  ended with "No subscriptions found" (AADSTS50076).
- Bash in the agent session did not find `az` after the winget install (PATH of the already running
  IDE); PowerShell with a refreshed PATH worked.
- User is **Owner** on the subscription. 6 leftover resource groups, all empty (0 resources, no cost).
  No budget configured yet.
- **Not obvious:** `Microsoft.ContainerService`, `Microsoft.ContainerRegistry` and `Microsoft.KeyVault`
  were not registered. Registered via `az provider register` (~1–2 min, free).
- **Not obvious:** vCPU quota in germanywestcentral is 10 in total, but **0 for the Basv2 family** that the
  plan used (`B2als_v2`). The older BS family has 10. Switched to `Standard_B2s` (2 vCPU, 4 GiB,
  0.0431 €/h) instead of requesting a quota increase. The plan would have failed at `terraform apply`.
- AKS versions available: 1.31–1.37 (1.31–1.33 only as paid LTS). Chosen: 1.36.5.

**Cost estimate now:** ≈ 118 €/month ≈ 3.90 €/day.

**Time:** ~20 min.
## Step 5 – Terraform code, validate and plan (2026-11-26)

**What:** Root module + `modules/azure` (network, AKS, PostgreSQL, ACR, Key Vault, CI identity), `terraform plan`.
**How:** Terraform 1.17.2, azurerm 5.13.0 (chosen over the 2-day-old 5.15.0), random 3.9.1, time 0.14.2.
Plan: **22 resources to add**, nothing applied yet.

**Where the agent was wrong / unsure**
- Wrote the code from azurerm 4.x knowledge; the current major is 5. `terraform validate` failed on 5 errors:
  - `azurerm_kubernetes_cluster` now **requires** a `node_provisioning_profile` block → `mode = "Manual"`
    (value guessed from the schema, the schema has no description; to be confirmed by apply).
  - `azurerm_federated_identity_credential`: `parent_id` → `user_assigned_identity_id`.
  - `azurerm_private_dns_zone_virtual_network_link`: `resource_group_name` + `private_dns_zone_name`
    → `private_dns_zone_id`.
  Fixed by reading `terraform providers schema -json` instead of guessing.
- Unsure whether the AKS system-assigned identity needs *Network Contributor* on the BYO subnet when
  created via Terraform (az CLI assigns it automatically). Added the assignment to be safe.
- Added a 60 s `time_sleep` before writing the Key Vault secret: RBAC propagation delay is a known cause
  of 403 errors right after the role assignment.

**Not obvious**
- The person running Terraform needs *Key Vault Secrets Officer* on the vault – Owner on the subscription
  does not grant access to secret values with RBAC-mode vaults.
- azurerm 4+ requires `subscription_id` in the provider block; `resource_provider_registrations = "none"`
  stops the provider from trying to register dozens of providers itself.

**Time:** ~25 min.
## Step 6 – First apply, region restriction, move to westeurope (2026-11-26)

**What:** `terraform apply` (with the user's OK) → 19 of 22 resources created in germanywestcentral, then
failure on PostgreSQL. Destroyed and re-applied in westeurope (user's decision).
**How:** Terraform. Images were built locally and pushed to the first ACR in parallel (lost with the destroy,
pushed again afterwards).

**What went right**
- AKS with `node_provisioning_profile { mode = "Manual" }` was accepted (created in 4 min 11 s) – the
  guessed value from Step 5 is correct.
- Key Vault secret write after the 60 s RBAC wait worked on the first try.

**What went wrong – the most important finding of the Azure test so far**
- PostgreSQL failed with `ParameterOutOfRange: The value of the 'Version' should be in: []`.
  The message is misleading (looks like a wrong version). The real reason, found only with
  `az postgres flexible-server list-skus --location germanywestcentral`:
  **"Provisioning is restricted in this region. Please choose a different region."**
  (`OfferRestricted`). Germany West Central does not offer PostgreSQL Flexible Server to this
  (pay-as-you-go) subscription at all – the "German region" story breaks at the managed database.
- None of the agent's pre-checks covered this: VM quota and provider registration were fine, but service
  availability per subscription and region is a separate dimension. A support request could lift it,
  but that takes days.
- Checked 11 EU regions: only germanywestcentral is restricted (germanynorth has no B1ms/v17 at all).
- Agent mistake: the first plan for the region change replaced the resource group but not the subnets
  and the private DNS zone inside it. Deleting the resource group would have removed them in Azure
  while Terraform still believed they existed. Did a full `terraform destroy` + `apply` instead.

**Time:** ~45 min incl. destroy/re-apply. Cost so far: a few cents (AKS ran ~10 min, no DB).
## Step 7 – Second apply failed, full teardown for the night (2026-11-26)

**What:** The re-apply in westeurope started automatically after the destroy (the agent's attempt to stop
it by renaming `terraform.tfvars` came too late). It failed after 11 min with three
"Provider produced inconsistent result after apply" errors and a Key Vault `ResourceNotFound` – typical
Azure eventual-consistency problems right after creating a fresh resource group. The domain was not
active at Strato yet, so the user decided to tear everything down overnight.
**How:** `terraform destroy` – failed once on a federated identity credential that Azure had already
removed (404 `ParentResourceNotFound`); fixed with `terraform state rm` and a second destroy.

**Verified afterwards (az CLI):** 0 resources tagged `project=textlib`, Terraform state empty.
Left over, both free:
- `NetworkWatcherRG` with `NetworkWatcher_germanywestcentral` / `_westeurope` – Azure creates these
  automatically when the first VNet in a region is created. Not managed by Terraform.
- Soft-deleted Key Vault `textlib-kv-…` from the failed apply – purged automatically after 7 days.

**Agent mistakes**
- Chaining destroy and apply in one background job made it impossible to stop cleanly; the "rename
  tfvars" trick raced with the job. Lesson: run destroy and apply as separate, explicit steps.

**Time:** ~25 min. Cost: AKS ran ~15 min in total, no DB – a few cents (to be confirmed in Cost Management).
## Step 8 – Azure up and running (2026-11-27)

**What:** Fresh `terraform apply` in westeurope, image push, `scripts/deploy.sh azure`, DNS at Strato,
Let's Encrypt staging → prod, end-to-end check.
**How:** Terraform (22 resources, **9 min**, no errors this time), CLI (docker push, deploy script),
manual (Strato DNS).

**Results**
- App on `https://<domain>` and Keycloak on `https://auth.<domain>` with trusted Let's Encrypt
  certificates; HTTP → HTTPS redirect (301).
- Backend and Keycloak reach the **private** PostgreSQL over TLS (with certificate verification in the
  backend).
- Scripted login as editor (Auth.js → Keycloak → callback) works on Azure exactly as locally; session has
  role `editor`, UI shows the edit controls.
- `deploy.sh` run a second time: 52 s, no changes needed → idempotent.

**Where the agent was wrong**
- Bash scripts called Windows `terraform.exe` with a Git-Bash path (`/c/Users/...`) because
  `MSYS_NO_PATHCONV=1` disables path conversion. Fixed with `pwd -W`. The failure was also swallowed by
  `eval "$(...)"`; now a separate assignment stops the script.
- Pods failed with `CreateContainerConfigError`: `runAsNonRoot` cannot verify the non-numeric image user
  `node`. Docker Compose never checks this, so the local test could not catch it. Fixed in the chart with
  `runAsUser: 1000`; running deployments were patched to let the waiting `helm --wait` finish.

**Surprises / not obvious**
- **AKS "admissionsenforcer"** rewrites the `namespaceSelector` of cert-manager's webhook. Helm 4 uses
  server-side apply and fails the *second* `helm upgrade` with a field-manager conflict. Fixed with
  `--force-conflicts`, set only in `scripts/providers/azure.sh` (AKS-specific).
- Strato: a new subdomain gets Strato's parking A **and** AAAA records by default; the apex settings are not
  inherited. The subdomain had to be created and configured separately. Let's Encrypt prefers IPv6, so a
  leftover AAAA record would have broken certificate issuance.
- While the HTTP-01 challenge routes exist, Envoy Gateway prefers them (hostname-specific) over the
  hostname-less redirect route, so `http://<domain>/` returned 404 until the certificate was issued.
  Harmless, but confusing.
- Let's Encrypt staging certificates are (by design) untrusted – Firefox shows `SEC_ERROR_UNKNOWN_ISSUER`.

**Time:** ~1 h 15 min (most of it waiting for DNS at Strato).
## Step 9 – Repository restructure (2026-11-27)

**What:** At the user's request: `terraform/` → `infrastructure/terraform/`, `platform/` →
`infrastructure/platform/`, `scripts/` → `infrastructure/scripts/`, `app/*` → `apps/*`,
`local/` → `apps/local-infra/`. Done with `git mv` (history kept); local state, tfvars and .env files moved
with their folders. All paths in scripts, compose file, workflow and docs updated; earlier test-log entries
keep the old paths.
**Checks:** `terraform validate`/`plan` from the new location (state found, only the pending OIDC subject
change), `docker compose config`, `helm lint`, `bash -n` on all scripts, script path resolution.