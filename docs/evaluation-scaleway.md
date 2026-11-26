# Evaluation – Scaleway

Same criteria and scale as [evaluation-azure.md](evaluation-azure.md). Evidence:
[test log](test-log-scaleway.md). Building blocks per resource: [building-blocks.md](building-blocks.md).

> Status: **in progress.** The differences below are known from research and code. Scores follow after
> the deployment test.

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
| **Onboarding** | Existing subscription; quota 0 for one VM family (switched to another family in minutes); PostgreSQL restricted in one region | Personal account, **activated immediately** – but **Kapsule quota 0/0** until the payment method is validated. A Visa debit card was accepted without the verification charge, so the account silently stayed at the lowest level. DB, registry and secrets could be created, only Kubernetes was blocked. Not visible on the quotas page, not self-service; the console lets you configure a whole cluster before failing | Account creation easier, **getting to a cluster harder** – blocked for hours |
| **CLI on Windows** | winget, MSI, ZIP | winget, Chocolatey, Scoop, binary – but the winget command is `scaleway-cli`, not `scw` as in the docs | Small stumbling block |
| **Terraform provider** | azurerm 5: 5 schema errors from outdated knowledge | scaleway 2.92: 0 schema errors | Smoother |
| **Cost** | ≈ 118 €/month | **≈ 90 €/month** (−24 %) | Mainly nodes (40 € vs. 63 €) and no 128-GB-disk trap |

### Changed files on the branch outside the provider-specific places

`git diff main..004-scaleway`:
- `apps/backend/src/config.ts`, `apps/backend/src/db.ts` – DB TLS mode `require`
- `infrastructure/platform/charts/textlib/templates/app.yaml`, `values.yaml` – value `db.sslMode`
- `infrastructure/scripts/deploy.sh` – optional hook `provider_pre_deploy` (pull secret)
- `.github/workflows/build.yml` – registry login with an API key instead of OIDC

## Issues by cause

_Filled in after the deployment test._ Known so far:

- **Provider – onboarding:** Kapsule quota 0/0 despite identity verification; payment method (debit
  card) accepted but not validated; no indication anywhere except the error on create.
- **Provider – console UX:** region selector per page (VPC landed in nl-ams by mistake); the cluster
  wizard shows the price and only then the quota error.
- **Agent:** did not check organisation quotas before the first apply (no CLI command for it); wrongly
  claimed that a dedicated control plane is billed for 30 days when deleted early.

## Scores

_Filled in after the deployment test._
