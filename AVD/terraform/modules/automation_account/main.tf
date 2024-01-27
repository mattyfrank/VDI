/* 
  __  __           _       _      
 |  \/  |         | |     | |     
 | \  / | ___   __| |_   _| | ___ 
 | |\/| |/ _ \ / _` | | | | |/ _ \
 | |  | | (_) | (_| | |_| | |  __/
 |_|  |_|\___/ \__,_|\__,_|_|\___|
                                  
Module for Azure Virtual Desktop automation account resources.

IMPORTANT: Manual creation of the Run As Account is required after Azure
Automation account is deployed.

*/

terraform {
  required_version = ">=1.4.0"
}

# Azure automation account
# -----------------------------------------------------------------------------
resource "azurerm_automation_account" "aa_avd" {
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  name                = var.azure_automation_account_name
  sku_name            = "Basic"
  tags                = var.tags
}

# Log analytics workspace - used for hybrid worker
# -----------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "loganalytics_hw" {
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  name                = var.log_analytics_name
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_analytics_retention_in_days
  tags                = var.tags
}

resource "azurerm_log_analytics_solution" "loganalytics_solution_hw" {
  solution_name         = "AzureAutomation"
  location              = var.resource_group_location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.loganalytics_hw.id
  workspace_name        = azurerm_log_analytics_workspace.loganalytics_hw.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/AzureAutomation"
  }
}

# Runbooks
# -----------------------------------------------------------------------------
## Runbook - Azure automation module updater
resource "azurerm_automation_runbook" "runbook_update_modules" {
  name                    = "Update-AutomationAzureModulesForAccount"
  location                = var.resource_group_location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_avd.name
  log_verbose             = "false"
  log_progress            = "true"
  description             = "Updates Azure PowerShell modules imported into an Azure Automation account."
  runbook_type            = "PowerShell"

  publish_content_link {
    uri = "https://raw.githubusercontent.com/microsoft/AzureAutomation-Account-Modules-Update/master/Update-AutomationAzureModulesForAccount.ps1"
  }
}

### Run module updater daily
resource "azurerm_automation_job_schedule" "runbook_update_modules_job" {
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_avd.name
  schedule_name           = azurerm_automation_schedule.aa_schedule_daily.name
  runbook_name            = azurerm_automation_runbook.runbook_update_modules.name

  parameters = {
    resourcegroupname     = var.resource_group_name
    automationaccountname = azurerm_automation_account.aa_avd.name
    azuremoduleclass      = "az"
  }
}

## Runbook - Removes computer from pool and deletes resources from Azure
data "local_file" "file_remove_avdcomputer" {
  filename = "${path.module}/runbooks/Remove-AVDComputer.ps1"
}

resource "azurerm_automation_runbook" "runbook_remove_avdcomputer" {
  name                    = "Remove-AVDComputer"
  location                = var.resource_group_location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_avd.name
  log_verbose             = "false"
  log_progress            = "true"
  description             = "Deletes AVD computer, storage disk, network interface, and disassociates from session host pool."
  runbook_type            = "PowerShell"

  content = data.local_file.file_remove_avdcomputer.content
}

## Runbook - Creates a new AVD VM for personal pools
data "local_file" "file_new_avdcomputer" {
  filename = "${path.module}/runbooks/New-AVDComputer.ps1"
}

resource "azurerm_automation_runbook" "runbook_new_avdcomputer" {
  name                    = "New-AVDComputer"
  location                = var.resource_group_location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_avd.name
  log_verbose             = "false"
  log_progress            = "true"
  description             = "Creates a new AVD computer, storage disk, network interface, and joins to session host pool."
  runbook_type            = "PowerShell"

  content = data.local_file.file_new_avdcomputer.content
}

## Runbook - Get assigned dev Horizon desktop
data "local_file" "file_get_horizondesktop" {
  filename = "${path.module}/runbooks/Get-HorizonDesktop.ps1"
}

resource "azurerm_automation_runbook" "runbook_get_horizondesktop" {
  name                    = "Get-HorizonDesktop"
  location                = var.resource_group_location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_avd.name
  log_verbose             = "false"
  log_progress            = "true"
  description             = "Run from hybrid worker, gets assigned Horizon desktop."
  runbook_type            = "PowerShell"

  content = data.local_file.file_get_horizondesktop.content
}

## Runbook - Add user to AD group
data "local_file" "file_add_usertogroup" {
  filename = "${path.module}/runbooks/Add-UserToADGroup.ps1"
}

resource "azurerm_automation_runbook" "runbook_add_usertogroup" {
  name                    = "Add-UserToADGroup"
  location                = var.resource_group_location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_avd.name
  log_verbose             = "false"
  log_progress            = "true"
  description             = "Run from hybrid worker, adds user to AD group."
  runbook_type            = "PowerShell"
  content                 = data.local_file.file_add_usertogroup.content
}

## Runbook - Remove user from AD group
data "local_file" "file_remove_userfromgroup" {
  filename = "${path.module}/runbooks/Remove-UserFromADGroup.ps1"
}

resource "azurerm_automation_runbook" "runbook_remove_userfromgroup" {
  name                    = "Remove-UserFromADGroup"
  location                = var.resource_group_location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_avd.name
  log_verbose             = "false"
  log_progress            = "true"
  description             = "Run from hybrid worker, removes user from AD group."
  runbook_type            = "PowerShell"
  content                 = data.local_file.file_remove_userfromgroup.content
}

## Runbook - Remove user from AD group
data "local_file" "file_restart_onpremvm" {
  filename = "${path.module}/runbooks/Restart-OnPremVM.ps1"
}

resource "azurerm_automation_runbook" "runbook_restart_onpremvm" {
  name                    = "Restart-OnPremVM"
  location                = var.resource_group_location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_avd.name
  log_verbose             = "false"
  log_progress            = "true"
  description             = "Run from hybrid worker, restarts on prem VM"
  runbook_type            = "PowerShell"
  content                 = data.local_file.file_restart_onpremvm.content
}

# Runbook modules
# -----------------------------------------------------------------------------
resource "azurerm_automation_module" "aa_module_azaccounts" {
  name                    = "Az.Accounts"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_avd.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Accounts"
  }
}

resource "azurerm_automation_module" "aa_module_azstorage" {
  name                    = "Az.Storage"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_avd.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Storage"
  }
}

resource "azurerm_automation_module" "aa_module_azcompute" {
  name                    = "Az.Compute"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_avd.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Compute"
  }
}

resource "azurerm_automation_module" "aa_module_azdesktopvirtualization" {
  name                    = "Az.DesktopVirtualization"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_avd.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.DesktopVirtualization"
  }
}

resource "azurerm_automation_module" "aa_module_azresources" {
  name                    = "Az.Resources"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_avd.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Resources"
  }
}

resource "azurerm_automation_module" "aa_module_azmanagedserviceidentity" {
  name                    = "Az.ManagedServiceIdentity"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_avd.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.ManagedServiceIdentity"
  }
}

# Runbook scheduling
# -----------------------------------------------------------------------------
resource "azurerm_automation_schedule" "aa_schedule_daily" {
  name                    = "Daily"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_avd.name
  frequency               = "Day"
  interval                = 1
  timezone                = "America/Los_Angeles"
  description             = "Run daily"
}

# Runbook variables
# -----------------------------------------------------------------------------
resource "azurerm_automation_variable_string" "var_domainjoinpw" {
  name                    = "var_domain_join_pw"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_avd.name
  encrypted               = true
  value                   = var.domain_join_pw
}

resource "azurerm_automation_variable_string" "var_localadminpw" {
  name                    = "var_local_admin_pw"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_avd.name
  encrypted               = true
  value                   = var.local_admin_pw
}

resource "azurerm_automation_variable_string" "var_storageaccountkey" {
  name                    = "var_storage_account_key"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_avd.name
  encrypted               = true
  value                   = var.storage_account_key
}

resource "azurerm_automation_variable_string" "var_storageaccountname" {
  name                    = "var_storage_account_name"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_avd.name
  value                   = var.storage_account_name
}

# Runbook credentials
# -----------------------------------------------------------------------------
resource "azurerm_automation_credential" "cred_horizonapi" {
  name                    = "cred_horizon_api"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_avd.name
  username                = "DOMAIN.net\\horizonapi"
  password                = var.horizon_api_pw
  description             = "Credential to access Horizon API"
}

resource "azurerm_automation_credential" "cred_hybridworker" {
  name                    = "cred_hybrid_worker"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_avd.name
  username                = "DOMAIN.net\\hybridworker1"
  password                = var.hybrid_worker_pw
  description             = "Credential to access on prem resources"
}

# Hybrid workers
# -----------------------------------------------------------------------------
## Build system info
locals {
  system_name_type = (var.env == "prod" ? "P" : "N")
  system_ou_name   = (var.env == "prod" ? "Prod" : "NonProd")
}

locals {
  pool_type = "hw"
  vm_prefix = upper("vmapp-${local.system_name_type}")
}

## Virtual machine scale set
resource "azurerm_windows_virtual_machine_scale_set" "vmss_hw" {
  name                                              = "vmss-avd-${var.env}-hybridworker-${var.resource_group_location}"
  computer_name_prefix                              = local.vm_prefix
  location                                          = var.resource_group_location
  resource_group_name                               = var.resource_group_name
  sku                                               = "Standard_B2s"
  instances                                         = 1
  enable_automatic_updates                          = true
  timezone                                          = "Pacific Standard Time"
  admin_username                                    = var.local_admin_username
  admin_password                                    = var.local_admin_pw
  do_not_run_extensions_on_overprovisioned_machines = true
  tags                                              = var.tags
  upgrade_mode                                      = "Manual" #"Automatic"

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-10"
    sku       = "win10-21h2-ent"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
    disk_size_gb         = "127"
  }

  network_interface {
    name    = "hybridworker-vmss-nic"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = var.hybrid_worker_subnet_id
    }
  }

  lifecycle {
    ignore_changes = [instances]
  }
}

## VMSS Extension - join domain
resource "azurerm_virtual_machine_scale_set_extension" "vmss_ext_domainJoin" {
  name                         = "vmss-domainjoin"
  virtual_machine_scale_set_id = azurerm_windows_virtual_machine_scale_set.vmss_hw.id
  publisher                    = "Microsoft.Compute"
  type                         = "JsonADDomainExtension"
  type_handler_version         = "1.3"
  auto_upgrade_minor_version   = true
  settings = jsonencode({
    "Name"    = "DOMAIN.net"
    "OUPath"  = "OU=${local.pool_type},OU=Pooled,OU=${local.system_ou_name},OU=AVD,OU=Workstations,DC=DOMAIN,DC=net",
    "User"    = "${var.domain_join_upn}",
    "Restart" = "true",
    "Options" = "3"
  })
  protected_settings = jsonencode({
    "Password" = "${var.domain_join_pw}"
  })
}

## VMSS Extension - log analytics
resource "azurerm_virtual_machine_scale_set_extension" "vmss_ext_loganalytics" {
  name                         = "vmss-loganalytics"
  virtual_machine_scale_set_id = azurerm_windows_virtual_machine_scale_set.vmss_hw.id
  publisher                    = "Microsoft.EnterpriseCloud.Monitoring"
  type                         = "MicrosoftMonitoringAgent"
  type_handler_version         = "1.0"
  auto_upgrade_minor_version   = true
  settings = jsonencode({
    "workspaceId" = "${azurerm_log_analytics_workspace.loganalytics_hw.workspace_id}"
  })
  protected_settings = jsonencode({
    "workspaceKey" = "${azurerm_log_analytics_workspace.loganalytics_hw.primary_shared_key}"
  })
}

## VMSS Extension - add hybrid worker custom script
locals {
  PSScriptName = "Add-HybridWorker.ps1"
  hwGroupName  = "HybridWorkerGroup${var.env}"
  hwEndPoint   = azurerm_automation_account.aa_avd.dsc_server_endpoint
  hwToken      = azurerm_automation_account.aa_avd.dsc_primary_access_key
}

locals {
  PSScript            = try(file("./scripts/${local.PSScriptName}"), null)
  base64EncodedScript = base64encode(local.PSScript)
}

resource "azurerm_virtual_machine_scale_set_extension" "vmss_ext_script_hw" {
  name                         = "vmss-customscript-hw"
  virtual_machine_scale_set_id = azurerm_windows_virtual_machine_scale_set.vmss_hw.id
  publisher                    = "Microsoft.Compute"
  type                         = "CustomScriptExtension"
  type_handler_version         = "1.10"
  auto_upgrade_minor_version   = true
  provision_after_extensions   = [azurerm_virtual_machine_scale_set_extension.vmss_ext_loganalytics.name]
  protected_settings = jsonencode({
    "commandToExecute" = "powershell.exe -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${local.base64EncodedScript}')) | Out-File -filepath ${local.PSScriptName}\" && powershell.exe -ExecutionPolicy Unrestricted -File ${local.PSScriptName} -GroupName ${local.hwGroupName} -EndPoint ${local.hwEndPoint} -Token ${local.hwToken}"
  })

  lifecycle {
    ignore_changes = [settings]
  }
}

## Autoscale policy
resource "azurerm_monitor_autoscale_setting" "autoscale_vmss" {
  name                = "vmss-autoscale"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  target_resource_id  = azurerm_windows_virtual_machine_scale_set.vmss_hw.id
  tags                = var.tags

  profile {
    name = "Autoscale 15 < CPU > 75"

    capacity {
      default = 1
      minimum = 1
      maximum = 3
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_windows_virtual_machine_scale_set.vmss_hw.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_windows_virtual_machine_scale_set.vmss_hw.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }
}