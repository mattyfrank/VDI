# AVD Applications
# -------------------------------------------------------------------------------------------------------
variable "appgroup_id" {
  description = "Resource ID for an Application Group to associate with the RemoteApps. Changing the ID forces a new resource to be created"
  type        = string
}
variable "name" {
  description = "The name of the Virtual Desktop Application. Changing the name forces a new resource to be created. Must be Letters, Numbers, Hyphen"
  type        = string
}
variable "friendly_name" {
  description = "Remote Apps Friendly Name."
  type        = string
}
variable "description" {
  description = "Remote Apps Description."
  type        = string
}
variable "path" {
  description = "The file path location of the app on the Virtual Desktop OS"
  type        = string
}
variable "command_line_args" {
  description = "Command Line Arguments for Virtual Desktop Application"
  type        = string
}
variable "command_line_pol" {
  description = "DoNotAllow, Allow, Require"
  type        = string
}
variable "show_in_portal" {
  description = "true/false"
  type        = string
  default     = "true"
}
variable "icon_path" {
  description = "Path for an icon which will be used for this Virtual Desktop Application."
  type        = string
}
variable "icon_index" {
  type    = number
  default = 0
}
