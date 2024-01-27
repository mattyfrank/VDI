/* 
  __  __           _       _      
 |  \/  |         | |     | |     
 | \  / | ___   __| |_   _| | ___ 
 | |\/| |/ _ \ / _` | | | | |/ _ \
 | |  | | (_) | (_| | |_| | |  __/
 |_|  |_|\___/ \__,_|\__,_|_|\___|

Module for Azure Virtual Desktop remoteapps.

*/
terraform {
  required_version = ">=1.4.0"
}

# RemoteApps Module
resource "azurerm_virtual_desktop_application" "remoteapp" {
  name                         = var.name
  application_group_id         = var.appgroup_id
  friendly_name                = var.friendly_name
  description                  = var.description
  path                         = var.path
  command_line_argument_policy = var.command_line_pol
  command_line_arguments       = var.command_line_args
  show_in_portal               = var.show_in_portal
  icon_path                    = var.icon_path
  icon_index                   = var.icon_index
}

