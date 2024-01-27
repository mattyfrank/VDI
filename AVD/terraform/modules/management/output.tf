output "log_analytics" {
  value       = azurerm_log_analytics_workspace.loganalytics
  description = "Log analytics resource"
}

output "resource_group" {
  value       = azurerm_resource_group.rg
  description = "Resource group resource"
}

output "event_hub" {
  value       = azurerm_eventhub.eventhub
  description = "Event hub resource"
}

output "eventhub_namespace" {
  value       = azurerm_eventhub_namespace.eventhubnamespace
  description = "Event hub namespace resource"
}

output "storage_account" {
  value       = azurerm_storage_account.storageaccount
  description = "Storage account resource"
}

output "storage_account_primary_access_key" {
  value = azurerm_storage_account.storageaccount.primary_access_key
}