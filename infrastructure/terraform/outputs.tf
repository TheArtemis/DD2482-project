output "aks_cluster_name" {
  value       = azurerm_kubernetes_cluster.project.name
  description = "AKS cluster name."
}

output "acr_login_server" {
  value       = azurerm_container_registry.project.login_server
  description = "ACR hostname used by the release workflow."
}

output "key_vault_name" {
  value       = azurerm_key_vault.project.name
  description = "Key Vault that holds the database connection secret."
}

output "workload_identity_client_id" {
  value       = azurerm_user_assigned_identity.workload.client_id
  description = "Client ID for the URL-shortener Kubernetes ServiceAccount annotation."
}

output "postgresql_fqdn" {
  value       = azurerm_postgresql_flexible_server.project.fqdn
  description = "Private PostgreSQL hostname."
}
