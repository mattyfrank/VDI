# Variables for main.tf file in automation_account module. These get passed in from top main.tf calling the
# module.

variable "env" {
  description = "Environment (prod, nonprod)"
  type        = string

  validation {
    condition     = contains(["prod", "nonprod"], var.env)
    error_message = "Valid values for var: env are (prod, nonprod)."
  }
}
# resource group
# -------------------------------------------------------------------------------------------------------
variable "resource_group_name" {
  description = "The Azure resource group name to contain resources."
  type        = string
}
variable "resource_group_location" {
  description = "The Azure resource group location."
  type        = string
}

# azure automation account
# -------------------------------------------------------------------------------------------------------
variable "azure_automation_account_name" {
  description = "Specifies the name of the azure automation account."
  type        = string
}
variable "domain_join_pw" {
  description = "Domain join password"
  type        = string
  sensitive   = true
}
variable "local_admin_pw" {
  description = "Virtual machine local admin password."
  type        = string
  sensitive   = true
}
variable "domain_join_upn" {
  description = "Domain join password"
  type        = string
}
variable "local_admin_username" {
  description = "Virtual machine local admin password."
  type        = string
}
variable "storage_account_key" {
  description = "Primary key for storage account containing AVD resources."
  type        = string
  sensitive   = true
}
variable "storage_account_name" {
  description = "Name of storage account containing AVD resources."
  type        = string
}
variable "horizon_api_pw" {
  description = "Password for horizon api account."
  type        = string
  sensitive   = true
}

variable "hybrid_worker_pw" {
  description = "Password for hybrid worker service account."
  type        = string
  sensitive   = true
}

# virtual machine scale set
# -------------------------------------------------------------------------------------------------------
variable "hybrid_worker_subnet_id" {
  description = "Subnet ID for hybrid workers."
  type        = string
}

# log analytics
# -------------------------------------------------------------------------------------------------------
variable "log_analytics_name" {
  description = "Name of log analytics workspace."
  type        = string
}
variable "log_analytics_sku" {
  description = "Sku of the Log Analytics Workspace."
  type        = string
}
variable "log_analytics_retention_in_days" {
  description = "The workspace data retention in days."
  type        = number
}

# tags
# -------------------------------------------------------------------------------------------------------
variable "tags" {
  description = "Resource tags."
  type        = map(any)
}