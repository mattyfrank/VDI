# Variables for main.tf file in avd desktop module. These get passed in from top main.tf calling the
# module.

# Resource Group
# -------------------------------------------------------------------------------------------------------
variable "resource_group_object" {
  description = "The Azure resource group object to contain resources."
  type = object({
    location = string
    name     = string
  })
}

# AVD Workspace
# -------------------------------------------------------------------------------------------------------
variable "workspace_name" {
  description = "Name for AVD workspace."
  type        = string
}
variable "workspace_friendly_name" {
  description = "Friendly name of AVD workspace."
  type        = string
}

# Diagnostics Settings
# -------------------------------------------------------------------------------------------------------
variable "log_analytics_id" {
  description = "Log analytics id for diagnostics settings."
  type        = string
}
variable "eventhub_name" {
  description = "Event hub name to send data to Splunk for diagnostics settings."
  type        = string
}
variable "eventhub_namespace_name" {
  description = "Event hub namespace containing event hub for diagnostics settings."
  type        = string
}

# Tags
# -------------------------------------------------------------------------------------------------------
variable "tags" {
  type = map(any)
}