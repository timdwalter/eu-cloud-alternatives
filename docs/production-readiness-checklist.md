# Production readiness checklist – Azure (reference) and IONOS

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

# IONOS

Checked on 2026-11-28 against the tested deployment (`de/fra`, Managed Kubernetes 1.36.6, DBaaS
PostgreSQL 17 v2, 1 core / 4 GB). Sources: docs.ionos.com, the IONOS price list (2026-10-29), the
Terraform provider schema (6.7.41), IONOS announcements. Same rating as above.

| # | Item | Rating | In this deployment | What it would take | Effort |
|---|---|---|---|---|---|
| 1 | Availability zones – nodes | ✅ | `availability_zone = "AUTO"` | Node pools per zone (`ZONE_1`, `ZONE_2`) | Low |
| 1 | Availability zones – database | 🟡 | 1 instance | Up to 5 instances (1 primary + standbys); zone placement not stated in the docs | Low–medium |
| 2 | WAF | ✅ | None | WAF offered (price list: per routing rule); placed in front of the public IP | Medium |
| 3 | DDoS protection | ✅ | Basic protection | DDoS Protect Basic / Advanced (L3/L4, Advanced with 24/7 support) | Low |
| 4 | Audit logs | ✅ | Activity log for the contract (privilege "access activity log") | Kubernetes API audit logs to an Object Storage bucket (`s3_buckets` on the cluster) | Low |
| 5 | Highly available PostgreSQL with failover | ✅ | No HA | `instances.count` up to 5, `STRICTLY_SYNCHRONOUS` replication; cost scales per instance | Low code change, high cost |
| 6 | Private Kubernetes API | ✅ / 🟡 | Public API | API allow list (`api_subnet_allow_list`); private clusters exist in `de/fra` but have no `LoadBalancer` services (needs another ingress path) | Low (allow list), high (private) |
| 7 | Node autoscaling | ✅ | Fixed 2 nodes | `auto_scaling { min_node_count, max_node_count }` on the node pool | Low |
| 8 | Backup and cross-region restore | ✅ / 🟡 | DB: daily backups to Object Storage `eu-central-3`, 7 days | Backup location selectable at creation; restore into a new cluster. Cluster resources: no managed backup – Velero or similar | Low (DB), medium (cluster) |
| 9 | Image scanning in the registry | ✅ | Off | Registry feature `vulnerability_scanning` (price list: 0.02 €/GB/30 days) | Low |
| 10 | Managed identity provider and MFA | ❌ / ✅ | Self-hosted Keycloak, no MFA | No managed identity service for app users found (IAM federation is for console users). Keycloak OTP/WebAuthn | Low (Keycloak MFA) |
| 11 | Certifications | 🟡 | – | **BSI C5** attestation announced in 2023 for Compute Engine, Cloud Cubes and Object Storage (Managed Kubernetes and DBaaS not named); ISO 27001 on the basis of IT-Grundschutz – current validity to be checked | None (provider-side) |

## Notes from the test (IONOS)

- **Secret store missing** – not in the list above, but relevant for production: a managed store with
  access logging and rotation would have to be self-hosted or bought from a partner.
- **Single ingress node:** `LoadBalancer` services get a public IP on one node; for production an IONOS
  Network/Application Load Balancer or several ingress nodes would be needed.
- **Biggest cost jumps:** HA PostgreSQL (per instance, already the most expensive part), WAF, DDoS Protect
  Advanced.
- **Data sovereignty:** IONOS is a German company (United Internet group) with data centres in Germany and
  other EU countries.

## Links (IONOS)

| # | Official documentation |
|---|---|
| 1, 6, 7 | [Managed Kubernetes – overview](https://docs.ionos.com/cloud/containers/managed-kubernetes/overview) · [FAQ](https://docs.ionos.com/cloud/containers/managed-kubernetes/kubernetes-faq) · [Limitations](https://docs.ionos.com/cloud/containers/managed-kubernetes/overview/limitations) |
| 2, 3 | [Price list (WAF, DDoS)](https://docs.ionos.com/cloud/support/general-information/price-list/ionos-cloud-gmbh-de) · [DDoS Protect](https://docs.ionos.com/cloud/network-services/ddos-protect) |
| 4 | [Activity logs](https://learn.cloud.ionos.co.uk/foundational/products/Observability/activity-logs.html) · Terraform `ionoscloud_k8s_cluster.s3_buckets` |
| 5, 8 | [PostgreSQL overview](https://docs.ionos.com/cloud/databases/postgresql/overview) |
| 9 | [Private Container Registry](https://docs.ionos.com/cloud/containers/private-container-registry/overview) |
| 10 | [User management](https://docs.ionos.com/cloud/set-up-ionos-cloud/management/identity-access-management/user-management) |
| 11 | [IONOS C5 announcement](https://ionos-group.com/investor-relations/publications/announcements/ionos-receives-c5-certification-for-compute-engine-cloud-cubes-and-s3-object-storage.html) · [BSI certificate BSI-IGZ-0543-2022](https://www.bsi.bund.de/SharedDocs/Zertifikate_GS_ISO27001/Abgeschlossen/BSI-IGZ-0543-2022.html) |
