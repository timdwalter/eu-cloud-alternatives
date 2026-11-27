# Evaluation – IONOS

Same criteria and scale as [evaluation-azure.md](evaluation-azure.md). Evidence:
[test log](test-log-ionos.md). Building blocks per resource: [building-blocks.md](building-blocks.md).

> Status: **tested and torn down** (`de/fra`). Costs are compared **based on list prices**.

## Differences to the Azure reference

### What is the same

- All building blocks except a secret store exist: managed Kubernetes, managed PostgreSQL **without a
  public endpoint**, private registry, public IP for the gateway, cost alert.
- Same node size (2 × 2 vCPU / 4 GB), Kubernetes 1.36, free control plane (no price line).
- **App and Helm chart unchanged** – the database certificate is publicly trusted (Let's Encrypt), so the
  backend verifies it exactly as on Azure.
- The in-cluster layer is unchanged: Envoy Gateway, cert-manager, Keycloak, app chart.

### What is different

| Topic | Azure | IONOS | Consequence |
|---|---|---|---|
| **Onboarding** | Existing subscription; quota 0 for one VM family; PostgreSQL restricted in one region | Private sign-up possible, but the "full version" is **reviewed manually (up to 24 h)**; API tokens only after that. Separate portal and login for IONOS Cloud | A day of waiting before the first resource |
| **CI login** | OIDC federation, identity may only push | **No OIDC.** Registry token (pull + push, no delete, 7-day expiry) as GitHub secret | Stored credential, but tightly scoped and self-expiring |
| **Image pull** | Kubelet identity + `AcrPull` | **`imagePullSecret`** with a pull-only registry token | One more stored credential in the cluster |
| **Secret store** | Key Vault | **None** – DB password only in the local Terraform state and the Kubernetes Secret | Documented gap (no managed store, no access log, no rotation) |
| **Load balancer** | Standard Load Balancer | **None** – the public IP is attached to one node (ingress node) | Cheaper, simpler, but a single entry node |
| **Database** | B1ms (1 vCore burstable, 2 GiB), ≈ 17 € | Smallest allowed: **1 core, 4 GB**, ≈ 64 € | **~3.5× the DB cost** |
| **Databases per cluster** | Terraform creates both | PostgreSQL v2 resource creates **one** initial database | Second database via a `psql` pod in `providers/ionos.sh` |
| **Network layout** | VNet + 2 subnets + private DNS zone + link | One private LAN (`10.20.0.0/24`), DB with a fixed address | Simpler |
| **Resource count** | 22 in Terraform, 6 more by AKS | **10** in Terraform (incl. 2 random values); IONOS adds its own Helm releases in the cluster | Less to understand |
| **Contract limits** | Spread over quota pages | One `ionosctl contract get` shows cores, RAM, IPs, clusters | Easy to check before applying |
| **CLI on Windows** | winget | **No winget/Chocolatey**, ZIP from GitHub; no browser login | Small stumbling blocks |
| **Terraform provider** | azurerm 5: 5 schema errors | 0 schema errors (schema read first); one date-format quirk | Smooth |
| **Cost (list prices, net)** | ≈ 118 €/month | **≈ 140–150 €/month** | Most expensive of the three, because of the database |

### Changed files on the branch outside the provider-specific places

`git diff main..003-ionos`:
- `infrastructure/scripts/deploy.sh` – optional hook `provider_pre_deploy` (as on Scaleway)
- root `versions.tf`, `variables.tf`, `main.tf`, `outputs.tf` (4 extra outputs that replace a secret
  store), `terraform.tfvars.example`
- `.github/workflows/build.yml` – token login instead of OIDC
- **No change** in `apps/` or `infrastructure/platform/charts/`.

## Experience in short

**The path**
1. **Account:** the user already had an IONOS customer account – but IONOS Cloud is a **separate portal
   with its own login**, and the start page shows Black Friday advertising first.
2. **Registration:** private address accepted (no company needed), € 200 starting credit – but only after
   unlocking the full version, which is **reviewed manually for up to 24 h**. Token Manager (and with it any
   CLI/Terraform access) only after the unlock.
3. **Identity:** group with six privileges + separate non-admin user + 4-hour token. Creating the group in
   the DCD was not obvious, and its privileges were empty at first. Least privilege worked: the
   Terraform user's token was correctly refused when it tried to change the group.
4. **Checks before applying:** contract limits, Kubernetes versions, locations and DB sizes readable with
   the CLI – the database minimum turned out to be 4 GB, not 2 GB.
5. **Code:** provider schema read first → 0 schema errors. PostgreSQL v2 creates only one database →
   second database through a TLS-verified `psql` pod.
6. **Apply:** Kubernetes cluster in 1 min, nodes 3.5 min, PostgreSQL 5 min. The two registry tokens
   failed because of an undocumented date format; fixed in minutes.
7. **Deploy:** one Windows path mistake (agent), then 3 min 49 s. The unchanged app connected with a
   verified certificate. DNS, certificates, browser checks, idempotent re-deploy, pipeline: all at the
   first attempt.

**Good**
- App and chart unchanged – the only European provider so far where that holds.
- Fast: cluster in a minute, whole stack in about 6 minutes.
- Contract limits visible and readable – no hidden quota.
- Registry tokens with scopes and expiry – the best CI credential of the European providers so far.
- Terraform provider without schema surprises.

**Bad**
- **Onboarding:** two portals, 24-hour manual review, no API access before it.
- **Database cost:** no small or burstable tier; 4 GB minimum; DBaaS cores cost 3.5× a Kubernetes vCPU.
- **No secret store**, no OIDC for CI, no keyless pull.
- **No real load balancer** – one node carries all inbound traffic.
- **Smaller portfolio** overall (user's first impression of the DCD): four database types, Kubernetes and
  registry for containers, Kafka – little beyond what this stack needs.
- Tooling rough edges: no winget/Chocolatey, no browser login, a CLI command calling a decommissioned API,
  an undocumented date format in the Terraform provider.

**Agent mistakes**
- Registry token expiry date format not checked (apply failed for 2 resources).
- `KUBECONFIG` merge with Unix separator for the Windows `kubectl.exe` (first deploy stopped at once).
- Assumed a 2 GB database minimum in the plan (cost estimate too low by ~10 €/month).
- An SQL quoting bug in the `psql` command – caught before running.

**In one sentence:** technically the cleanest migration so far (no app change, fast, few surprises);
the price is a slow start, the most expensive database and three security gaps by design.

## Issues by cause

| # | Issue | Cause | Impact | Fix |
|---|---|---|---|---|
| 1 | Full version reviewed manually (up to 24 h); no API token before | **IONOS** | Medium (a day of waiting) | Waited |
| 2 | IONOS Cloud has its own portal and login, separate from the customer account | **IONOS** | Low | Registered for IONOS Cloud |
| 3 | No winget/Chocolatey package, no browser login for the CLI | **IONOS** / tooling | Low | ZIP from GitHub, token login |
| 4 | Creating a group in the DCD not obvious; new group without privileges | **IONOS** (UX) | Low | Found by the user; privileges ticked |
| 5 | Price list states "business customers" although private sign-up works | **IONOS** | Unclear | – |
| 6 | DBaaS minimum 4 GB RAM, no burstable tier; expensive DBaaS cores | **IONOS** | Medium (cost) | Accepted (smallest tier) |
| 7 | `ionosctl dbaas postgres version list` → 410 "API decommissioned" | **IONOS** (CLI) | Low | Terraform data source instead |
| 8 | PostgreSQL v2 resource creates only one database; extra-DB resource belongs to v1 | **IONOS** / Terraform provider | Medium | `psql` pod in `providers/ionos.sh` |
| 9 | Registry token expiry needs `YYYY-MM-DD hh:mm:ssZ`; ISO 8601 fails with a Go parse error | Terraform provider | Low | `formatdate()` |
| 10 | No managed secret store | **IONOS** | Design gap | Password in local state (accepted) |
| 11 | No OIDC for CI, no keyless pull | **IONOS** | Design gap | Scoped registry tokens with expiry |
| 12 | No cloud load balancer: IP on one node | **IONOS** | Design difference | Accepted |
| 13 | `kubectl run` could not attach to the `psql` pod (falls back to logs) | Platform / kubectl | Cosmetic | – |
| 14 | Token date format not checked | **Agent** | Low | See #9 |
| 15 | `KUBECONFIG` separator and paths for Windows `kubectl.exe` | **Agent** | Low | `cygpath` |
| 16 | DB minimum assumed (2 GB) instead of checked | **Agent** | Low (estimate) | Corrected after the read-only checks |
| 17 | SQL quoting bug in the `psql` command | **Agent** | None (caught before running) | Simpler query |

**Count:** IONOS / provider 12 (none high, three medium, the rest low or design gaps) · platform 1 ·
agent 4.

## Scores

Scale **1–5**, same as Azure (5 = worked as expected, no detours · 3 = worked with noticeable detours ·
1 = blocked or missing).

| Criterion | Score | Reasoning |
|---|---|---|
| Account & onboarding (quotas, providers, regions) | **3** | Private sign-up and visible contract limits, no quota surprises. Minus: second portal, 24-hour manual review, no API access before it. |
| Terraform support | **4** | 0 schema errors, whole stack in ~6 min, clean idempotent plan. Minus: v1/v2 split for PostgreSQL, undocumented date format. |
| Managed Kubernetes | **4** | Cluster in 1 min, 1.36.6, LoadBalancer without annotations, private LAN attachment simple. Minus: no keyless pull, single ingress node. |
| Managed PostgreSQL | **3** | Private LAN only, publicly trusted certificate (app unchanged), 5 min. Minus: one database per cluster in v2, 4 GB minimum, expensive. |
| Registry | **4** | Tokens with scopes and expiry, vulnerability scanning available. Minus: pull secret needed, only in `de/fra`. |
| Secrets | **1** | No managed secret store. |
| CI integration without stored credentials | **2** | Keyless login missing. Mitigated well: push-only (no delete), one registry, 7-day expiry. |
| Networking / private access | **4** | One private LAN, DB with a fixed private address and no public endpoint. Minus: nodes in public pools have public IPs, single ingress node. |
| Error messages & diagnosability | **3** | Mostly clear (403 for missing privileges, 410 for the old API). Minus: the token date error is a raw Go parse message. |
| Documentation | **3** | docs.ionos.com is thorough (incl. a machine-readable index). Minus: moved pages (404), DB minimum not in the docs, price list for "business customers". |
| Cost transparency | **3** | EUR price list public and current. Minus: no control-plane line, node IPs unclear, the most expensive setup of the three. |
| Teardown | **4** | `destroy` in 4 min, contract usage back to 0, nothing billable left. Minus: the Terraform user, group and token are manual objects in the DCD (as the helper identities on Scaleway). |
| Portability of the in-cluster layer | **5** | No app or chart change; only a pre-deploy hook in the provider script. |
| Production readiness offered | **4** | Multi-zone node pools, HA PostgreSQL, private clusters, autoscaling, WAF, DDoS Protect, Kubernetes audit logs to Object Storage, registry scanning, BSI C5 (partial scope). Missing: managed identity service, secret store ([checklist](production-readiness-checklist.md#ionos)). |
| Data sovereignty | – | Not scored here (same as Azure). |

**Average (14 scored criteria): 3.4 / 5** (sum 47) · Azure 3.9 · Scaleway 3.1.

## Time

| Phase | Time |
|---|---|
| Active time of the person (registration, identity, DCD, DNS, browser checks) | **~2 h** (user's estimate) |
| Waiting for the contract review | up to 24 h (checked the next day) |
| Whole stack from the finished code | ~6 min apply + ~4 min deploy + DNS |
| Re-deploy (idempotent) | 65 s |

## Verdict

IONOS delivered the **cleanest migration** so far: the same app and chart, a fast and predictable build,
visible limits. The costs of that are a slow, manual start, a database that is much more expensive than
on Azure or Scaleway, and three gaps by design – no secret store, no keyless CI login, no keyless pull.
