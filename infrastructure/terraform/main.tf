# Root module: selects the provider module. Every provider module has the same outputs, so the scripts
# and the chart stay unchanged; on this branch the OVHcloud module is selected.

module "infra" {
  source = "./modules/ovhcloud"

  prefix              = var.prefix
  project_id          = var.project_id
  okms_id             = var.okms_id
  registry_user_email = var.registry_user_email
  region              = var.region
  db_region           = var.db_region
  registry_region     = var.registry_region
  kubernetes_version  = var.kubernetes_version
  node_flavor         = var.node_flavor
  node_count          = var.node_count
}
