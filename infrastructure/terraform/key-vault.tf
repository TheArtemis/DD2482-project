resource "azurerm_key_vault" "project" {
  name                       = "${local.resource_prefix}-kv"
  location                   = data.azurerm_resource_group.project.location
  resource_group_name        = data.azurerm_resource_group.project.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  rbac_authorization_enabled = true
  tags                       = local.common_tags
}

resource "azurerm_user_assigned_identity" "workload" {
  name                = "${local.resource_prefix}-workload"
  location            = data.azurerm_resource_group.project.location
  resource_group_name = data.azurerm_resource_group.project.name
  tags                = local.common_tags
}

resource "azurerm_federated_identity_credential" "workload" {
  name                = "url-shortener"
  resource_group_name = data.azurerm_resource_group.project.name
  parent_id           = azurerm_user_assigned_identity.workload.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.project.oidc_issuer_url
  subject             = "system:serviceaccount:url-shortener:url-shortener"
}

resource "azurerm_role_assignment" "terraform_key_vault_admin" {
  scope                = azurerm_key_vault.project.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_secret" "database_url" {
  name         = "database-url"
  value        = "postgresql+psycopg://${var.postgres_admin_login}:${random_password.postgres.result}@${azurerm_postgresql_flexible_server.project.fqdn}:5432/${azurerm_postgresql_flexible_server_database.app.name}?sslmode=require"
  key_vault_id = azurerm_key_vault.project.id
  content_type = "SQLAlchemy PostgreSQL connection URL"

  depends_on = [azurerm_role_assignment.terraform_key_vault_admin]
}

resource "azurerm_role_assignment" "workload_key_vault_secrets" {
  scope                = azurerm_key_vault.project.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}
