# European Cloud Alternatives – test project

The same minimal but realistic web stack, deployed with infrastructure as code on several cloud
providers: **Azure** as the reference, then STACKIT, IONOS and Scaleway. This repository is the test
project behind part 3 of the Medium series *"European Cloud Alternatives"*.

- `main` is the **Azure reference**.
- Each European provider gets its own branch, created from `main`. `git diff main..<branch>` is the
  migration effort.
- [`docs/test-log-azure.md`](docs/test-log-azure.md) records every step, including the mistakes.
- [`docs/production-readiness-checklist.md`](docs/production-readiness-checklist.md) shows what is missing
  for production.
- [`docs/building-blocks.md`](docs/building-blocks.md) lists every resource with the reason we need it,
  as the checklist for building an equivalent setup on the other providers.
- [`docs/evaluation-azure.md`](docs/evaluation-azure.md) scores how well the deployment worked, with the
  issues sorted by cause (provider, third party, agent/tooling).

## What gets deployed

A small "text library": anyone can read texts, users with the Keycloak role `editor` can create, edit and
delete them.

```
Browser ──HTTPS──> Load balancer ──> Envoy Gateway (Gateway API, TLS by cert-manager / Let's Encrypt)
                                       ├─ <domain>       → frontend (Next.js) ──> backend (Node.js, internal only)
                                       └─ auth.<domain>  → Keycloak (OIDC)              │
                                                              │                         │
                                                              └──── managed PostgreSQL (private network only)
Registry (images pushed by GitHub Actions via OIDC)    Secret store (DB password)
```

| Layer | Azure reference | Provider-specific? |
|---|---|---|
| Kubernetes | AKS, 1 node pool, 2 × `Standard_B2s` | yes – `infrastructure/terraform/modules/azure` |
| Database | PostgreSQL Flexible Server B1ms, VNet integration, no public access | yes |
| Registry | Azure Container Registry (Basic) | yes |
| Secrets | Key Vault holds the DB password, read by the deploy script | yes – `get_secret()` |
| Ingress / TLS | Envoy Gateway + cert-manager (HTTP-01) | no |
| Identity | Keycloak in the cluster (not Entra ID) | no |
| App | Next.js frontend + Fastify backend | no |
| CI | GitHub Actions → registry (OIDC, `AcrPush` only) | the login step |

Left out on purpose to keep it minimal: Argo CD, External Secrets Operator, external-dns, remote
Terraform state, monitoring stack, automated tests, image scanning.

## Repository layout

```
apps/
  backend/        Fastify API (internal only)
  frontend/       Next.js + Auth.js
  local-infra/    Docker Compose for the local run
infrastructure/
  terraform/      root module + modules/<provider>  (same inputs/outputs for every provider)
  platform/       Helm chart (provider-neutral), values/<provider>.yaml, versions.env
  scripts/        deploy.sh, teardown.sh, push-images.sh, providers/<provider>.sh
.github/workflows/build.yml   image pipeline
docs/             decisions, test log, production readiness checklist
```

Everything with real values stays out of Git: `*.tfvars`, Terraform state, `config.local.env`, `.env`,
kubeconfigs. Each of those files has a committed `*.example` next to it.

## Run it locally (no cloud account needed)

Prerequisites: Docker (Desktop) and Bash (Git Bash on Windows).

```bash
cp apps/local-infra/.env.example apps/local-infra/.env    # replace every "change-me"
docker compose -f apps/local-infra/docker-compose.yml up --build -d
apps/local-infra/create-users.sh                          # editor + reader without role
```

Open http://localhost:3000. Log in as the editor from your `.env`.
Stop with `docker compose -f apps/local-infra/docker-compose.yml down`. Add `-v` to delete the data too.

## Deploy to Azure

### Prerequisites

- Tools: Azure CLI, Terraform ≥ 1.17, kubectl, Helm 4, Docker, Bash, `openssl`. Optionally the GitHub CLI.
- An Azure subscription where you are **Owner**, plus a domain whose DNS records you can edit.
- Check once (read-only) and fix if needed:
  - resource providers `Microsoft.ContainerService`, `Microsoft.ContainerRegistry`, `Microsoft.KeyVault`,
    `Microsoft.DBforPostgreSQL`, `Microsoft.Network` and `Microsoft.ManagedIdentity` are registered
    (`az provider register -n …`)
  - vCPU quota for the VM family of `node_size` in your region (`az vm list-usage -l <region>`)
  - PostgreSQL Flexible Server may be created in the region:
    `az postgres flexible-server list-skus -l <region>`. A `reason` field ("Provisioning is restricted in
    this region") means it may not. This happened in `germanywestcentral`, see the test log.

### Cost

Roughly **118 €/month ≈ 3.90 €/day** with list prices in westeurope: 2 nodes, load balancer,
PostgreSQL B1ms, disks, IPs, ACR Basic. AKS control plane Free tier.
**Set a budget alert on the subscription before the first apply** (Cost Management → Budgets). Tear the
environment down when you are done.

### Steps

```bash
# 1. Infrastructure (~10 min)
cp infrastructure/terraform/terraform.tfvars.example infrastructure/terraform/terraform.tfvars   # fill in
terraform -chdir=infrastructure/terraform init
terraform -chdir=infrastructure/terraform apply

# 2. Images – by hand once (or let the pipeline do it, see below)
infrastructure/scripts/push-images.sh azure            # prints the tag

# 3. Everything inside the cluster
cp infrastructure/platform/config.local.env.example infrastructure/platform/config.local.env  # domain, tag, editor
infrastructure/scripts/deploy.sh azure                 # prints the load balancer IP
```

4. **DNS:** create A records for `<domain>` and `auth.<domain>` pointing to that IP. Remove any AAAA
   records: the load balancer is IPv4-only, and Let's Encrypt prefers IPv6. Some registrars (e.g. Strato)
   need the subdomain created first, and they do not inherit the apex settings.
5. **TLS:** start with `TLS_ISSUER=letsencrypt-staging`. Once `kubectl -n textlib get certificate` shows
   `READY True`, set `letsencrypt-prod` and run `deploy.sh` again.
6. Open `https://<domain>`, log in as the editor and create a text.

`deploy.sh` can be run again at any time. It keeps the generated secrets.

### Image pipeline (GitHub Actions)

`.github/workflows/build.yml` builds and pushes both images on every push to `main` that touches
`apps/backend` or `apps/frontend`. No secret is stored anywhere: GitHub's OIDC token is exchanged for an
Azure identity whose only role is `AcrPush` on the registry.

1. Set the outputs of `terraform output ci_variables` as repository **variables** (not secrets):
   `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `REGISTRY`.
2. Newer repositories send an ID-based subject claim
   (`repo:<owner>@<id>/<repo>@<id>:ref:refs/heads/main`). If the login step fails with `AADSTS700213`,
   copy the subject from the error into `github_oidc_subject` in `terraform.tfvars` and apply again.
3. Deploy a new image: set `IMAGE_TAG` (the short commit SHA) in `config.local.env` and run `deploy.sh azure`.

### Tear down

```bash
infrastructure/scripts/teardown.sh azure                    # removes the in-cluster layer and the load balancer
terraform -chdir=infrastructure/terraform destroy
az resource list --tag project=textlib -o table             # should be empty
```

What is left and free of charge: the automatically created `NetworkWatcherRG`, and the soft-deleted Key
Vault if a run failed. Azure purges it after 7 days. The DNS records at your registrar point nowhere
until the next deployment.

## Adding a provider

On a branch created from `main`:
- add `infrastructure/terraform/modules/<provider>` with the same variables and outputs as
  `modules/azure`, and point `infrastructure/terraform/main.tf` to it
- add `infrastructure/platform/values/<provider>.yaml` and `infrastructure/scripts/providers/<provider>.sh`
  (`get_kube_credentials`, `get_secret`, `registry_login`)
- adjust the login step in the workflow

The chart and the apps should not need changes. If they do, write it down in the provider's test log.
