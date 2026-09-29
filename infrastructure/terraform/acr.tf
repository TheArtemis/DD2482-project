resource "azurerm_container_registry" "project" {
  name                = replace("${local.resource_prefix}acr", "-", "")
  location            = local.location
  resource_group_name = data.azurerm_resource_group.project.name
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.common_tags
}
