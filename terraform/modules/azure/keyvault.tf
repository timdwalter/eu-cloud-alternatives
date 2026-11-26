resource "azurerm_key_vault" "this" {
  name                       = "${local.name}-kv-${local.suffix}"
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = var.tags
}

# The person running Terraform may write and read secrets (Owner alone does not grant data access).
resource "azurerm_role_assignment" "kv_officer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# RBAC assignments take a while to propagate; writing the secret immediately often fails with 403.
resource "time_sleep" "kv_rbac" {
  depends_on      = [azurerm_role_assignment.kv_officer]
  create_duration = "60s"
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = random_password.db.result
  key_vault_id = azurerm_key_vault.this.id
  depends_on   = [time_sleep.kv_rbac]
}
