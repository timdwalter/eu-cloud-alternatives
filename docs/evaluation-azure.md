# Evaluation – Azure (reference)

How well did it work to deploy the [building blocks](building-blocks.md) to Azure? Same structure and
scale for every provider, so the four evaluations can be compared side by side.
Evidence: [test log](test-log-azure.md).

## Two perspectives

- **Person running the test (via the AI agent):** "Terraform, Helm, Docker – zero problems." Every issue
  was found and fixed by the agent, usually within minutes. The person only had to log in, approve
  costs, set a budget and edit DNS.
- **What actually happened underneath:** 20 issues, see below: 9 caused by Azure (one serious), 2 by
  third parties (GitHub, Strato), 8 by the agent or the tooling, 1 expected. None blocked the goal for long;
  one (region restriction) forced a design change.

The difference matters for the article: with an AI agent doing the work, the *perceived* difficulty of a
cloud drops sharply. The *real* friction shows in the issue list and in what an agent cannot do
(logins, MFA, budgets, DNS, support requests).

## Issues by cause

| # | Issue | Cause | Impact | Fix |
|---|---|---|---|---|
| 1 | PostgreSQL Flexible Server "restricted" in `germanywestcentral` for this subscription; misleading error `'Version' should be in: []` | **Azure** | High: region change, destroy + re-apply | Moved to `westeurope` |
| 2 | vCPU quota 0 for the Basv2 VM family | **Azure** | Low | Other VM family (`B2s`) |
| 3 | Resource providers (AKS, ACR, Key Vault) not registered | **Azure** | Low | `az provider register` |
| 4 | Apply in a fresh resource group failed with "inconsistent result" / `ResourceNotFound` (eventual consistency) | **Azure** | Low | Re-run |
| 5 | AKS admissions enforcer conflicts with Helm 4 server-side apply (2nd deploy fails) | **Azure** | Low | `--force-conflicts` in `providers/azure.sh` |
| 6 | AKS sets defaults (`upgrade_settings`) that appear as Terraform drift | **Azure** | Cosmetic | Declared in code |
| 7 | Tenant enforces MFA; first `az login` found no subscription | Azure (security feature) | Low | `az login --tenant` |
| 8 | GitHub sends ID-based OIDC subject claim; classic format rejected (`AADSTS700213`) | GitHub | Low | Configurable subject |
| 9 | Strato: subdomain must be created separately, parking AAAA records by default | Strato | Medium (waiting) | Manual DNS |
| 10 | Agent knowledge outdated: azurerm 5 (5 schema errors), Terraform 1.17, Helm 4, Node 26 | Agent | Low | Provider schema / registries |
| 11 | Windows paths for `terraform.exe` from Git Bash | Agent / tooling | Low | `pwd -W` |
| 12 | `runAsNonRoot` with non-numeric image user (not caught by Docker Compose) | Agent | Low | `runAsUser: 1000` |
| 13 | Region-change plan would have left Terraform state inconsistent | Agent | Avoided | Full destroy + apply |
| 14 | Destroy and apply chained in one background job, could not be stopped cleanly | Agent | Low (a few cents) | Separate steps |
| 15 | Second random editor password for Azure; user could not log in | Agent | Low (annoying) | Same credentials as local |
| 16 | Unquoted value in `.env.example`, Fastify error-handler typing, error page only client-side, a few test-command mistakes | Agent | Low | Fixed immediately |
| 17 | `winget` refused Terraform/Helm ("portable package exists") | Tooling (Windows) | Low | `--force` |
| 18 | Destroy failed on an already deleted federated credential (404) | Azure / Terraform provider | Low | `terraform state rm` |
| 19 | Let's Encrypt staging certificate untrusted in the browser (by design) | Expected | None | Switch to prod |
| 20 | Retail price API rate-limited during cost estimate | Azure | Cosmetic | Re-query later |

**Count:** Azure 9 (one high, the rest low or cosmetic) · third parties 2 · agent/tooling 8 · expected 1.

## Scores

Scale **1–5** (5 = worked as expected, no detours · 3 = worked with noticeable detours · 1 = blocked or missing).

| Criterion | Score | Reasoning |
|---|---|---|
| Account & onboarding (quotas, providers, regions) | **2** | Owner access was easy, but quota 0 for a common VM family, unregistered providers and, above all, the **hidden region restriction** for PostgreSQL. Nothing in the portal or the quota pages hints at it. |
| Terraform support | **4** | azurerm is mature and complete; all 22 resources in one apply in 9 min. Minus: breaking changes in major 5, drift from AKS defaults, one eventual-consistency failure. |
| Managed Kubernetes (AKS) | **4** | Fast (5 min), Free tier, workload identity for pulls built in. Minus: admissions enforcer vs. Helm 4, many auto-created resources (6). |
| Managed PostgreSQL | **3** | Private VNet integration works well. Minus: region restriction, misleading error, no HA on Burstable, geo-backup only at creation. |
| Registry | **5** | ACR Basic, pull without secrets, push via OIDC – no issues. |
| Secrets | **5** | Key Vault with RBAC worked first time (with a known 60 s propagation wait). |
| CI integration without stored credentials | **4** | OIDC federation for GitHub with least privilege (`AcrPush` only) works; the subject-format change was GitHub's. |
| Networking / private access | **5** | VNet, delegated subnet, private DNS – exactly as documented. |
| Error messages & diagnosability | **2** | The decisive error (#1) pointed in the wrong direction. Others were clear. |
| Documentation | **4** | Comprehensive and accurate where checked. Some URLs moved (404 for 2 of 17 links). |
| Cost transparency | **4** | Public price API without login; estimate matched. Minus: hidden defaults (128 GB OS disks ~19 €/node), cost data arrives with a delay. |
| Teardown | **4** | `terraform destroy` removes everything. Leftovers (Network Watcher, soft-deleted Key Vault) are free. |
| Portability of the in-cluster layer | **5** | Only one Helm value and one Helm flag are Azure-specific. App, Keycloak, Gateway and cert-manager unchanged. |
| Production readiness offered | **4** | Almost everything is available ([checklist](production-readiness-checklist.md)), mostly as paid add-ons or tier changes. |
| Data sovereignty | – | Not scored here (US provider; topic of the article series, not of this deployment test). |

**Average (14 scored criteria): 3.9 / 5** (sum 55)

## Time

| Phase | Time |
|---|---|
| First deployment incl. scope discussion, app, local test, all detours | **~5 h of the person's time**, much of it running in the background while doing other things (spread over two calendar days because the new domain at Strato was only activated overnight) |
| Infrastructure + platform from the finished code (re-deploy) | ~25 min + DNS |
| Of that, waiting for Azure (apply) | 9 min |

## Verdict

Technically Azure delivered every building block, most of them without friction. The friction sat
**before** the first resource (quota, providers, region availability) and in **AKS-specific behaviour**. The
one serious problem, PostgreSQL not being offered in Germany West Central for this subscription, is exactly
the kind of thing a customer only finds out by trying. That is relevant for the "German region" argument.

For the comparison: the European providers must reach the same building blocks with the **same code
outside the provider module**. Their scores use the same criteria and scale.
