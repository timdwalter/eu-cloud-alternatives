resource "azurerm_kubernetes_cluster" "this" {
  name                = "${local.name}-aks"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = local.name
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Free"
  node_resource_group = "${local.name}-aks-nodes-rg"
  tags                = var.tags

  default_node_pool {
    name                        = "system"
    vm_size                     = var.node_size
    node_count                  = var.node_count
    vnet_subnet_id              = azurerm_subnet.aks.id
    os_disk_size_gb             = 32 # default 128 GB (P10) would cost ~19 €/node/month
    os_disk_type                = "Managed"
    temporary_name_for_rotation = "systemtmp"
    tags                        = var.tags
  }

  identity {
    type = "SystemAssigned"
  }

  # Required block since azurerm 5. "Manual" = classic node pools, no node auto-provisioning (Karpenter).
  node_provisioning_profile {
    mode = "Manual"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    pod_cidr            = "10.244.0.0/16"
    service_cidr        = "10.0.0.0/16"
    dns_service_ip      = "10.0.0.10"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }
}

# The cluster identity manages load balancers in our own VNet.
resource "azurerm_role_assignment" "aks_network" {
  scope                = azurerm_subnet.aks.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.this.identity[0].principal_id
}
