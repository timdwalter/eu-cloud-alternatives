# Root module: selects the provider module. Every provider module (modules/azure, later
# modules/stackit, …) has the same inputs and outputs, so only this file changes per provider.

module "infra" {
  source = "./modules/azure"

  prefix              = var.prefix
  location            = var.location
  kubernetes_version  = var.kubernetes_version
  node_size           = var.node_size
  node_count          = var.node_count
  github_repository   = var.github_repository
  github_oidc_subject = var.github_oidc_subject

  tags = {
    project    = var.prefix
    managed-by = "terraform"
  }
}
