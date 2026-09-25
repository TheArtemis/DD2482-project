resource "azurerm_virtual_network" "project" {
  name                = "${local.resource_prefix}-vnet"
  location            = data.azurerm_resource_group.project.location
  resource_group_name = data.azurerm_resource_group.project.name
  address_space       = ["10.20.0.0/16"]
  tags                = local.common_tags
}

resource "azurerm_subnet" "aks" {
  name                 = "aks"
  resource_group_name  = data.azurerm_resource_group.project.name
  virtual_network_name = azurerm_virtual_network.project.name
  address_prefixes     = ["10.20.0.0/22"]
}

resource "azurerm_subnet" "postgres" {
  name                 = "postgres"
  resource_group_name  = data.azurerm_resource_group.project.name
  virtual_network_name = azurerm_virtual_network.project.name
  address_prefixes     = ["10.20.4.0/24"]
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "postgres-flexible-server"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_private_dns_zone" "postgres" {
  name                = "${local.resource_prefix}.postgres.database.azure.com"
  resource_group_name = data.azurerm_resource_group.project.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${local.resource_prefix}-postgres-link"
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.project.id
  resource_group_name   = data.azurerm_resource_group.project.name
  tags                  = local.common_tags
}
