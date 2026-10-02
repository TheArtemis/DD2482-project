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

variable "operator_public_ip" {
  description = "Public IPv4 address of the machine that manages Terraform state. Azure Storage does not accept /32 CIDRs in IP rules."
  type        = string

  validation {
    condition     = !strcontains(var.operator_public_ip, ":") && can(cidrhost("${var.operator_public_ip}/32", 0))
    error_message = "operator_public_ip must be a single IPv4 address without a CIDR suffix."
  }
}
