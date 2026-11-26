# Root module: selects the provider module. Every provider module (modules/azure, modules/scaleway, …)
# has the same outputs, so the rest of the tooling does not care which one runs.

module "infra" {
  source = "./modules/scaleway"

  prefix             = var.prefix
  region             = var.region
  zone               = var.zone
  kubernetes_version = var.kubernetes_version
  node_size          = var.node_size
  node_count         = var.node_count

  tags = ["project=${var.prefix}", "managed-by=terraform"]
}
