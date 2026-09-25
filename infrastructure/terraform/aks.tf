resource "azurerm_user_assigned_identity" "aks" {
  name                = "${local.resource_prefix}-aks"
  location            = data.azurerm_resource_group.project.location
  resource_group_name = data.azurerm_resource_group.project.name
  tags                = local.common_tags
}

resource "azurerm_role_assignment" "aks_network" {
  scope                = azurerm_subnet.aks.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_kubernetes_cluster" "project" {
  name                = "${local.resource_prefix}-aks"
  location            = data.azurerm_resource_group.project.location
  resource_group_name = data.azurerm_resource_group.project.name
  dns_prefix          = "${local.resource_prefix}-aks"
  # AKS requires a separate Azure-managed resource group for node VMs, disks,
  # and scale sets. It cannot reuse the cluster's resource group.
  node_resource_group = "${data.azurerm_resource_group.project.name}-aks-nodes"
  sku_tier            = "Free"

  default_node_pool {
    name           = "system"
    vm_size        = var.aks_vm_size
    node_count     = var.aks_node_count
    vnet_subnet_id = azurerm_subnet.aks.id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "azure"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  dynamic "oms_agent" {
    for_each = var.enable_monitoring ? [1] : []
    content {
      log_analytics_workspace_id = azurerm_log_analytics_workspace.project[0].id
    }
  }

  tags       = local.common_tags
  depends_on = [azurerm_role_assignment.aks_network]
}

resource "azurerm_role_assignment" "kubelet_acr_pull" {
  scope                = azurerm_container_registry.project.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.project.kubelet_identity[0].object_id
}
