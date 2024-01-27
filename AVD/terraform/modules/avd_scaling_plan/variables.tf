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
variable "resource_group" {
  description = "The Azure resource group name to store the role."
  type        = string
}
variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
}

variable "region" {
  description = "Azure region/location."
  type        = string
}

# tags
# -------------------------------------------------------------------------------------------------------
variable "tags" {
  description = "Resource tags."
  type        = map(any)
}