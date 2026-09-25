data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "project" {
  name = var.resource_group_name
}

locals {
  resource_prefix = "${var.project_name}-${random_string.suffix.result}"
  common_tags = merge(var.tags, {
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Environment = var.environment
  })
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}
