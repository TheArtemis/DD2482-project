resource "azurerm_log_analytics_workspace" "project" {
  count               = var.enable_monitoring ? 1 : 0
  name                = "${local.resource_prefix}-logs"
  location            = data.azurerm_resource_group.project.location
  resource_group_name = data.azurerm_resource_group.project.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}
