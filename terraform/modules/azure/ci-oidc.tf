# Identity for the GitHub Actions image pipeline: OIDC federation (no stored secret),
# only allowed to push images to this registry.

resource "azurerm_user_assigned_identity" "ci" {
  name                = "${local.name}-ci"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "github_main" {
  name                      = "github-main"
  user_assigned_identity_id = azurerm_user_assigned_identity.ci.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:${var.github_repository}:ref:refs/heads/main"
}

resource "azurerm_role_assignment" "ci_push" {
  scope                            = azurerm_container_registry.this.id
  role_definition_name             = "AcrPush"
  principal_id                     = azurerm_user_assigned_identity.ci.principal_id
  skip_service_principal_aad_check = true
}
