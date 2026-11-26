# Globally unique names (registry namespace) get a short random suffix.
resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

locals {
  name   = var.prefix
  suffix = random_string.suffix.result
}

# One private network for cluster and database (no delegated subnet needed on Scaleway).
resource "scaleway_vpc_private_network" "this" {
  name   = "${local.name}-pn"
  region = var.region
  tags   = var.tags
}
