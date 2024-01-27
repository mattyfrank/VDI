# Variables for main.tf file in avd host pool module. These get passed in from top main.tf calling the
# module.

variable "env" {
  description = "Environment (prod, nonprod)"
  type        = string

  validation {
    condition     = contains(["prod", "nonprod"], var.env)
    error_message = "Valid values for var: env are (prod, nonprod)."
  }
}

# Resource Group
# -------------------------------------------------------------------------------------------------------
variable "location" {
  description = "The Azure region location."
  type        = string
}

# Host Pool
# -------------------------------------------------------------------------------------------------------
variable "host_pool_name" {
  description = "Short name of host pool used in naming of resources."
  type        = string
}
variable "host_pool_type" {
  description = "Pooled or Personal."
  type        = string
  validation {
    condition     = contains(["pooled", "personal"], var.host_pool_type)
    error_message = "Valid values for var: host_pool_type are (pooled, personal)."
  }
}
variable "pool_set_load_balancer_type" {
  description = "DepthFirst or BreadthFirst"
  type        = string
}
variable "pool_set_rdp_properties" {
  description = "Custom RDP properties string for the Virtual Desktop Host Pool."
  type        = string
  default     = null
}
variable "pool_set_max_sessions" {
  description = "A valid integer value from 0 to 999999 for the maximum number of users that have concurrent sessions on a session host."
  type        = number
  default     = 1
}
variable "pool_set_validate" {
  description = "Allows you to test service changes before they are deployed to production."
  type        = bool
  default     = false
}
variable "pool_set_autostart_vm" {
  description = "Enables or disables the Start VM on Connection Feature."
  type        = bool
}

# Subnet
# -------------------------------------------------------------------------------------------------------
variable "subnet_name" {
  type = string
}
variable "subnet_vnet_name" {
  type = string
}
variable "subnet_resource_group" {
  type = string
}

# Session Hosts
# -------------------------------------------------------------------------------------------------------
variable "personal_desktop_assignment_type" {
  type    = string
  default = "Direct"
}
variable "session_host_count" {
  description = "Number of systems to build."
  type        = number
}
variable "session_host_prefix" {
  description = "\"AVMS\" for MultiSession and \"AVPE\" for Personal."
  type        = string
  validation {
    condition     = length(var.session_host_prefix) <= 15
    error_message = "Session Host Name must be under 15 chars."
  }
}
variable "session_host_size" {
  type        = string
  description = "VM Profile Size for Session Host. B are best for Bursting, and D are for general-purpose workloads"
  validation {
    condition = anytrue([
      var.session_host_size == "Standard_B2s",
      var.session_host_size == "Standard_D2s_v5",
      var.session_host_size == "Standard_D2as_v5",
      var.session_host_size == "Standard_D4s_v5",
      var.session_host_size == "Standard_D8s_v5",
      var.session_host_size == "Standard_D8as_v5"
    ])
    error_message = "VM Size must be \"Standard_B2s\", \"Standard_D2as_v5\", \"Standard_D4s_v5\", \"Standard_D8s_v5\", \"Standard_D8as_v5\"."
  }
}
variable "session_host_disk_type" {
  description = "Specify OS Disk Type."
  type        = string
  validation {
    condition     = var.session_host_disk_type == "Standard_LRS" || var.session_host_disk_type == "StandardSSD_LRS"
    error_message = "Disk Type must be StandardHDD or StandardSSD."
  }
}
variable "session_host_disk_size_gb" {
  description = "Specify disk size if different than image disk size."
  type        = string
  default     = null
}
variable "ip_allocation_type" {
  description = "Static or Dynamic"
  type        = string
  default     = "Dynamic"
  validation {
    condition     = var.ip_allocation_type == "Static" || var.ip_allocation_type == "Dynamic"
    error_message = "Network IP Allocation Type must be Static of Dynamic."
  }
}
variable "shared_image_id" {
  type = string
}
variable "vm_admin_username" {
  description = "Username for the local Administrator account."
  type        = string
}
variable "vm_admin_pw" {
  description = "Virtual machine local admin password."
  type        = string
  sensitive   = true
}
variable "vm_domain_join_upn" {
  description = "Domain join user principal name"
  sensitive   = true
}
variable "vm_domain_join_pw" {
  description = "Domain join password"
  type        = string
  sensitive   = true
}
variable "url_avd_agent" {
  description = "URL of AVD agent install module from https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts?restype=container&comp=list"
  type        = string
}
variable "url_ccm_agent" {
  description = "URL of custom powershell script"
  type        = string
}
variable "storage_account_name" {
  description = "storage account name"
  type        = string
}
variable "storage_account_key" {
  description = "storage account primary key"
  type        = string
  sensitive   = true
}
variable "log_analytics_workspace_id" {
  description = "ID of Log Analytics workspace"
  type        = string
}
variable "log_analytics_primary_shared_key" {
  description = "Primary shared key of Log Analytics workspace"
  type        = string
  sensitive   = true
}
variable "log_analytics_id" {
  description = "ID of Log Analytics workspace."
  type        = string
}
variable "eventhub_name" {
  description = "Name of event hub."
  type        = string
}
variable "eventhub_namespace_object" {
  description = "The Azure event hub namespace group object."
  type = object({
    name                = string
    resource_group_name = string
  })
}

# tags
# -------------------------------------------------------------------------------------------------------
variable "tags" {
  description = "Resource tags."
  type        = map(any)
}