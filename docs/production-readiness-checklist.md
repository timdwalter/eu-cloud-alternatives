# Production readiness checklist – Azure

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
