output "host_pool" {
  value       = azurerm_virtual_desktop_host_pool.hostpool
  description = "Host pool resource"
}

output "resource_group" {
  value       = azurerm_resource_group.rg
  description = "Resource group resource"
}