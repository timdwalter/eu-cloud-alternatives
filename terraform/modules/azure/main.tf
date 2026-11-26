data "azurerm_client_config" "current" {}

# Globally unique names (registry, key vault, database server) get a short random suffix.
resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

locals {
  name   = var.prefix
  suffix = random_string.suffix.result
}

resource "azurerm_resource_group" "this" {
  name     = "${local.name}-rg"
  location = var.location
  tags     = var.tags
}
