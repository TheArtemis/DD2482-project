data "azurerm_resource_group" "project" {
  name = var.resource_group_name
}

resource "random_string" "suffix" {
  length  = 8
  upper   = false
  special = false
}

resource "azurerm_storage_account" "state" {
  name                          = "tfstate${random_string.suffix.result}"
  resource_group_name           = data.azurerm_resource_group.project.name
  location                      = data.azurerm_resource_group.project.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  min_tls_version               = "TLS1_2"
  shared_access_key_enabled     = false
  public_network_access_enabled = true

  blob_properties {
    versioning_enabled = true
  }
}

resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}
