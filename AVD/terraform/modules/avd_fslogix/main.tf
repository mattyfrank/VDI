/* 
  __  __           _       _      
 |  \/  |         | |     | |     
 | \  / | ___   __| |_   _| | ___ 
 | |\/| |/ _ \ / _` | | | | |/ _ \
 | |  | | (_) | (_| | |_| | |  __/
 |_|  |_|\___/ \__,_|\__,_|_|\___|
                                  
Module for Azure Storage dedicated to FSlogix Profiles.

*/

terraform {
  required_version = ">=1.4.0"
}

## Storage Account User Profile
resource "azurerm_storage_account" "profilestorageaccount" {
  location                        = var.resource_group_location
  resource_group_name             = var.resource_group_name
  name                            = var.profile_storage_account_name
  account_tier                    = var.account_tier
  account_replication_type        = var.account_replication_type
  account_kind                    = var.account_kind
  min_tls_version                 = "TLS1_2"
  tags                            = var.tags
  allow_nested_items_to_be_public = false
  azure_files_authentication {
    directory_type = "AD"
    active_directory {
      domain_guid         = "domain_guid"
      domain_name         = "domain_name"
      domain_sid          = "domain_sid"
      forest_name         = "domain_forest_name"
      netbios_domain_name = "netbios_name"
      storage_sid         = var.storage_sid
    }
  }
  share_properties {
    smb {
      authentication_types = [
        "Kerberos" #,
        #"NTLMv2"
      ]
      channel_encryption_type = [
        "AES-128-CCM",
        "AES-128-GCM",
        "AES-256-GCM",
      ]
      kerberos_ticket_encryption_type = [
        "AES-256"
      ]
      versions = [
        "SMB3.0",
        "SMB3.1.1"
      ]
    }
  }
  # network_rules {
  #   default_action = "Deny"
  #   ip_rules       = []
  #   bypass         = ["AzureServices"]
  #   virtual_network_subnet_ids = [
  #     module.root.azurerm_subnet.subnet_desktop1.id,
  #     root.module.azurerm_subnet.subnet_desktop2.id,
  #     azurerm_subnet.subnet_desktop3.id
  #   ]
  # }
}

## File share - fslogix-profiles
resource "azurerm_storage_share" "fileshare" {
  name                 = "fslogix-profiles"
  storage_account_name = var.profile_storage_account_name
  depends_on           = [azurerm_storage_account.profilestorageaccount]
  enabled_protocol     = "SMB"
  quota                = var.storage_quota
}

/*
##STORAGE SCRATCH
#https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/group
## AZ AD Groups
resource "azuread_group" "storageuser_group" {
  display_name     = "example"
  owners           = [data.azuread_client_config.current.object_id]
  security_enabled = true
}
resource "azuread_group" "storageadmin_group" {
  display_name     = "example"
  owners           = [data.azuread_client_config.current.object_id]
  security_enabled = true
}

resource "azuread_group_member" "example" {
  group_object_id  = azuread_group.example.id
  member_object_id = data.azuread_user.example.id
}
resource "azuread_group_member" "example" {
  group_object_id  = azuread_group.example.id
  member_object_id = data.azuread_user.example.id
}
## Azure built-in roles
## https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
data "azurerm_role_definition" "storageadmin_role" {
  name = "Storage File Data SMB Share Elevated Contributor"
}
data "azurerm_role_definition" "storageuser_role" {
  name = "Storage File Data SMB Share Contributor"
}
#unexpected status 403 with OData error:Authorization_RequestDenied: Insufficient privileges to complete the operation
#AZAD Groups
data "azuread_group" "storageuser_group" { ##Not sure if this will work 
  #display_name = "VDI_AVD_Users"
  object_id = "AZAD_ObjectID"
}
data "azuread_group" "storageadmin_group" {
  #display_name = "VDI_AVD_Admins"
  object_id = "AZAD_ObjectID"
}

##Role Assignment
resource "azurerm_role_assignment" "admin_role" {
  scope              = azurerm_storage_account.profilestorageaccount.id
  role_definition_id = data.azurerm_role_definition.storageadmin_role.id
  principal_id       = data.azuread_group.storageadmin_group.id
}
resource "azurerm_role_assignment" "user__role" {
  scope              = azurerm_storage_account.profilestorageaccount.id
  role_definition_id = data.azurerm_role_definition.storageuser_role.id
  principal_id       = azuread_group.storageuser_group.id
}
*/