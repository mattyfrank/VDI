/* 
  __  __           _       _      
 |  \/  |         | |     | |     
 | \  / | ___   __| |_   _| | ___ 
 | |\/| |/ _ \ / _` | | | | |/ _ \
 | |  | | (_) | (_| | |_| | |  __/
 |_|  |_|\___/ \__,_|\__,_|_|\___|

Module for Azure Virtual Desktop session host pools. Creates a resource 
group containing all session host resources. Creates the virtual desktops and registers 
them with the pool.

*/

terraform {
  required_version = ">=1.4.0"
}

locals {
  resource_group_name = lower("rg-avd-${var.env}-pool-${var.host_pool_name}-${var.location}")
  host_pool_name      = lower("vdpool-${var.env}-${var.host_pool_type}-${var.host_pool_name}-${var.location}")
  domain_ou_path      = "OU=${var.host_pool_name},OU=${var.host_pool_type},OU=${var.env},OU=AVD,OU=CorpClient,OU=Workstations,DC=DOMAIN,DC=net"
  provisionID         = (var.env == "prod" ? "P01228FF" : "P01229EF") #(Prod="P01228FF"||NonProd="P01229EF")
}

# Resource group
# -----------------------------------------------------------------------------
resource "azurerm_resource_group" "rg" {
  name     = local.resource_group_name
  location = var.location
  tags     = var.tags
}

# AVD Session Host Pool
# -----------------------------------------------------------------------------
## Registration key rotation
resource "time_rotating" "token" {
  rotation_days = 30
}

## Subnet info
data "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  virtual_network_name = var.subnet_vnet_name
  resource_group_name  = var.subnet_resource_group
}

## Host Pool
resource "azurerm_virtual_desktop_host_pool" "hostpool" {
  location                         = azurerm_resource_group.rg.location
  resource_group_name              = azurerm_resource_group.rg.name
  name                             = local.host_pool_name
  type                             = title(var.host_pool_type)
  custom_rdp_properties            = var.pool_set_rdp_properties
  load_balancer_type               = var.pool_set_load_balancer_type
  maximum_sessions_allowed         = (var.host_pool_type == "pooled" ? var.pool_set_max_sessions : null)
  personal_desktop_assignment_type = (var.host_pool_type == "personal" ? var.personal_desktop_assignment_type : null)
  validate_environment             = var.pool_set_validate
  start_vm_on_connect              = var.pool_set_autostart_vm
  tags                             = var.tags
  scheduled_agent_updates {
    enabled  = true
    timezone = "Pacific Standard Time"
    schedule {
      day_of_week = "Saturday"
      hour_of_day = 1
    }    
    schedule {
      day_of_week = "Saturday"
      hour_of_day = 3
    }
  }
}

## Host Pool Registration
resource "azurerm_virtual_desktop_host_pool_registration_info" "registration_info" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.hostpool.id
  expiration_date = time_rotating.token.rotation_rfc3339
}

## Network card
resource "azurerm_network_interface" "nic" {
  count               = var.session_host_count
  name                = "${var.session_host_prefix}-${count.index + 1}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = var.ip_allocation_type
  }
}
## Virtual machine
resource "azurerm_windows_virtual_machine" "vm" {
  count               = var.session_host_count
  name                = "${var.session_host_prefix}-${count.index + 1}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  timezone            = "Pacific Standard Time"
  size                = var.session_host_size
  admin_username      = var.vm_admin_username
  admin_password      = var.vm_admin_pw
  tags                = var.tags
  license_type        = "Windows_Client"
  network_interface_ids = [
    azurerm_network_interface.nic.*.id[count.index],
  ]

  source_image_id = var.shared_image_id

  lifecycle {
    ignore_changes = [
      source_image_id
    ]
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.session_host_disk_type
    disk_size_gb         = var.session_host_disk_size_gb
  }
}
##VM Extensions
#Domain Join
resource "azurerm_virtual_machine_extension" "ext_domainJoin" {
  count                      = var.session_host_count
  name                       = "${var.session_host_prefix}-${count.index + 1}-domainJoin"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm.*.id[count.index]
  publisher                  = "Microsoft.Compute"
  type                       = "JsonADDomainExtension"
  type_handler_version       = "1.3"
  auto_upgrade_minor_version = true
  depends_on                 = [azurerm_windows_virtual_machine.vm]
  lifecycle {
    ignore_changes = [settings, protected_settings]
  }
  settings = jsonencode({
    "Name" : "DOMAIN.net",
    "OUPath" : "${local.domain_ou_path}",
    "User" : "${var.vm_domain_join_upn}",
    "Restart" : "true",
    "Options" : "3"
  })
  protected_settings = jsonencode({
    "Password" : "${var.vm_domain_join_pw}"
  })
}
/*
#Daily VM ShutDown Schedule
resource "azurerm_dev_test_global_vm_shutdown_schedule" "ext_daily_shutdown" {
  count                 = var.session_host_count
  depends_on            = [azurerm_virtual_machine_extension.ext_domainJoin]
  virtual_machine_id    = azurerm_windows_virtual_machine.vm.*.id[count.index]
  location              = azurerm_resource_group.rg.location
  enabled               = true
  daily_recurrence_time = "2100"
  timezone              = "Pacific Standard Time"
  notification_settings {
    enabled         = false
    time_in_minutes = "30"
    webhook_url     = "AVDadmin@DOMAIN.com"
  }
}
*/
#Microsoft Monitoring Dependency
resource "azurerm_virtual_machine_extension" "monitor_dependency-agent" {
  count                      = var.session_host_count
  depends_on                 = [azurerm_virtual_machine_extension.ext_domainJoin]
  name                       = "${var.session_host_prefix}-${count.index + 1}-monitorDepAgent"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm.*.id[count.index]
  publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                       = "DependencyAgentWindows"
  type_handler_version       = "9.10"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
  {
    "workspaceId" : "${var.log_analytics_workspace_id}"
  }
  SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
  {
    "workspaceKey" : "${var.log_analytics_primary_shared_key}"
  }
  PROTECTED_SETTINGS
}
#Log analytics
resource "azurerm_virtual_machine_extension" "ext_loganalytics" {
  count                      = var.session_host_count
  depends_on                 = [azurerm_virtual_machine_extension.monitor_dependency-agent]
  name                       = "${var.session_host_prefix}-${count.index + 1}-la"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm.*.id[count.index]
  publisher                  = "Microsoft.EnterpriseCloud.Monitoring"
  type                       = "MicrosoftMonitoringAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    "workspaceId" : "${var.log_analytics_workspace_id}"
  })

  protected_settings = jsonencode({
    "workspaceKey" : "${var.log_analytics_primary_shared_key}"
  })
}
#Azure Monitoring Agent
resource "azurerm_virtual_machine_extension" "azure_monitor_agent" {
  count                      = var.session_host_count
  depends_on                 = [azurerm_virtual_machine_extension.monitor_dependency-agent]
  name                       = "${var.session_host_prefix}-${count.index + 1}-azmonitorextension"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm.*.id[count.index]
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.2"
  auto_upgrade_minor_version = "true"
  automatic_upgrade_enabled  = "true"
}
# resource "time_sleep" "wait_5_minutes" {
#   count           = var.session_host_count
#   depends_on      = [azurerm_virtual_machine_extension.azure_monitor_agent]
#   create_duration = "5m"
# }
#CM Setup BootStrap
resource "azurerm_virtual_machine_extension" "ext_ccm_bootstrap" {
  count                = var.session_host_count
  # depends_on           = [time_sleep.wait_5_minutes]
  depends_on           = [azurerm_virtual_machine_extension.azure_monitor_agent]
  name                 = "${var.session_host_prefix}-${count.index + 1}-ccm"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.*.id[count.index]
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  timeouts {
    create = "90m"
  }
  settings           = <<SETTINGS
  {
    "commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted -File cmbootstrap.ps1 -ProvisionID ${local.provisionID}"
  }
  SETTINGS
  protected_settings = <<PROTECTED_SETTINGS
  {
    "storageAccountName": "${var.storage_account_name}",
    "storageAccountKey": "${var.storage_account_key}",
    "fileUris": ["${var.url_ccm_agent}"]
  }
  PROTECTED_SETTINGS
}
#PowerShell DSC connect to session host pool
resource "azurerm_virtual_machine_extension" "ext_wvdreg" {
  count                      = var.session_host_count
  depends_on                 = [azurerm_virtual_machine_extension.ext_ccm_bootstrap]
  name                       = "${var.session_host_prefix}-${count.index + 1}-dsc"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm.*.id[count.index]
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.83"
  auto_upgrade_minor_version = true
  lifecycle {
    ignore_changes = [settings]
  }
  settings = jsonencode({
    "modulesUrl" : "${var.url_avd_agent}",
    "configurationFunction" : "Configuration.ps1\\AddSessionHost",
    "properties" : {
      "hostPoolName" : "${azurerm_virtual_desktop_host_pool.hostpool.name}",
      "registrationInfoToken" : "${azurerm_virtual_desktop_host_pool_registration_info.registration_info.token}"
    }
  })
}
# Diagnostics settings
# -----------------------------------------------------------------------------
## Get event hub auth rule
data "azurerm_eventhub_namespace_authorization_rule" "eventhub_auth" {
  name                = "RootManageSharedAccessKey"
  resource_group_name = var.eventhub_namespace_object.resource_group_name
  namespace_name      = var.eventhub_namespace_object.name
}
# Send events from AVD Host Pool to Log Analytics Workspace
resource "azurerm_monitor_diagnostic_setting" "diag_log_analytics_workspace_appgroup" {
  name                           = "diag-log-analytics-workspace"
  target_resource_id             = azurerm_virtual_desktop_host_pool.hostpool.id
  log_analytics_workspace_id     = var.log_analytics_id
  eventhub_name                  = var.eventhub_name
  eventhub_authorization_rule_id = data.azurerm_eventhub_namespace_authorization_rule.eventhub_auth.id
  #https://docs.microsoft.com/en-us/azure/virtual-desktop/azure-monitor#host-pool-diagnostic-settings
  enabled_log {
    category = "Checkpoint"

    retention_policy {
      days    = 0
      enabled = false
    }
  }

  enabled_log {
    category = "Error"

    retention_policy {
      days    = 0
      enabled = false
    }
  }

  enabled_log {
    category = "Management"

    retention_policy {
      days    = 0
      enabled = false
    }
  }

  enabled_log {
    category = "Connection"

    retention_policy {
      days    = 0
      enabled = false
    }
  }

  enabled_log {
    category = "HostRegistration"

    retention_policy {
      days    = 0
      enabled = false
    }
  }

  enabled_log {
    category = "AgentHealthStatus"

    retention_policy {
      days    = 0
      enabled = false
    }
  }

  enabled_log {
    category = "NetworkData"

    retention_policy {
      days    = 0
      enabled = false
    }
  }

  enabled_log {
    category = "SessionHostManagement"

    retention_policy {
      days    = 0
      enabled = false
    }
  }
}