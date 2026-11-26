resource "azurerm_container_registry" "this" {
  name                = "${local.name}acr${local.suffix}" # letters and digits only
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Basic"
  admin_enabled       = false
  tags                = var.tags
}

# Nodes pull images with the kubelet identity – no pull secret.
resource "azurerm_role_assignment" "aks_pull" {
  scope                            = azurerm_container_registry.this.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}
