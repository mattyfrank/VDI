output "management_resource_group_name" {
  value       = module.mgmt.resource_group.name
  description = "Management resource group name"
}

output "storage_account_name" {
  value       = module.mgmt.storage_account.name
  description = "Storage account name"
}

output "container_name" {
  value       = module.mgmt.container.name
  description = "Storage account container name"
}