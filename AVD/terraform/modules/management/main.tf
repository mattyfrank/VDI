/* 
  __  __           _       _      
 |  \/  |         | |     | |     
 | \  / | ___   __| |_   _| | ___ 
 | |\/| |/ _ \ / _` | | | | |/ _ \
 | |  | | (_) | (_| | |_| | |  __/
 |_|  |_|\___/ \__,_|\__,_|_|\___|
                                  
Module for Azure Virtual Desktop management resources.

*/

terraform {
  required_version = ">=1.4.0"
}

# Resource group - group containing non-pool specific resources
# -----------------------------------------------------------------------------
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.resource_group_location
  tags     = var.tags
}

# Log analytics workspace - AVD logs including auditing, management and access
# -----------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "loganalytics" {
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  name                = var.log_analytics_name
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_analytics_retention_in_days
  tags                = var.tags
}

# Event hub - forwards AVD events to Splunk
# -----------------------------------------------------------------------------
## Namespace
resource "azurerm_eventhub_namespace" "eventhubnamespace" {
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  name                = var.event_hub_namespace
  sku                 = "Standard"
  capacity            = 1
  tags                = var.tags
}

## Hub
resource "azurerm_eventhub" "eventhub" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = var.event_hub_name
  namespace_name      = azurerm_eventhub_namespace.eventhubnamespace.name
  partition_count     = 1
  message_retention   = var.event_hub_name_message_retention
}

# Storage account - image content
# -----------------------------------------------------------------------------
resource "azurerm_storage_account" "storageaccount" {
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  name                     = var.storage_account_name
  account_tier             = "Standard"
  account_replication_type = "ZRS"
  min_tls_version          = "TLS1_2"
  tags                     = var.tags
}

# ## File share - image content
# resource "azurerm_storage_share" "fileshare" {
#   name                 = "images_content"
#   storage_account_name = azurerm_storage_account.storageaccount.name
#   quota                = 100
# }

# Blob - image content
resource "azurerm_storage_container" "images_content" {
  name                  = "images-content"
  storage_account_name  = azurerm_storage_account.storageaccount.name
  container_access_type = "private"
}

# Blob - deployment scripts
resource "azurerm_storage_container" "deployment_scripts" {
  name                  = "deployment-scripts"
  storage_account_name  = azurerm_storage_account.storageaccount.name
  container_access_type = "private"
}

# Scripts are managed with the set-blobcontents.ps1 script
# resource "azurerm_storage_blob" "file_vm_script" {
#   name                   = "Add-LocalAdmin.ps1"
#   storage_account_name   = azurerm_storage_account.storageaccount.name
#   storage_container_name = azurerm_storage_container.deployment_scripts.name
#   type                   = "Block"
#   source                 = "./scripts/Add-LocalAdmin.ps1"
# }