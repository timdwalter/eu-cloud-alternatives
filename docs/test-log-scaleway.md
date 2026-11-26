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