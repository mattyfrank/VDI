# Variables for main.tf file in management module. These get passed in from top main.tf calling the
# module.

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

# event hub
# -------------------------------------------------------------------------------------------------------
variable "event_hub_namespace" {
  description = "Name of event hub namespace."
  type        = string
}
variable "event_hub_name" {
  description = "Name of event hub."
  type        = string
}
variable "event_hub_name_message_retention" {
  description = "Number of days to retain the events."
  type        = string
}

# storage account
# -------------------------------------------------------------------------------------------------------
variable "storage_account_name" {
  description = "Specifies the name of the storage account."
  type        = string
}

# tags
# -------------------------------------------------------------------------------------------------------
variable "tags" {
  description = "Resource tags."
  type        = map(any)
}