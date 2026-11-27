# Evaluation – Scaleway

Same criteria and scale as [evaluation-azure.md](evaluation-azure.md). Evidence:
[test log](test-log-scaleway.md). Building blocks per resource: [building-blocks.md](building-blocks.md).

> Status: **tested and torn down** (nl-ams). Costs are compared **based on list prices**.

## Differences to the Azure reference

### What is the same

- All building blocks exist: managed Kubernetes, managed PostgreSQL **without a public endpoint**,
  private registry, secret store, load balancer with public IP, billing alerts.
- Same sizes: 2 nodes with 2 vCPU / 4 GB, database with 1 vCPU / 2 GB (Azure B1ms = Scaleway
  DB-PLAY2-PICO), Kubernetes 1.36.
- Free control plane (AKS Free tier = Kapsule mutualized), both without SLA.
- Public price API without login on both.
- The in-cluster layer is unchanged: Envoy Gateway, cert-manager, Keycloak, app chart.

### What is different

| Topic | Azure | Scaleway | Consequence |
|---|---|---|---|
| **CI login** | OIDC federation, no stored secret, identity may only push (`AcrPush`) | **No OIDC federation** (checked: federation is SSO for humans only; Scaleway's own GitHub Actions tutorial and `scaleway/action-scw` use a stored secret key). API key stored as GitHub secret; smallest permission set is `ContainerRegistryFullAccess` (push **and** delete) | Weaker on "no stored credentials" and least privilege |
| **Image pull** | Kubelet identity + `AcrPull`, no secret | **`imagePullSecret`** with a read-only key (from Secret Manager) | One more stored credential, in the cluster |
| **DB TLS** | Certificate from a public CA, verified by the backend | **Per-instance CA**, not trusted by default | App + chart change on the branch: `DB_SSL=require` (encrypt, no verification) |
| **IAM scope** | Terraform (Owner) creates the CI identity itself | IAM permissions are **organisation-scoped** only | Helper identities created once with the CLI so that Terraform stays project-scoped |
| **Node addresses** | Nodes without public IPs; one shared outbound IP | **Each node has a public IPv4** (inbound closed by security group) | Different network posture; private-only nodes would need a Public Gateway (+19 €/month + IP) |
| **Network layout** | VNet + 2 subnets (one delegated to PostgreSQL) + private DNS zone + link | **One Private Network**, DB and cluster attached directly | Simpler: 4 Azure building blocks become 1 |
| **Resource count** | 22 in Terraform, 6 more created by AKS | **13** in Terraform (incl. 2 DB privileges), LB/IP/security group by Kapsule | Less to understand and to tear down |
| **Root module** | – | `versions.tf`, `variables.tf`, `main.tf` change, not only the module selection | Our design was less provider-neutral than intended |
| **Onboarding** | Existing subscription; quota 0 for one VM family (switched to another family in minutes); PostgreSQL restricted in one region | Personal account, **activated immediately** – but new Kapsule clusters in fr-par **blocked by a capacity shortage**, reported as `quota exceeded 0/0`. DB, registry and secrets could be created. The misleading message led to hours of checking identity, payment method and the quotas page; only support explained it | Account creation easier, **getting to a cluster much harder** |
| **CLI on Windows** | winget, MSI, ZIP | winget, Chocolatey, Scoop, binary – but the winget command is `scaleway-cli`, not `scw` as in the docs | Small stumbling block |
| **Terraform provider** | azurerm 5: 5 schema errors from outdated knowledge | scaleway 2.92: 0 schema errors | Smoother |
| **Cost** | ≈ 118 €/month | **≈ 90 €/month** (−24 %) | Mainly nodes (40 € vs. 63 €) and no 128-GB-disk trap |

### Changed files on the branch outside the provider-specific places

`git diff main..004-scaleway`:
- `apps/backend/src/config.ts`, `apps/backend/src/db.ts` – DB TLS mode `require`
- `infrastructure/platform/charts/textlib/templates/app.yaml`, `values.yaml` – value `db.sslMode`
- `infrastructure/scripts/deploy.sh` – optional hook `provider_pre_deploy` (pull secret)
- `.github/workflows/build.yml` – registry login with an API key instead of OIDC

## Experience in short

**The path**
1. **Account:** personal sign-up, **activated immediately** – the opposite of STACKIT (business customers
   only) and IONOS (manual review up to 24 h).
2. **Tools:** CLI via winget (named `scaleway-cli` on Windows, not `scw` as in the docs), a clean Terraform
   provider, a public price API.
3. **First build:** DB, network, registry and secrets in 4 minutes – then the **cluster was blocked for a
   whole day** with `quota exceeded 0/0`.
4. **A false trail:** identity verified, the debit card suspected, a credit card added, the quotas page
   searched (no Kubernetes entry), the console tried. None of it was the cause.
5. **Support:** **not a quota problem** – a capacity shortage in fr-par, new deployments blocked, reported
   with a misleading error message.
6. **Move to Amsterdam (nl-ams):** the whole stack in **3 min 41 s**.
7. **Deploy:** missing DB privileges (agent mistake, two extra resources), then a few minutes of delay for
   the certificates because the cluster's resolver still had the old Azure IP cached. After that: HTTPS
   with trusted certificates, login, create/edit/delete – all acceptance checks passed. Re-deploy is
   idempotent (76 s, no changes).

**Good**
- Cheaper: ≈ 90 €/month vs. ≈ 118 € on Azure.
- Simpler: 13 instead of 22 Terraform resources; one private network instead of VNet, subnets and DNS zone.
- Fast to build once capacity is there.
- Terraform provider without schema surprises (unlike azurerm 5).
- App and chart unchanged except the DB TLS mode.

**Bad**
- Capacity shortage plus an **error message that points to the wrong cause** – it cost a day.
- **No OIDC:** the pipeline needs a stored API key, and there is no push-only permission set.
- **No keyless pull:** the cluster needs a pull secret.
- **DB certificate from a per-instance CA:** the app encrypts but does not verify (app change on the branch).
- **IAM only at organisation level:** helper identities created with the CLI, outside Terraform, so they
  are not removed by `terraform destroy`.
- **Login:** the login page asks to choose between Scaleway and Dedibox (separate older product line).
- **Console:** region chosen per page (a VPC landed in Amsterdam by mistake); the cluster wizard lets you
  configure everything before it fails on the block.

**Agent mistakes**
- Did not check DB privileges (admin user has no rights on separately created databases).
- Claimed without checking that a dedicated control plane is billed 30 days when deleted early – wrong.
- Blamed the debit card for the 0/0 quota – wrong.
- Did not check quotas before the first apply.

**In one sentence:** in operation simpler and cheaper than Azure; getting started was tough because of
capacity and a misleading message; weaker on security because of stored keys.

## Issues by cause

| # | Issue | Cause | Impact | Fix |
|---|---|---|---|---|
| 1 | New Kapsule clusters in fr-par blocked by a **capacity shortage**, reported as `quota exceeded … 0/0` | **Scaleway** | **High:** blocked for a day, false trail | Support ticket; moved the stack to `nl-ams` |
| 2 | Quotas page has no Kubernetes entry; quotas not self-service ("to prevent abuse") | **Scaleway** | Medium (part of the false trail) | – |
| 3 | DB certificate from a per-instance CA, not trusted by Node | **Scaleway** | Medium: app + chart change on the branch | `DB_SSL=require` (encrypt, no verification) |
| 4 | Admin user has no rights on separately created databases (Azure: has) | **Scaleway** behaviour, not checked by the agent | Medium: deploy hung, Keycloak crash loop | 2 × `scaleway_rdb_privilege` |
| 5 | No OIDC / workload identity for CI; no push-only permission set | **Scaleway** | Design gap | API key as GitHub secret, 7-day expiry |
| 6 | No keyless image pull | **Scaleway** | Design gap | Pull secret with a read-only key |
| 7 | IAM permissions only at organisation level | **Scaleway** | Low: helper identities via CLI, outside Terraform; pull-key secret copied by hand on the region move | CLI, documented |
| 8 | Nodes get public IPv4 addresses (inbound closed) | **Scaleway** | Design difference | Accepted (Public Gateway would cost extra) |
| 9 | Console: region chosen per page (VPC landed in nl-ams); cluster wizard fails only after full configuration | **Scaleway** (UX) | Low | Deleted, CLI checks |
| 10 | CLI is `scaleway-cli` on winget, `scw` in the docs | **Scaleway** / tooling | Cosmetic | Both names in the provider script |
| 11 | scaleway.com docs refuse automated fetches (403) | **Scaleway** | Low (research via the docs repository on GitHub) | `scaleway/docs-content` |
| 12 | First CI key rejected (`api_key not_found`) | Unclear | Low | New key with default project |
| 13 | Inside the cluster the domain resolved to the old Azure IP for a while; cert-manager self check timed out | DNS caching (expected) | Low (minutes) | Waited |
| 14 | Debit card blamed for the 0/0 quota; "dedicated control plane billed 30 days" claimed without checking | **Agent** | Low, but misled the user | Corrected after support / docs |
| 15 | Quotas/capacity not checked before the first apply (no CLI command for it) | **Agent** | Low | Pre-check step for the next provider |
| 16 | DB privileges (#4) not checked when writing the module by analogy to Azure | **Agent** | Medium (see #4) | – |
| 17 | `fr-par` hard-coded in script and workflow | **Agent** | Low (found at the region move) | Derived from the registry endpoint |
| 18 | Module without `required_providers`; `.gitignore` missed `*.tfvars.azure`; stray YAML block | **Agent** | Low | Fixed before commit |
| 19 | Pushes touching `build.yml` triggered unplanned pipeline runs | **Agent** | Low (failed at login, key not sent) | – |

**Count:** Scaleway 11 (one high, two medium, the rest low, cosmetic or design gaps) · unclear/expected 2 ·
agent 6.

## Scores

Scale **1–5**, same as Azure (5 = worked as expected, no detours · 3 = worked with noticeable detours ·
1 = blocked or missing). Costs are compared based on list prices, not on billing data (billing arrives
with a delay, and the test periods were not exact 24-hour blocks).

| Criterion | Score | Reasoning |
|---|---|---|
| Account & onboarding (quotas, providers, regions) | **2** | Activated immediately, no providers to register – but the first region was unusable for a day, with no hint anywhere except a wrong error. |
| Terraform support | **4** | 0 schema errors, whole stack in under 4 min, clean idempotent plan. Minus: DB privileges as separate resources, IAM outside the project scope forces CLI steps. |
| Managed Kubernetes (Kapsule) | **3** | Free control plane, fast, Cilium, LB created by the CCM. Minus: capacity block, no keyless pull. |
| Managed PostgreSQL | **3** | Private-network-only endpoint is simple. Minus: per-instance CA (app change), admin without DB rights. |
| Registry | **3** | Works and costs nearly nothing. Minus: pull secret needed, no push-only permission. |
| Secrets | **4** | Secret Manager works with the CLI and Terraform. Minus: regional – moving region means copying secrets. |
| CI integration without stored credentials | **2** | Keyless login missing (checked in the docs). Works with a stored key; mitigated with a 7-day expiry. |
| Networking / private access | **4** | One private network for cluster and DB – simpler than Azure. Minus: public IPs on the nodes. |
| Error messages & diagnosability | **1** | The decisive message (`quota 0/0`) named the wrong cause and cost a day; only support could explain it. Others were clear. |
| Documentation | **3** | Clear how-tos, Scaleway's own CI tutorial matched our setup. Minus: quota docs point to validation, not capacity; website not machine-readable. |
| Cost transparency | **4** | Public price catalog API without login, cheapest so far (based on list prices). |
| Teardown | **4** | `destroy` in 85 s, nothing billable left. Minus: 4 helper objects outside Terraform need manual CLI deletion. |
| Portability of the in-cluster layer | **4** | One LB annotation, the DB TLS mode (app + chart) and a pre-deploy hook for the pull secret. Keycloak, Gateway and cert-manager unchanged. |
| Production readiness offered | **3** | Multi-AZ, HA DB (upgradeable later), autoscaling and cross-region DB backups exist. Missing: registry image scanning, a managed identity service; Kubernetes audit logs and an SLA only with the paid dedicated control plane; no SecNumCloud/C5 yet ([checklist](production-readiness-checklist.md#scaleway)). |
| Data sovereignty | – | Not scored here (same as Azure). |

**Average (14 scored criteria): 3.1 / 5** (sum 44) · Azure: 3.9.

## Time

| Phase | Time |
|---|---|
| Active time of the person (account, CLI, identities, quota hunt, region move, DNS, browser checks) | **~4 h** – more than planned, because the Kubernetes cluster failed |
| Waiting for the support answer | **~8 h** – the answer is only shown inside the Scaleway console; the e-mail just says that there is a new message, so it was noticed late |
| Whole stack from the finished code (nl-ams) | 3 min 41 s apply + ~2 min deploy + DNS |
| Re-deploy (idempotent) | 76 s |

## Verdict

Once the cluster existed, Scaleway was **simpler, faster and cheaper** than Azure, and the same code outside
the provider module worked with small, explainable changes. The weak points are **getting started** (a
capacity shortage disguised as a quota error) and **security by design**: stored keys for CI and image pulls,
and a database certificate the app cannot verify without extra work.
