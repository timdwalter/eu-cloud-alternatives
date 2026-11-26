# Building blocks – what the stack needs and why

Every provider test has to deliver **the same functions**. Resource names differ between clouds, so this
list is organised by function. For each provider, fill in which resource provides it. If a provider
needs extra parts or cannot offer one, that is a result for the article.

Azure figures are from the reference deployment (westeurope, list prices, 730 h/month).
"Auto" = created by the managed Kubernetes service itself, not declared in our Terraform code.

## Infrastructure (Terraform module per provider)

| # | Function | Why we need it | Azure | Created by | Azure €/month | STACKIT | IONOS | Scaleway |
|---|---|---|---|---|---|---|---|---|
| 1 | Resource container | Groups everything of the test, so it can be found, tagged (`project=textlib`) and deleted together | Resource group `textlib-rg` | Terraform | 0 | | | |
| 2 | Private network | The database must not be reachable from the internet; cluster and DB need a common private network | Virtual network `10.20.0.0/16` | Terraform | 0 | | | |
| 3 | Subnet for nodes | Address range for the Kubernetes nodes | Subnet `aks` `10.20.0.0/22` | Terraform | 0 | | | |
| 4 | Subnet for the database | Azure requires a dedicated, delegated subnet for a VNet-integrated PostgreSQL | Subnet `db` `10.20.8.0/24` (delegated) | Terraform | 0 | | | |
| 5 | Private name resolution | The cluster must resolve the DB host name to its private IP | Private DNS zone + VNet link | Terraform | ~0 | | | |
| 6 | Managed Kubernetes control plane | Runs the API server, scheduler, etc. Managed by the provider | AKS (Free tier) | Terraform | 0 | | | |
| 7 | Worker nodes | The VMs that run all containers: app, Keycloak, gateway, cert-manager | VM scale set, 2 × `Standard_B2s` (2 vCPU, 4 GiB) | Auto (from AKS node pool) | 62.93 | | | |
| 8 | Node disks | OS disk per node. Reduced to 32 GB, the default 128 GB would cost ~19 €/node | 2 × Premium SSD P4 | Auto | 10.43 | | | |
| 9 | Node firewall | Default network rules for the nodes | Network security group | Auto | 0 | | | |
| 10 | Load balancer | Public entry point; forwards ports 80/443 to the Envoy gateway, and handles outbound traffic of the nodes | Standard Load Balancer `kubernetes` | Auto (from `Service type=LoadBalancer` and AKS outbound) | 16.35 | | | |
| 11 | Public IP – inbound | The address the DNS A records point to | Public IP (gateway) | Auto | 3.29 | | | |
| 12 | Public IP – outbound | Source address for traffic from the nodes (image pulls, Let's Encrypt) | Public IP (AKS outbound) | Auto | 3.29 | | | |
| 13 | Managed PostgreSQL | Database for the app and Keycloak; backups and patches by the provider; private access only | PostgreSQL Flexible Server 17, Burstable B1ms, 32 GB | Terraform | 17.01 | | | |
| 14 | Container registry | Private image store the cluster pulls from | Container Registry Basic | Terraform | 4.55 | | | |
| 15 | Pull permission | Nodes pull images without a stored password | `AcrPull` for the kubelet identity (agent pool identity: Auto) | Terraform | 0 | | | |
| 16 | Secret store | Holds the DB password outside Git and outside the pipeline | Key Vault (RBAC) + secret `db-password` | Terraform | ~0 | | | |
| 17 | CI identity | Lets the pipeline push images without a stored credential (OIDC federation), allowed to push and nothing else | User-assigned managed identity + federated credential + `AcrPush` | Terraform | 0 | | | |
| 18 | Network permission for the cluster | The cluster may create load balancers in our own subnet | `Network Contributor` on subnet `aks` | Terraform | 0 | | | |
| – | Network diagnostics | Not needed by us. Azure creates it automatically with the first VNet in a region | Network Watcher (`NetworkWatcherRG`) | Auto (Azure) | 0 | | | |
| | **Total** | | | | **≈ 118** | | | |

## Inside the cluster (identical on every provider)

| Function | Why | Implementation | Provider-specific part |
|---|---|---|---|
| Ingress | One public entry point for both host names, HTTP → HTTPS redirect | Envoy Gateway (Gateway API) | Annotations on the load balancer service (`values/<provider>.yaml`) |
| TLS certificates | Publicly trusted HTTPS, renewed automatically | cert-manager + Let's Encrypt (HTTP-01) | none |
| Identity / login | App login via OIDC, without the provider's own identity service | Keycloak (official image), realm imported from JSON | none |
| App | Frontend (public) and backend (internal only) | Own Helm chart `textlib` | none |
| Secrets in the cluster | DB password, client secret, session secret | Kubernetes Secret, created by `deploy.sh` | `get_secret()` in `scripts/providers/<provider>.sh` |

## Outside the cloud

| Function | Why | Implementation |
|---|---|---|
| DNS | `<domain>` and `auth.<domain>` point to the inbound IP | A records at the registrar (Strato), set by hand |
| Image pipeline | Build and push images on every change | GitHub Actions + OIDC (login step per provider) |
| Cost guard | Warning before costs run away | Budget alert on the subscription/project, set by hand |

## Equivalence rules for the other providers

1. Every function from #2 to #17 must exist, or be documented as missing, with the workaround if there is one.
2. The database must have **no public endpoint**.
3. No stored credentials: neither in Git, nor in the pipeline, nor in pull secrets, if the provider offers
   an alternative. Otherwise document it.
4. Comparable size: 2 nodes with ~2 vCPU / 4 GiB each, smallest managed PostgreSQL tier, smallest registry.
5. Resources the provider creates automatically are listed too, because they count for cost and complexity.
