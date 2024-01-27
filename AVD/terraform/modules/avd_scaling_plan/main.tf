/* 
  __  __           _       _      
 |  \/  |         | |     | |     
 | \  / | ___   __| |_   _| | ___ 
 | |\/| |/ _ \ / _` | | | | |/ _ \
 | |  | | (_) | (_| | |_| | |  __/
 |_|  |_|\___/ \__,_|\__,_|_|\___|
                                  
Module for Scaling Plans.

*/

terraform {
  required_version = ">=1.1.0"
}

# Role definition - create a custom role
# -----------------------------------------------------------------------------
resource "azurerm_role_definition" "custom_role" {
  name        = "AutoScale"
  scope       = var.resource_group_id
  description = "Custom role created via Terraform."
  assignable_scopes = [
    var.subscription_id
  ]

  permissions {
    actions = [
        "Microsoft.Insights/eventtypes/values/read",
        "Microsoft.Compute/virtualMachines/deallocate/action",
        "Microsoft.Compute/virtualMachines/restart/action",
        "Microsoft.Compute/virtualMachines/powerOff/action",
        "Microsoft.Compute/virtualMachines/start/action",
        "Microsoft.Compute/virtualMachines/read",
        "Microsoft.DesktopVirtualization/hostpools/read",
        "Microsoft.DesktopVirtualization/hostpools/write",
        "Microsoft.DesktopVirtualization/hostpools/sessionhosts/read",
        "Microsoft.DesktopVirtualization/hostpools/sessionhosts/write",
        "Microsoft.DesktopVirtualization/hostpools/sessionhosts/usersessions/delete",
        "Microsoft.DesktopVirtualization/hostpools/sessionhosts/usersessions/read",
        "Microsoft.DesktopVirtualization/hostpools/sessionhosts/usersessions/sendMessage/action"
    ]
    data_actions = []
    not_actions = []
  }
}

# Assign identity - grant access to resources
# -----------------------------------------------------------------------------
resource "azurerm_role_assignment" "assign_role" {
  scope                = var.subscription_id
  role_definition_name = azurerm_role_definition.custom_role.id
  principal_id         = "####" #Assign to the WVD Application ObjectID 
}
resource "azurerm_role_assignment" "assign_role" {
  scope                = var.subscription_id
  role_definition_name = azurerm_role_definition.custom_role.id
  principal_id         = "####"
}


# Create new scaling plan
resource "azurerm_virtual_desktop_scaling_plan" "scaling_plan" {
  name                = "AutoScalePlan-Weekday-${var.env}"
  location            = var.region
  resource_group_name = var.resource_group.name
  time_zone           = "Pacific Standard Time"
  schedule {
    name                                 = "Weekdays"
    days_of_week                         = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
    ramp_up_start_time                   = "04:00"
    ramp_up_load_balancing_algorithm     = "DepthFirst"
    ramp_up_minimum_hosts_percent        = 20
    ramp_up_capacity_threshold_percent   = 50
    peak_start_time                      = "05:00"
    peak_load_balancing_algorithm        = "DepthFirst"
    ramp_down_start_time                 = "18:00"
    ramp_down_load_balancing_algorithm   = "DepthFirst"
    ramp_down_minimum_hosts_percent      = 20
    ramp_down_force_logoff_users         = false
    ramp_down_wait_time_minutes          = 45
    ramp_down_notification_message       = "Please log off in the next 45 minutes, or risk loosing work."
    ramp_down_capacity_threshold_percent = 30
    ramp_down_stop_hosts_when            = "ZeroActiveSessions" //"ZeroSessions"
    off_peak_start_time                  = "19:00"
    off_peak_load_balancing_algorithm    = "DepthFirst"
  }
}