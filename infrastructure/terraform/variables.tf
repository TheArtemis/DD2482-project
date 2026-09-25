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
  default = "Standard_B2s"
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
