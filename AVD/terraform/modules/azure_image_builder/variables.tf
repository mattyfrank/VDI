# Variables for main.tf file in azure_image_builder module. These get passed in from top main.tf calling 
# the module.

variable "env" {
  description = "Environment (prod, nonprod)"
  type        = string

  validation {
    condition     = contains(["prod", "nonprod"], var.env)
    error_message = "Valid values for var: env are (prod, nonprod)."
  }
}

# managed identity
# -------------------------------------------------------------------------------------------------------
variable "identity_name" {
  description = "Name of managed identity."
  type        = string
}
variable "resource_group_name" {
  description = "The Azure resource group name to store managed identity."
  type        = string
}
variable "location" {
  description = "Location of managed identity."
  type        = string
}

# assignment scopes
# -------------------------------------------------------------------------------------------------------
variable "network_resource_group_id" {
  description = "Resource ID of network resource group."
  type        = string
}
variable "images_resource_group_id" {
  description = "Resource ID of images resource group."
  type        = string
}
variable "avdmgmt_resource_group_id" {
  description = "Resource ID of AVD management group."
  type        = string
}

# tags
# -------------------------------------------------------------------------------------------------------
variable "tags" {
  description = "Resource tags."
  type        = map(any)
}