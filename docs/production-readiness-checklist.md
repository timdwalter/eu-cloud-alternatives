# Production readiness checklist – Azure (reference) and Scaleway

Stage 2 of the test: **checked only, nothing implemented.** The reference deployment is deliberately
minimal (one zone, Burstable database, public Kubernetes API). This page shows what Azure offers to close
each gap, how much work it would be with the code in this repository, and where to read more.

Checked on 2026-11-27 against the running reference deployment (region `westeurope`, AKS 1.36,
PostgreSQL Flexible Server 17 B1ms).

**Rating**
- ✅ **available** – a managed feature exists and fits this setup with little work
- 🟡 **possible with effort** – exists, but needs a bigger change, a different tier or extra components
- ❌ **missing** – not offered by the provider

| # | Item | Rating | In this deployment | What it would take | Effort |
|---|---|---|---|---|---|
| 1 | Availability zones – nodes | ✅ | Single zone | `zones = ["1","2","3"]` on the node pool, ≥ 3 nodes; nodes are recreated | Low |
| 1 | Availability zones – database | 🟡 | Single zone | Zone-redundant HA (see #5) – not available on the Burstable tier | Medium |
| 2 | WAF | 🟡 | None (Envoy Gateway directly behind a public load balancer) | Application Gateway for Containers or Azure Front Door with WAF policy in front of the gateway; changes the ingress path | Medium–high, noticeable monthly cost |
| 3 | DDoS protection | ✅ | Infrastructure (basic) protection only – always on, free | DDoS IP Protection on the gateway IP or DDoS Network Protection on the VNet | Low effort, high cost (Network Protection) |
| 4 | Audit logs | ✅ | Activity log only (default, 90 days) | Diagnostic settings for AKS (`kube-audit`, `kube-audit-admin`), Key Vault and PostgreSQL to a Log Analytics workspace | Low (Terraform), cost per ingested GB |
| 5 | Highly available PostgreSQL with failover | 🟡 | No HA – **Burstable doesn't support high availability** | Switch to General Purpose (e.g. D2ds) and enable zone-redundant HA; roughly 10–20× the database cost of B1ms | Low code change, high cost |
| 6 | Private Kubernetes API | 🟡 | Public API server endpoint | Private cluster or API server VNet integration; deployments (`deploy.sh`) then need a machine in the VNet (jump host, self-hosted runner, Bastion) | Medium |
| 7 | Node autoscaling | ✅ | Fixed 2 nodes | Cluster autoscaler (`auto_scaling_enabled`, `min_count`/`max_count`) or node auto-provisioning (Karpenter-based) | Low |
| 8 | Backup and cross-region restore | 🟡 | PostgreSQL: 7-day locally redundant backup (default). Cluster: none | PostgreSQL geo-redundant backup – **can only be chosen when the server is created** (server must be recreated). AKS Backup (Azure Backup extension) for cluster resources | Medium |
| 9 | Image scanning in the registry | ✅ | None (Trivy was dropped from the pipeline on purpose) | Microsoft Defender for Containers – vulnerability assessment of ACR images | Low, paid per vCore |
| 10 | Managed identity provider and MFA | ✅ | Self-hosted Keycloak, no MFA (by design: the app login must run unchanged on European providers) | Provider: Microsoft Entra ID with MFA / Conditional Access. Without changing the design: enable OTP or WebAuthn in Keycloak | Low (Keycloak MFA) |
| 11 | Certifications (BSI C5, ISO 27001) | ✅ | – | Azure holds a BSI C5 attestation and ISO/IEC 27001 certification; reports in the Service Trust Portal | None |

## Notes from the test

- **Region availability is a production topic too.** The subscription used for this test may not create
  PostgreSQL Flexible Server in `germanywestcentral` ("Provisioning is restricted in this region"), which
  is why the reference runs in `westeurope`. Such restrictions can be lifted via a support request, but
  they are not visible in quota or provider checks.
- **Biggest cost jumps** on the way to production: WAF, DDoS Network Protection and HA PostgreSQL (tier
  change). The rest is mostly configuration.
- **Kubernetes API access:** this setup uses local cluster accounts (no Entra ID integration for `kubectl`).
  Production setups would enable Entra ID integration with Kubernetes RBAC – a separate item not covered by
  the list above.
- **Certifications** describe the provider, not this deployment: Azure is operated by a US company, which
  matters for the data-sovereignty comparison in this series.

## Links

| # | Official documentation |
|---|---|
| 1 | [AKS – availability zones](https://learn.microsoft.com/en-us/azure/aks/reliability-availability-zones-configure) |
| 2 | [Azure Web Application Firewall](https://learn.microsoft.com/en-us/azure/web-application-firewall/overview) · [Application Gateway for Containers](https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/overview) |
| 3 | [Azure DDoS Protection](https://learn.microsoft.com/en-us/azure/ddos-protection/ddos-protection-overview) |
| 4 | [Monitor AKS (resource logs incl. audit)](https://learn.microsoft.com/en-us/azure/aks/monitor-aks) · [Activity log](https://learn.microsoft.com/en-us/azure/azure-monitor/fundamentals/activity-log) |
| 5 | [PostgreSQL Flexible Server – high availability](https://learn.microsoft.com/en-us/azure/postgresql/high-availability/concepts-high-availability) · [Reliability](https://learn.microsoft.com/en-us/azure/reliability/reliability-database-postgresql) |
| 6 | [AKS private cluster](https://learn.microsoft.com/en-us/azure/aks/private-clusters) · [API server VNet integration](https://learn.microsoft.com/en-us/azure/aks/api-server-vnet-integration) |
| 7 | [AKS cluster autoscaler](https://learn.microsoft.com/en-us/azure/aks/cluster-autoscaler) |
| 8 | [PostgreSQL backup and restore](https://learn.microsoft.com/en-us/azure/postgresql/backup-restore/concepts-backup-restore) · [AKS Backup](https://learn.microsoft.com/en-us/azure/backup/azure-kubernetes-service-backup-overview) |
| 9 | [Defender for Containers](https://learn.microsoft.com/en-us/azure/defender-for-cloud/defender-for-containers-introduction) |
| 10 | [Entra ID MFA](https://learn.microsoft.com/en-us/entra/identity/authentication/concept-mfa-howitworks) · [Keycloak server administration (OTP, WebAuthn)](https://www.keycloak.org/docs/latest/server_admin/index.html) |
| 11 | [BSI C5](https://learn.microsoft.com/en-us/compliance/regulatory/offering-c5-germany) · [ISO/IEC 27001](https://learn.microsoft.com/en-us/compliance/regulatory/offering-iso-27001) |

---

# Scaleway

Checked on 2026-11-27 against the tested deployment (region `nl-ams`, Kapsule 1.36.6 mutualized,
Managed Database `DB-PLAY2-PICO` PostgreSQL 17). Sources: Scaleway's documentation (read in its public
repository `scaleway/docs-content`, because scaleway.com refuses automated fetches), the Scaleway CLI and
Scaleway's security pages. Same rating as above.

| # | Item | Rating | In this deployment | What it would take | Effort |
|---|---|---|---|---|---|
| 1 | Availability zones – nodes | ✅ | Single zone (`nl-ams-1`) | Multi-AZ cluster: pools in several zones of the region. Limitations: control plane access through a load balancer in the primary zone; volumes stay zonal | Low |
| 1 | Availability zones – database | 🟡 | Single node | HA standby node (synchronous replication); the zone of the standby is not stated in the docs. Read replicas can be placed in another AZ | Low–medium |
| 2 | WAF | 🟡 | None | Edge Services with WAF in front of the load balancer (the Load Balancer FAQ points there) | Medium, extra cost |
| 3 | DDoS protection | 🟡 | Nothing configured | No dedicated DDoS product found for Load Balancer / Kapsule; the docs point to Edge Services (WAF) | Unclear – ask Scaleway |
| 4 | Audit logs | 🟡 | Audit Trail (IAM and other products) available | Kubernetes API audit logs **only with a dedicated control plane** (`k8s cluster-type list`: audit logs supported only for `kapsule-dedicated-*`) | Low code change, high cost |
| 5 | Highly available PostgreSQL with failover | ✅ | No HA | `is_ha_cluster = true`; a standalone instance can be **upgraded to HA after creation** (not back). Roughly doubles the DB cost. Availability on the smallest node type to verify | Low |
| 6 | Private Kubernetes API | 🟡 | Public endpoint, no IP restriction | Allowed-IP list for the control plane plus a VPC endpoint for `kubectl`; the public endpoint itself remains | Low–medium |
| 7 | Node autoscaling | ✅ | Fixed 2 nodes | Pool autoscaling with min/max size | Low |
| 8 | Backup and cross-region restore | ✅ / 🟡 | DB: automatic backups (default) | DB backups can be stored **in another region** (backup region selectable). Cluster resources: no managed backup – Velero or similar | Low (DB), medium (cluster) |
| 9 | Image scanning in the registry | ❌ | None | No vulnerability scanning found in the Container Registry docs – scanner in the pipeline (e.g. Trivy) | Low (pipeline step) |
| 10 | Managed identity provider and MFA | ❌ / ✅ | Self-hosted Keycloak, no MFA | No managed identity service for app users found (IAM MFA is for console members). Keycloak OTP/WebAuthn as on Azure | Low (Keycloak MFA) |
| 11 | Certifications | 🟡 | – | ISO/IEC 27001:2022 and HDS (BSI certificate directory); **SecNumCloud qualification in progress**, not granted; **BSI C5 not found** | None (provider-side) |

## Notes from the test (Scaleway)

- **Capacity is a production topic too.** New Kapsule clusters in fr-par were blocked for a day because of a
  capacity shortage, reported as a quota error. A production setup in a single region depends on that.
- **Security gaps by design** (not in the list above): no keyless CI login, no keyless image pull, DB
  certificate from a per-instance CA (the app does not verify it in this test).
- **Biggest cost jumps:** dedicated control plane (needed for an SLA and for Kubernetes audit logs), HA
  database, Edge Services/WAF.
- **Data sovereignty:** Scaleway is a French company (Iliad group) with data centres in France, the
  Netherlands and Poland.

## Links (Scaleway)

| # | Official documentation |
|---|---|
| 1 | [Multi-AZ clusters](https://www.scaleway.com/en/docs/kubernetes/reference-content/multi-az-clusters/) · [Read replicas](https://www.scaleway.com/en/docs/managed-databases-for-postgresql-and-mysql/how-to/manage-read-replicas/) |
| 2, 3 | [Edge Services – WAF](https://www.scaleway.com/en/docs/edge-services/how-to/configure-waf/) · [Load Balancer FAQ](https://www.scaleway.com/en/docs/load-balancer/faq/) |
| 4 | [Kubernetes audit logs](https://www.scaleway.com/en/docs/kubernetes/how-to/access-audit-logs/) · [Control plane offers](https://www.scaleway.com/en/docs/kubernetes/reference-content/kubernetes-control-plane-offers/) |
| 5 | [Managed Databases – concepts (high availability)](https://www.scaleway.com/en/docs/managed-databases-for-postgresql-and-mysql/concepts/) |
| 6 | [Allowed IPs](https://www.scaleway.com/en/docs/kubernetes/how-to/manage-allowed-ips/) · [API server via VPC endpoint](https://www.scaleway.com/en/docs/kubernetes/api-cli/reach-api-server-via-vpc/) |
| 7 | [Kubernetes concepts (autoscaling)](https://www.scaleway.com/en/docs/kubernetes/concepts/) |
| 8 | [Manage DB backups](https://www.scaleway.com/en/docs/managed-databases-for-postgresql-and-mysql/how-to/manage-backups/) |
| 9 | [Container Registry docs](https://www.scaleway.com/en/docs/container-registry/) |
| 10 | [Enforce MFA (IAM)](https://www.scaleway.com/en/docs/iam/security/enforce-mfa/) |
| 11 | [Security and compliance](https://www.scaleway.com/en/security-and-compliance/) · [SecNumCloud](https://www.scaleway.com/en/security-and-compliance/secnumcloud/) |
