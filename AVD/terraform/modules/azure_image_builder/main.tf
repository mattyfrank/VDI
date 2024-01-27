/* 
  __  __           _       _      
 |  \/  |         | |     | |     
 | \  / | ___   __| |_   _| | ___ 
 | |\/| |/ _ \ / _` | | | | |/ _ \
 | |  | | (_) | (_| | |_| | |  __/
 |_|  |_|\___/ \__,_|\__,_|_|\___|
                                  
Module for Azure Image Builder.

*/

terraform {
  required_version = ">=1.4.0"
}

# Managed user identity - identity used to access resources for builds
# -----------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "user_aib" {
  location            = var.location
  resource_group_name = var.resource_group_name
  name                = var.identity_name
  tags                = var.tags
}

# Role definition - create a custom role
# https://docs.microsoft.com/en-us/azure/role-based-access-control/resource-provider-operations
# -----------------------------------------------------------------------------
resource "azurerm_role_definition" "roledef_aib" {
  name        = "Azure Image Builder Service Image Creation ${var.env}"
  scope       = var.avdmgmt_resource_group_id
  description = "Image Builder access to create resources for the image build. Custom role created via Terraform."
  assignable_scopes = [
    "${var.network_resource_group_id}",
    "${var.images_resource_group_id}",
    "${var.avdmgmt_resource_group_id}"
  ]

  permissions {
    actions = [
      "Microsoft.Compute/galleries/read",
      "Microsoft.Compute/galleries/images/read",
      "Microsoft.Compute/galleries/images/versions/read",
      "Microsoft.Compute/galleries/images/versions/write",
      "Microsoft.Compute/images/write",
      "Microsoft.Compute/images/read",
      "Microsoft.Compute/images/delete",
      "Microsoft.Storage/storageAccounts/*/read",
      "Microsoft.Storage/storageAccounts/blobServices/generateUserDelegationKey/action",
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/subnets/join/action"
    ]
    data_actions = [
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read"
    ]
    not_actions = []
  }
}

# Assign identity - grant access to resources
# -----------------------------------------------------------------------------
## Management resource group
resource "azurerm_role_assignment" "assign_aib" {
  scope                = var.avdmgmt_resource_group_id
  role_definition_name = azurerm_role_definition.roledef_aib.name
  principal_id         = azurerm_user_assigned_identity.user_aib.principal_id
}

## Images resource group
resource "azurerm_role_assignment" "assign_aib_img" {
  scope                = var.images_resource_group_id
  role_definition_name = azurerm_role_definition.roledef_aib.name
  principal_id         = azurerm_user_assigned_identity.user_aib.principal_id
}

## Network resource group
resource "azurerm_role_assignment" "assign_aib_net" {
  scope                = var.network_resource_group_id
  role_definition_name = azurerm_role_definition.roledef_aib.name
  principal_id         = azurerm_user_assigned_identity.user_aib.principal_id
}