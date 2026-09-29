output "backend_config" {
  value = <<-EOT
    resource_group_name  = "${data.azurerm_resource_group.project.name}"
    storage_account_name = "${azurerm_storage_account.state.name}"
    container_name       = "${azurerm_storage_container.state.name}"
    key                  = "url-shortener.tfstate"
    use_azuread_auth     = true
  EOT
}
