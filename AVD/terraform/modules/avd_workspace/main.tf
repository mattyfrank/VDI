/* 
  __  __           _       _      
 |  \/  |         | |     | |     
 | \  / | ___   __| |_   _| | ___ 
 | |\/| |/ _ \ / _` | | | | |/ _ \
 | |  | | (_) | (_| | |_| | |  __/
 |_|  |_|\___/ \__,_|\__,_|_|\___|

Module for Azure Virtual Desktop workspaces.

*/

terraform {
  required_version = ">=1.4.0"
}

# AVD Workspaces - Organization and presentation of desktop and applications
# -----------------------------------------------------------------------------
resource "azurerm_virtual_desktop_workspace" "workspace" {
  location            = var.resource_group_object.location
  resource_group_name = var.resource_group_object.name
  name                = var.workspace_name
  friendly_name       = var.workspace_friendly_name
  tags                = var.tags
}

# Diagnostics settings
# -----------------------------------------------------------------------------
## Get event hub auth rule
data "azurerm_eventhub_namespace_authorization_rule" "eventhub_auth" {
  name                = "RootManageSharedAccessKey"
  resource_group_name = var.resource_group_object.name
  namespace_name      = var.eventhub_namespace_name
}

## Send events from AVD workspace to Log Analytics Workspace and Event Hub
resource "azurerm_monitor_diagnostic_setting" "diag_log_analytics_workspace_ws" {
  name                           = "diag-log-analytics-workspace"
  target_resource_id             = azurerm_virtual_desktop_workspace.workspace.id
  log_analytics_workspace_id     = var.log_analytics_id
  eventhub_name                  = var.eventhub_name
  eventhub_authorization_rule_id = data.azurerm_eventhub_namespace_authorization_rule.eventhub_auth.id
  #https://docs.microsoft.com/en-us/azure/virtual-desktop/azure-monitor#workspace-diagnostic-settings
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
    category = "Feed"

    retention_policy {
      days    = 0
      enabled = false
    }
  }
}