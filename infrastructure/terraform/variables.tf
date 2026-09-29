variable "subscription_id" {
  description = "Azure subscription ID; null uses Azure CLI authentication."
  type        = string
  default     = null
  nullable    = true
}

variable "resource_group_name" {
  description = "Existing resource group in which project resources are created."
  type        = string
  default     = "devops-project"
}

variable "location" {
  description = "Azure region for project resources. Must satisfy the subscription's allowed-region policy."
  type        = string
  default     = "spaincentral"
}

variable "project_name" {
  description = "Short lowercase project name used in Azure resource names."
  type        = string
  default     = "urlshortener"

  validation {
    condition     = can(regex("^[a-z0-9]{3,16}$", var.project_name))
    error_message = "project_name must contain 3–16 lowercase letters or digits."
  }
}

variable "environment" {
  type    = string
  default = "production"
}

variable "aks_node_count" {
  type    = number
  default = 1
}

variable "aks_vm_size" {
  type    = string
  default = "Standard_D2s_v4"
}

variable "operator_public_ip" {
  description = "Public IPv4 address of the machine that runs Terraform and writes the Key Vault secret."
  type        = string

  validation {
    condition     = !strcontains(var.operator_public_ip, ":") && can(cidrhost("${var.operator_public_ip}/32", 0))
    error_message = "operator_public_ip must be a single IPv4 address without a CIDR suffix."
  }
}

variable "aks_api_authorized_ip_ranges" {
  description = "Public CIDR ranges allowed to reach the AKS API; include administrator and cluster egress addresses."
  type        = list(string)

  validation {
    condition     = length(var.aks_api_authorized_ip_ranges) > 0 && alltrue([for range in var.aks_api_authorized_ip_ranges : !strcontains(range, ":") && can(cidrhost(range, 0)) && range != "0.0.0.0/0"])
    error_message = "Provide at least one valid CIDR range and do not allow 0.0.0.0/0."
  }
}

variable "postgres_admin_login" {
  type      = string
  default   = "pgadmin"
  sensitive = true
}

variable "enable_monitoring" {
  description = "Enable Azure Monitor integration; it adds cost."
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
