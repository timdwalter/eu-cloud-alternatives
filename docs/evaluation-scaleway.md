# Evaluation – Scaleway

Same criteria and scale as [evaluation-azure.md](evaluation-azure.md). Evidence:
[test log](test-log-scaleway.md). Building blocks per resource: [building-blocks.md](building-blocks.md).

> Status: **deployment test passed** (nl-ams). Scores and actual cost follow.

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
| **CI login** | OIDC federation, no stored secret, identity may only push (`AcrPush`) | **No OIDC federation.** API key stored as GitHub secret; smallest permission set is `ContainerRegistryFullAccess` (push **and** delete) | Weaker on "no stored credentials" and least privilege |
| **Image pull** | Kubelet identity + `AcrPull`, no secret | **`imagePullSecret`** with a read-only key (from Secret Manager) | One more stored credential, in the cluster |
| **DB TLS** | Certificate from a public CA, verified by the backend | **Per-instance CA**, not trusted by default | App + chart change on the branch: `DB_SSL=require` (encrypt, no verification) |
| **IAM scope** | Terraform (Owner) creates the CI identity itself | IAM permissions are **organisation-scoped** only | Helper identities created once with the CLI so that Terraform stays project-scoped |
| **Node addresses** | Nodes without public IPs; one shared outbound IP | **Each node has a public IPv4** (inbound closed by security group) | Different network posture; private-only nodes would need a Public Gateway (+19 €/month + IP) |
| **Network layout** | VNet + 2 subnets (one delegated to PostgreSQL) + private DNS zone + link | **One Private Network**, DB and cluster attached directly | Simpler: 4 Azure building blocks become 1 |
| **Resource count** | 22 in Terraform, 6 more created by AKS | **11** in Terraform, LB/IP/security group by Kapsule | Less to understand and to tear down |
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

_Filled in after the deployment test._ Known so far:

- **Provider – capacity:** new Kapsule deployments in fr-par temporarily blocked because of a capacity
  shortage (support answer). The API reports this as `quota exceeded 0/0` – a **misleading error message**
  that sent the test on a false trail (identity check, payment method, quotas page, support ticket). The quotas page states that quotas are limited by default to prevent abuse and must be requested
  from support – an unnecessary hurdle for a new customer who wants a single free-tier cluster.
- **Provider – console UX:** region selector per page (VPC landed in nl-ams by mistake); the cluster
  wizard shows the price and only then the quota error.
- **Agent:** blamed the debit card for the 0/0 quota (wrong, it was capacity); did not check organisation quotas before the first apply (no CLI command for it); wrongly
  claimed that a dedicated control plane is billed for 30 days when deleted early.

## Scores

_Filled in after the deployment test._
