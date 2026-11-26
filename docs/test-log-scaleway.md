# Test log – Scaleway

Branch `004-scaleway`, created from `main` at tag `azure-tested` (Scaleway tested before IONOS because
personal accounts are documented). Same structure as [test-log-azure.md](test-log-azure.md).

## Step 0 – CLI (2026-11-27)

**What:** Installed the Scaleway CLI on Windows.
**How:** `winget install --id Scaleway.cli` – ~1 min.

**Observations**
- Installation channels on Windows: **winget, Chocolatey (official in the README), Scoop**, the `.exe`
  from GitHub releases, and a Docker image. On macOS Homebrew, plus Arch Linux. Much better than
  STACKIT (Scoop or ZIP only).
- winget had 2.66.0 while GitHub already had 2.67.0 (released 4 days earlier), a small lag.
- **Not obvious:** the winget package registers the command as **`scaleway-cli`**, not `scw` as used
  throughout Scaleway's documentation (Homebrew installs `scw`). Copy-pasting from the docs fails on
  Windows. The provider script accepts both names.
- **Account:** personal account created by the user and **activated immediately**. No company needed, no
  waiting time. Compare STACKIT: business customers from DACH only.
## Step 1 – Research and plan (2026-11-27)

**What:** Mapped every building block to Scaleway, priced it, wrote the plan.
**How:** CLI (read-only), the public product catalog API (no login, prices for every SKU, comparable to
Azure's retail price API), Terraform registry, docs.

**Findings before writing any code**
- Kapsule control plane (mutualized) is free, like the AKS Free tier. PostgreSQL 17 and a node size identical
  to Azure's B1ms (DB-PLAY2-PICO) are available. **Estimate ≈ 90 €/month vs. 118 € on Azure.**
- **No keyless CI login:** no OIDC / workload identity federation for GitHub Actions found in Scaleway IAM.
  An API key has to be stored as a GitHub secret. There is no push-only permission set, so the key also
  allows deleting images in the project.
- **No keyless image pull:** Kapsule needs an `imagePullSecret` with an API key for a private registry
  namespace (Azure: kubelet identity + `AcrPull`).
- **DB TLS:** certificate per instance with its own CA. The backend, which verifies against public CAs,
  will not connect unchanged. Decision pending.
- Nodes get public IPv4 addresses by default. Without them, outbound traffic would need a Public Gateway.
- Billing alerts exist (console, CLI, Terraform).
- Our own root module turned out to be Azure-specific in 3 files (`versions.tf`, `variables.tf`,
  `main.tf`), not just the module selection as planned.

**Time:** ~30 min.
## Step 2 – Decisions and Terraform identity (2026-11-27)

**Decisions (user):** DB TLS mode `require` **on this branch only** (`main` stays the unchanged Azure
reference, so the diff shows the difference). Private registry + pull secret. Billing alert set by the user
in the console.

**What:** IAM application `textlib-terraform` + policy + API key, via CLI with the user's OK. ~5 min.
- Policy: 10 permission sets (Kubernetes, Instances, Block Storage, VPC, Private Networks, IPAM, Load
  Balancers, Relational Databases, Container Registry, Secret Manager), **scoped to the one project**.
- The key is stored only in a separate local CLI profile `textlib-terraform`. Checked: the profile can list
  clusters in the project and is denied IAM access.

**Not obvious**
- All IAM permission sets are **organisation-scoped**. If Terraform created the helper identities (CI push,
  cluster pull) itself, its key would need organisation-wide IAM rights. So the helper identities are
  created once with the CLI, and Terraform stays project-scoped. On Azure, Terraform created the CI
  identity itself (Owner on the subscription).
## Step 3 – Code (2026-11-27)

**What:** `modules/scaleway` (private network, Kapsule + pool, PostgreSQL on the private network only,
registry namespace, Secret Manager), root switched to Scaleway, `values/scaleway.yaml`,
`providers/scaleway.sh`, workflow login step, DB TLS mode.
**How:** Terraform 1.17.2 + provider `scaleway/scaleway` 2.92.1. `terraform plan`: **11 resources**
(Azure: 22).

**Results / findings**
- `terraform validate` passed with **no provider schema errors** (Azure: 5 errors due to azurerm 5).
  One own mistake: the module lacked a `required_providers` block, so Terraform looked for
  `hashicorp/scaleway`.
- Warning "Multiple variable sources detected": only project, region and zone are set twice (provider
  block and CLI profile). Checked: the credentials come from the project-scoped profile.
- **Changes outside the allowed places** (each is a finding):
  - backend `config.ts`/`db.ts` + chart `DB_SSL` value: new mode `require` (TLS without verification)
    for Scaleway's per-instance CA. **Branch only.**
  - `deploy.sh`: optional hook `provider_pre_deploy` (no-op on Azure), used for the pull secret.
  - root `versions.tf`, `variables.tf`, `main.tf`, `tfvars.example`: provider-specific by nature.
  - workflow: Azure OIDC login replaced by `docker login` with a stored API key.
- The Azure state and tfvars were parked locally (`*.azure`, gitignored) because Azure is still running.
  Mistake caught: the first `.gitignore` did not cover `terraform.tfvars.azure`. Fixed with `*.tfvars.*`.
## Step 4 – Identities and first apply (2026-11-27)

**What:** Created the helper identities `textlib-registry-pull` (`ContainerRegistryReadOnly`, key into
Secret Manager as `registry-pull-key`) and `textlib-ci` (`ContainerRegistryFullAccess`, key as GitHub
secret `SCW_SECRET_KEY`) via CLI, with the user's OK. Keys were never printed. The pull key went through a
temporary file for a moment (deleted right after), because the CLI takes `data=@file`. Then `terraform
apply`.
**How:** CLI, `gh secret set`, Terraform.

**Result:** 9 of 11 resources in 4 min. The PostgreSQL instance took 3 min 34 s. Then:
`quota exceeded(s): K8SClustersTypeKapsule has reached its quota (0/0)`.

**Not obvious – blocker for the moment:** a new personal account has a **Kapsule quota of 0**. According to
the docs, quotas are unlocked by **verifying payment method and identity**, otherwise through support.
None of the agent's read-only checks showed this: instance types and stock were checked, the
organisation quotas were not (there is no CLI command for them). The quotas page in the console is
the place to check it before applying.

- Identity verified by the user in the console. A second `terraform apply` right afterwards: **quota
  still 0/0** for Kapsule. Unlocking is not immediate, or identity verification alone is not enough.
- **The console's Quotas page shows no Kubernetes section at all** (user's check). The Kapsule quota
  (`K8SClustersTypeKapsule 0/0`) is neither visible nor self-service.
- Third attempt about 30 minutes after identity verification: `plan` shows 2 to add (cluster, pool),
  `apply` fails again with **0/0**. Waiting does not help. Next step: support ticket.
- **Node types in the console cluster wizard:** the user tried the console as a workaround. For the pool
  it offers only `STANDARD3-X2C-8G` (2 vCPU / 8 GB, € 0.0809/h ≈ 59 €/month per node); all smaller
  types are shown as unavailable / out of stock, PLAY2-NANO included. The wizard's default (3 nodes,
  further defaults) showed **≈ 500 €/month**. Nothing was created in the console.
- **Contradiction:** at the same time the Instance API (`instance server-type list`) reports
  `PLAY2-NANO` as **available** in fr-par-1 and fr-par-2; `BASIC3`, `POP2-2C-8G` and `PRO2-XXS` as
  `low_stock` in fr-par-1. Kapsule apparently has its own stock or its own list of allowed types, which
  is not visible through the CLI (there is no `k8s node-type` command in the installed version).
  For planning, the console is the more reliable source.
- Consequence if PLAY2-NANO stays unavailable for Kapsule: 2 × STANDARD3-X2C-8G ≈ 118 €/month for nodes
  alone instead of ≈ 40 €, total ≈ 168 €/month instead of ≈ 90 € – more expensive than Azure (≈ 118 €).
- **Correction:** the VPC and Private Network the user created in the console ended up in **nl-ams**
  (Amsterdam), not fr-par – the console's region selector was on Amsterdam, unnoticed. The node-type
  limitation above was most likely seen for nl-ams, so it is **not** evidence for fr-par. Easy to miss:
  the region is chosen per page in the console, not once per project.
- Fourth `terraform apply`: still **0/0**. `k8s cluster-type list` shows the free type `kapsule` as
  "available" – the type is offered, but the organisation quota for it is 0.
- **Console vs. quota:** the console wizard offers the dedicated control planes (`kapsule-dedicated-*`,
  99.5 % SLA, "commitment delay 30 days" in `k8s cluster-type list`), which are not blocked by the quota of
  the free type. The ≈ 500 €/month seen in the wizard most likely came from a dedicated control plane plus
  3 larger nodes.
- **Correction of an agent claim:** the agent first warned that a dedicated cluster deleted after two
  hours would be billed for 30 days. The docs say otherwise: billing is calculated **hourly**, and
  **deleting** a dedicated cluster cancels the commitment. The 30 days only block a downgrade to a lower
  tier. Lesson: check the docs before warning.
- **Workaround chosen by the user:** create the cluster in the console (dedicated control plane), test,
  delete after a few hours. When deleting, tick the option that also removes volumes and load balancers,
  otherwise they keep billing. A console cluster is outside Terraform – a documented deviation.
- The VPC and Private Network created by mistake in nl-ams were deleted (CLI, user's OK). Nothing was
  attached to them.
- **Console workaround fails as well:** the wizard showed **€191.87/month** for the user's selection, and
  creating it fails with *"quota(s) exceeded: … maximum number of K8SClustersTypeKapsule authorized by
  your Organization. Access the quotas page from your Organization dashboard to manage quotas."* The
  quota applies to all Kapsule types; the console wizard lets you configure a whole cluster before
  telling you so. The quotas page it points to has no Kubernetes entry. **Only support can unblock this.**
- **What the docs say:** Kapsule quotas follow the account level – 20 clusters with a validated payment
  method, 40 with payment method and identity validated; more only through support. The quota cannot be
  raised self-service. 0/0 after identity verification means the account does not yet count as
  validated (payment method status to be checked by the user), or the level change did not propagate.
- **Likely cause:** the payment method is a **Visa debit card**. The console accepted it, but the € 1
  verification charge was never taken from the account. So the payment method is probably not
  validated, and the account stays at the level with 0 Kapsule clusters – without any message saying so.
  The DB, registry and secrets could still be created.
- User added a credit card. `apply` directly afterwards: still
  **0/0**. Either the card's validation is still pending, or the level change takes time.
- The verification charge on the credit card shows as *pending* in the bank app (unlike the debit card,
  where nothing appeared). Next `apply`: still **0/0**. The level change is not instant after the charge.
- Next `apply` some time later: still **0/0**.
- **Quotas page text (Organization dashboard):** the page explains that quotas are limited by default
  "to prevent abuse" and that more must be requested from support. For a new customer who wants one
  small cluster this is an **unnecessary hurdle**: the free cluster type is advertised, the default
  quota for it is 0, there is no self-service request, and the page does not even list Kubernetes.
  Support ticket sent (stating that providers are being evaluated). Azure was torn down meanwhile
  (see test-log-azure.md), so the domain is offline until Scaleway is up.
