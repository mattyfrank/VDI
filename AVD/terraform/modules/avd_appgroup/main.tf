/* 
  __  __           _       _      
 |  \/  |         | |     | |     
 | \  / | ___   __| |_   _| | ___ 
 | |\/| |/ _ \ / _` | | | | |/ _ \
 | |  | | (_) | (_| | |_| | |  __/
 |_|  |_|\___/ \__,_|\__,_|_|\___|

Module for Azure Virtual Desktop application groups.

*/

terraform {
  required_version = ">=1.4.0"
}

# AVD Application Group
# -----------------------------------------------------------------------------
resource "azurerm_virtual_desktop_application_group" "appgroup" {
  location                     = var.resource_group_object.location
  resource_group_name          = var.resource_group_object.name
  name                         = var.appgroup_name
  default_desktop_display_name = var.default_desktop_name
  type                         = var.appgroup_type
  host_pool_id                 = var.desktop_pool_id
  tags                         = var.tags
}

## Group Assignment
resource "azurerm_role_assignment" "assignpool" {
  for_each             = var.group_assignment_principal_id
  scope                = azurerm_virtual_desktop_application_group.appgroup.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = each.value
}

## Workspace association
resource "azurerm_virtual_desktop_workspace_application_group_association" "workspaceassociate" {
  workspace_id         = var.workspace_id
  application_group_id = azurerm_virtual_desktop_application_group.appgroup.id
}

# Diagnostics settings
# -----------------------------------------------------------------------------
## Get event hub auth rule
data "azurerm_eventhub_namespace_authorization_rule" "eventhub_auth" {
  name                = "RootManageSharedAccessKey"
  resource_group_name = var.eventhub_rg_name
  namespace_name      = var.eventhub_namespace_name
}

# Send events from AVD application group to Log Analytics Workspace
resource "azurerm_monitor_diagnostic_setting" "diag_log_analytics_workspace_appgroup" {
  name                           = "diag-log-analytics-workspace"
  target_resource_id             = azurerm_virtual_desktop_application_group.appgroup.id
  log_analytics_workspace_id     = var.log_analytics_id
  eventhub_name                  = var.eventhub_name
  eventhub_authorization_rule_id = data.azurerm_eventhub_namespace_authorization_rule.eventhub_auth.id

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
}