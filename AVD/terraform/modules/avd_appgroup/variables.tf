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

# AVD Application Group 
# -------------------------------------------------------------------------------------------------------
variable "appgroup_name" {
  type = string
}
variable "default_desktop_name" {
  description = "AVD Desktop Name, displayed in client. Only supported when appgroup_type = Desktop"
  type        = string
}
variable "appgroup_type" {
  description = "Desktop or RemoteApp."
  type        = string
}
variable "desktop_pool_id" {
  description = "Resource ID for a Host Pool to associate with the Application Group."
  type        = string
}
variable "group_assignment_principal_id" {
  description = "Friendly name of AVD workspace."
  type        = set(string)
}
variable "workspace_id" {
  description = "ID of workspace to associate application group."
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
variable "eventhub_rg_name" {
  description = "Event hub resource group name."
  type        = string
}

# Tags
# -------------------------------------------------------------------------------------------------------
variable "tags" {
  type = map(any)
}