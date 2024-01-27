variable "env" {
  type = string
  validation {
    condition     = var.env == "nonprod" || var.env == "prod"
    error_message = "Environment is either Prod or NonProd."
  }
}
variable "resource_group_name" {
  description = "The Azure resource group name to contain resources."
  type        = string
}
variable "resource_group_location" {
  description = "The Azure resource group location."
  type        = string
}
variable "profile_storage_account_name" {
  description = "Specifies the name of the storage account."
  type        = string
  validation {
    condition     = length(var.profile_storage_account_name) <= 15
    error_message = "Storage Account Name must be under 15 chars."
  }
}
variable "storage_sid" {
  description = "AZ storage account AD domain SID"
  type        = string
}
variable "storage_quota" {
  description = "AZ storage account size quota"
  type        = number
}
variable "account_tier" {
  description = "Defines the Tier to use for this storage account."
  type        = string
  default     = "Standard"
  validation {
    condition     = var.account_tier == "Standard" || var.account_tier == "Premium"
    error_message = "Storage Account must be Standard or Premium."
  }
}
variable "account_kind" {
  description = "Defines the type of replication to use for this storage account."
  type        = string
  validation {
    condition     = var.account_kind == "StorageV2" || var.account_kind == "FileStorage"
    error_message = "Storage Account Kind must be Storagev2 or FileStorage."
  }
}
variable "account_replication_type" {
  description = "Defines the type of replication to use for this storage account."
  type        = string
  default     = "LRS"
}
variable "tags" {
  description = "Resource tags."
  type        = map(any)
}
# variable "subnet_id_list" {
#   description = "List of Subnet IDs for Storage Access"
#   type = list
# }