# Provider module interface – identical outputs for every provider module.

output "cluster_name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "kube_credentials_command" {
  value = "az aks get-credentials --resource-group ${azurerm_resource_group.this.name} --name ${azurerm_kubernetes_cluster.this.name} --overwrite-existing"
}

output "registry_login_server" {
  value = azurerm_container_registry.this.login_server
}

output "db_host" {
  value = azurerm_postgresql_flexible_server.this.fqdn
}

output "db_user" {
  value = azurerm_postgresql_flexible_server.this.administrator_login
}

output "secret_store_name" {
  value = azurerm_key_vault.this.name
}

output "ci_variables" {
  value = {
    AZURE_CLIENT_ID       = azurerm_user_assigned_identity.ci.client_id
    AZURE_TENANT_ID       = data.azurerm_client_config.current.tenant_id
    AZURE_SUBSCRIPTION_ID = data.azurerm_client_config.current.subscription_id
    REGISTRY              = azurerm_container_registry.this.login_server
  }
}
