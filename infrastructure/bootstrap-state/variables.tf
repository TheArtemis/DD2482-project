variable "subscription_id" {
  description = "Azure subscription ID; null uses Azure CLI authentication."
  type        = string
  default     = null
  nullable    = true
}

variable "resource_group_name" {
  description = "Existing resource group in which state storage is created."
  type        = string
  default     = "devops-project"
}

variable "location" {
  description = "Azure region for state storage. Must satisfy the subscription's allowed-region policy."
  type        = string
  default     = "germanywestcentral"
}
