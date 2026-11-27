# Root module: selects the provider module. Every provider module has the same outputs, so the scripts
# and the chart stay unchanged; on this branch the IONOS module is selected.

module "infra" {
  source = "./modules/ionos"

  prefix             = var.prefix
  location           = var.location
  kubernetes_version = var.kubernetes_version
  node_count         = var.node_count
  node_cores         = var.node_cores
  node_ram_mb        = var.node_ram_mb
}
