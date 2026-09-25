resource "random_password" "postgres" {
  length  = 32
  special = false
}

resource "azurerm_postgresql_flexible_server" "project" {
  name                   = "${local.resource_prefix}-postgres"
  resource_group_name    = data.azurerm_resource_group.project.name
  location               = data.azurerm_resource_group.project.location
  version                = "16"
  delegated_subnet_id    = azurerm_subnet.postgres.id
  private_dns_zone_id    = azurerm_private_dns_zone.postgres.id
  administrator_login    = var.postgres_admin_login
  administrator_password = random_password.postgres.result
  sku_name               = "B_Standard_B1ms"
  storage_mb             = 32768
  backup_retention_days  = 7
  tags                   = local.common_tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = "url_shortener"
  server_id = azurerm_postgresql_flexible_server.project.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}
