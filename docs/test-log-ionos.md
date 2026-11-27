# Test log – IONOS

Same stack and rules as the [Azure reference](test-log-azure.md). Honest record, including the agent's
own mistakes. Times are the user's wall-clock time.

## Step 0 – Account and tools (2026-11-27)

**What:** Check access, install the CLI.
**How:** Customer portal, GitHub release.

**Result:**
- The user already has an IONOS customer account (`mein.ionos.de`, hosting/domains). Its start page
  shows Black Friday advertising for the website builder first.
- **IONOS Cloud is a separate portal** (Data Center Designer) with **its own login**. The customer
  account does not lead directly to Managed Kubernetes. Two portals, two logins for one provider.
- **CLI `ionosctl`:** no winget, no Chocolatey package (checked); the docs mention Scoop, otherwise a
  ZIP from GitHub. Installed v6.10.5 from the official `ionos-cloud/ionosctl` release, SHA-256 checked
  against the release checksum file, unpacked, added to the user PATH. Same stumbling block as STACKIT.
- **The customer-account login does not work for the Data Center Designer.** IONOS Cloud needs its own
  registration/contract, even for an existing IONOS customer.
- **IONOS Cloud registration:** done by the user; no company fields so far (unlike STACKIT). Starts as a
  **test account**. The **€ 200 starting credit** is only granted after unlocking the "full version" of
  the virtual data center.
- **CLI login:** username + password prompt in the terminal or an API token (`--token`); **no browser
  login** (Scaleway: API key; Azure: browser login via `az login`). Typing a password into a terminal
  prompt is uncomfortable for the user.
- **Unlocking the full version** asks for company/organisation and address. To be checked whether a
  private person can complete it.
- Unlocking: a private address was accepted (no company needed so far). **Credit card form does not
  support browser autofill** – card details have to be typed by hand. Small, but annoying.
- Address and credit card submitted. **The full version is reviewed manually – "up to 24 h".** Until then
  only the test account. Second provider in a row (after Scaleway) where onboarding blocks the start.
- **Token Manager is only available in the full version.** No API token, so no CLI/Terraform access
  during the review either – nothing can even be checked read-only.

## Step 1 – Research and plan (2026-11-27, no account access)

**What:** Map the building blocks to IONOS from the docs and the price list, while the contract is under review.
**How:** IONOS docs and German price list (version 2026-10-29), GitHub releases.

**Result (to be confirmed after the unlock):**
- **No cloud load balancer** for `Service type=LoadBalancer`: IONOS attaches a public IP to one worker
  node. Simpler and cheaper, but a single ingress node.
- **DB certificate from Let's Encrypt** – the unchanged app should verify it (unlike Scaleway's own CA).
- **No native secret store**, **no OIDC for CI**, **no keyless image pull** – three gaps vs. Azure.
- **Cost Alert** exists (notification only, no cap).
- The price list says it applies to **business customers** – although a private address was accepted.
- Expected ≈ 131–141 €/month net, mainly the database (54 €: DBaaS cores cost 0.06 €/h). Most expensive
  of the three so far; the € 200 credit covers the test easily.

## Step 2 – Contract unlocked (2026-11-28)

- The full version was unlocked within the announced 24 h (the user checked the next day; exact time
  unknown).
- **First impression of the DCD (user):** a **much smaller service portfolio** than Azure (and smaller
  than Scaleway): four database types, for containers only Managed Kubernetes and the Container Registry,
  plus Kafka. Everything our stack needs is there, but there is little beyond it.
- Cost Alert set by the user in the DCD (before any resource exists).
- **No browser login for the CLI** – `ionosctl` accepts username + password or a token. Creating a
  least-privilege identity therefore means: group with privileges + separate user (needs its own e-mail
  address) + token created while logged in as that user. Done in the DCD (a CLI route would need an owner
  token first). Group privileges: create data center, create Kubernetes cluster, manage DBaaS, manage
  registry, reserve IP, create internet access.
- DCD: creating a group was not obvious – the user dialog "add to group" offers no way to create one; the group list is elsewhere.
- User created group `textlib-terraform` and a non-admin user (own e-mail alias) in the DCD, then a token
  for that user with **TTL 4 h** (TTL can be as short as 1 h – good). CLI login with the token.
- The group had **no privileges ticked** yet. The agent's attempt to set them via CLI was correctly
  rejected (403): the token belongs to the non-admin user, which must not change groups – least
  privilege works. Privileges have to be set by the owner in the DCD.

## Step 3 – Read-only checks before the first apply (2026-11-28)

**What:** Lesson from Scaleway – check limits and availability before creating anything.
**How:** `ionosctl` with the Terraform user's token.

**Result:**
- **Contract limits** (`contract get`): 48 cores, 96 GB RAM, 5 Kubernetes clusters, 5 reservable IPs,
  2 TB SSD – far above our needs (≈ 5 cores, 12 GB, 1 cluster, 1–3 IPs). Clearly visible and readable by
  the CLI, unlike on Scaleway.
- **Kubernetes versions:** 1.32.4 … **1.36.6** (default 1.35.10) – same patch as Scaleway.
- **de/fra:** vCPU instances, Kubernetes and private Kubernetes clusters offered; CPU families Intel
  Skylake/Ice Lake (+ AMD EPYC/Turin features listed). Container Registry only in **de/fra**.
- **DBaaS PostgreSQL:** minimum **1 core and 4 GB RAM** (not 2 GB as assumed in the plan), 10 GB–2 TB,
  storage HDD / SSD_STANDARD / SSD_PREMIUM. `ionosctl dbaas postgres version list` fails with
  **410 Gone – "This API has been decommissioned"**: the current CLI still calls an old API version.
- Group privileges verified: the six needed + "access and manage logging" (ticked by mistake, not needed).
- **Cost estimate corrected:** DB 1 core + 4 GB = (0.06 + 4 × 0.007) × 730 ≈ **64 €/month** (not 54 €);
  total ≈ **140 € net (≈ 150 € with node IPs)**, ≈ 4.60–4.95 €/day net.

## Step 4 – Code and plan (2026-11-28)

**What:** `modules/ionos`, root switch, `providers/ionos.sh`, `values/ionos.yaml`, `deploy.sh` hook,
workflow login step.
**How:** provider schema read with `terraform providers schema -json` **before** writing the module
(lesson from azurerm 5); backup locations and PostgreSQL versions read with a read-only probe.

**Result:**
- `terraform validate`: valid at the first attempt, **0 schema errors**. `plan`: **10 to add**
  (datacenter, LAN, Kubernetes cluster, node pool, PostgreSQL, registry, 2 registry tokens, 2 random values).
- **Two PostgreSQL resources in the provider:** `pg_cluster` (v1 API – the CLI already gets *410 Gone*
  for it) and `pg_cluster_v2`. v2 creates **only one initial database**; the extra-database resource
  (`pg_database`) belongs to v1. Workaround: `providers/ionos.sh` creates the `keycloak` database with a
  one-off `psql` pod before the chart is installed – with `sslmode=verify-full` against the system CAs,
  which also proves the Let's Encrypt DB certificate is trusted.
- **No secret store:** `get_secret db-password` reads `terraform output db_password` from the local state.
- **No reserved IP:** the plan said to pre-reserve one; left out to stay minimal – IONOS reserves the
  `LoadBalancer` IP itself (same as Azure/Scaleway, where the LB IP is automatic too).
- Pipeline: automatic runs only on `main`; on this branch it is started by hand – so pushes that touch the
  workflow file do not trigger failing runs (lesson from Scaleway).
- Root module: as on Scaleway, `versions.tf`, `variables.tf`, `main.tf`, `outputs.tf` (4 extra outputs,
  because the state replaces a secret store) and `tfvars.example` change.
- **Decision (user):** no managed secret store on IONOS is **accepted and documented as missing**
  (equivalence rule 1). Exposure is the same as on Azure (the DB password was in the local state there
  too); what is missing is a managed store with access logging and rotation. Self-hosting OpenBao was
  rejected as not minimal.

## Step 5 – Apply (2026-11-28, 13:54–14:01)

- **8 of 10 resources in 5 min 37 s:** datacenter 6 s, LAN 17 s, registry 49 s, **Kubernetes cluster
  1 min 1 s**, node pool 3 min 36 s, **PostgreSQL 5 min 14 s** (the docs mention up to an hour).
- **Both registry tokens failed:** the provider expects the expiry date as `YYYY-MM-DD hh:mm:ssZ`
  (space instead of the ISO 8601 `T`) and rejects `timeadd()` output with a Go time-parse error
  (`cannot parse "T12:41:56Z" as " "`). Nothing half-created at IONOS. Fixed with `formatdate()`; second
  apply: 2 tokens in 2–3 s. Agent mistake (format not checked) + provider quirk (undocumented format,
  unhelpful error).
- DB host is a DNS name under `postgresql.de-fra.ionoscloud.com`; registry `…cr.de-fra.ionos.com`.
- First `deploy.sh ionos` stopped at the kubeconfig merge: `kubectl.exe` on Windows needs `;` and Windows paths in `KUBECONFIG` (agent mistake, Git Bash vs. Windows binaries again). Fixed with `cygpath`; kubeconfig backed up first. 2 nodes `Ready`, 1.36.6.

## Step 6 – Deploy (2026-11-28, 14:03–14:07)

- `deploy.sh ionos`: **3 min 49 s**, Helm release `deployed` at the first attempt.
- `provider_pre_deploy`: pull secret created; `CREATE DATABASE keycloak` over **`sslmode=verify-full`**
  (system CAs) – the DB's Let's Encrypt certificate is trusted. (`kubectl run` could not attach and fell
  back to streaming logs – cosmetic.)
- **Backend unchanged from `main` (`DB_SSL=true`, certificate verified): `database schema ready`.** No app
  or chart change needed – unlike Scaleway.
- IONOS installs its own components as Helm releases into the cluster (`calico`, `coredns`,
  `csi-ionoscloud`, `ionos-policy-validator`, `kube-proxy`) – visible with `helm list -A`.
- `Service type=LoadBalancer` got a public IP without any annotation (attached to one node).
- DNS moved by the user; resolved to the new IP publicly **and inside the cluster** at once (no cache issue
  as on Scaleway). Staging certificates in ~3 min, switch to `letsencrypt-prod` (revision 2): both
  production certificates issued.

## Step 7 – Acceptance checks (2026-11-28)

- `https://<domain>` and `https://auth.<domain>`: 200, Let's Encrypt production certificates.
- Anonymous visitor sees the seed text. Backend not reachable from the internet.
- Inside the cluster `POST /texts` without token and with a forged token: **401**.
- **DB exposure:** the public DNS name of the database resolves to the **private** address `10.20.0.5`
  only – no public endpoint.
- Editor login, create, edit and delete in the browser: **all work** (user). **US1 and US2 passed.**
- **Idempotent re-deploy:** `deploy.sh ionos` again: 65 s, Helm revision 3, same IP, no pod restarted,
  `pg-init` reports "database keycloak exists"; `terraform plan`: no changes.

## Step 8 – Pipeline (2026-11-28)

- CI registry token (scopes pull + push, no delete, 7-day expiry, created by Terraform) stored as the
  GitHub secret `IONOS_REGISTRY_PASSWORD` straight from `terraform output` (value not printed); variables
  `REGISTRY`, `REGISTRY_USERNAME` set.
- Manual run on `003-ionos`: **success at the first attempt**, both images pushed (tag `afb3ea8`).
  **US4 passed.** Like Scaleway: no OIDC, a stored credential – but scoped to the registry, push without
  delete, and with a built-in expiry date (better than Scaleway's `ContainerRegistryFullAccess`).
- **Time (user's estimate):** ~2 h active work, plus the up-to-24-hour contract review.

## Summary (before teardown)

- **Result:** all acceptance checks passed (US1–US4), idempotent re-deploy, pipeline green. App and chart
  **unchanged** from `main`.
- **Changed outside the provider module:** root Terraform files, `deploy.sh` hook, workflow login step,
  README section. Nothing in `apps/` or `infrastructure/platform/charts/`.
- **Gaps vs. Azure:** no secret store (accepted), no OIDC for CI, no keyless pull, no cloud load balancer.
- **Surprises:** manual 24-hour contract review; separate IONOS Cloud portal; PostgreSQL v2 with one
  database only; 4 GB minimum for the database; undocumented date format in the Terraform provider;
  a CLI command against a decommissioned API.
- **Agent mistakes:** 4 (token date format, Windows `KUBECONFIG`, DB minimum assumed, SQL quoting bug
  caught before running).
- **Time:** ~2 h active (user's estimate) + up to 24 h review. Apply ~6 min, deploy ~4 min.
- **Cost:** compared based on list prices: ≈ 140–150 €/month net (≈ 4.60–4.95 €/day), paid from the
  € 200 starting credit.
