/* 
                                __      ___      _               _ 
     /\                         \ \    / (_)    | |             | |
    /  \    _____   _ _ __ ___   \ \  / / _ _ __| |_ _   _  __ _| |
   / /\ \  |_  / | | | '__/ _ \   \ \/ / | | '__| __| | | |/ _` | |
  / ____ \  / /| |_| | | |  __/    \  /  | | |  | |_| |_| | (_| | |
 /_/    \_\/___|\__,_|_|  \___|     \/   |_|_|   \__|\__,_|\__,_|_|
               _____            _    _                             
              |  __ \          | |  | |                            
              | |  | | ___  ___| | _| |_ ___  _ __                 
              | |  | |/ _ \/ __| |/ / __/ _ \| '_ \                
              | |__| |  __/\__ \   <| || (_) | |_) |               
              |_____/ \___||___/_|\_\\__\___/| .__/                
                                             | |                   
                                             |_|                    

Infrastructure code for Azure Virtual Desktop. This was designed to be run from GitLab CICD with variables being injected at run time. Azure
Service Principal or user running this code must have the Desktop Virtualization Contributor role
or higher such as Subscription Contributor role and User Access Administrator role.

Terraform backend is hosted on the GitLab project.

Pipeline environmental variables:
	
ARM_CLIENT_ID
ARM_CLIENT_SECRET
ARM_SUBSCRIPTION_ID
ARM_TENANT_ID
TF_VAR_domain_join_pw
TF_VAR_horizon_api_pw
TF_VAR_hybrid_worker_pw
TF_VAR_local_admin_pw
TF_VAR_env

*/

terraform {
  # Use GitLab hosted backend for state files
  backend "http" {}

  required_providers {
    # Azure provider
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.49.0"
    }
    # Some Azure resources required globally unique names
    # random = {
    #   source  = "hashicorp/random"
    #   version = ">= 3.4.0"
    # }
  }
}

provider "azurerm" {
  features {}
}

/*
  __  __           _       _           
 |  \/  |         | |     | |          
 | \  / | ___   __| |_   _| | ___  ___ 
 | |\/| |/ _ \ / _` | | | | |/ _ \/ __|
 | |  | | (_) | (_| | |_| | |  __/\__ \
 |_|  |_|\___/ \__,_|\__,_|_|\___||___/

*/

# Module: Management infrastructure for AVD, including log analytics workspace, 
# event hub, and storage account
# -----------------------------------------------------------------------------
module "mgmt" {
  source                           = "./modules/management"
  resource_group_name              = "rg-avd-${var.env}-mgmt-${var.primary_region}"
  resource_group_location          = var.primary_region
  log_analytics_name               = "la-avd-${var.env}-${var.primary_region}"
  log_analytics_sku                = var.log_analytics_sku
  log_analytics_retention_in_days  = var.log_analytics_retention_in_days
  event_hub_namespace              = "ehn-avd-${var.env}-${var.primary_region}"
  event_hub_name                   = "eh-avd-${var.env}"
  event_hub_name_message_retention = var.event_hub_name_message_retention
  storage_account_name             = "storavd${var.env}x${var.primary_region}"
  tags                             = var.tags
}

# Module: Azure Automation account, includes runbooks
# -----------------------------------------------------------------------------
module "aa" {
  source                          = "./modules/automation_account"
  env                             = var.env
  resource_group_location         = module.mgmt.resource_group.location
  resource_group_name             = module.mgmt.resource_group.name
  azure_automation_account_name   = "aa-avd-${var.env}-${var.primary_region}"
  local_admin_username            = var.local_admin_username
  local_admin_pw                  = var.local_admin_pw # from CICD variables
  domain_join_upn                 = var.domain_join_upn
  domain_join_pw                  = var.domain_join_pw # from CICD variables
  log_analytics_name              = "la-avd-${var.env}-automation-${var.primary_region}"
  log_analytics_sku               = var.log_analytics_sku
  log_analytics_retention_in_days = var.log_analytics_retention_in_days
  hybrid_worker_subnet_id         = data.azurerm_subnet.subnet_mgmt.id
  storage_account_key             = module.mgmt.storage_account.primary_access_key
  storage_account_name            = module.mgmt.storage_account.name
  horizon_api_pw                  = var.horizon_api_pw   # from CICD variables
  hybrid_worker_pw                = var.hybrid_worker_pw # from CICD variables
  tags                            = var.tags
}

# Module: Azure Image Builder for AVD, includes resources, identity, and roles
# -----------------------------------------------------------------------------
module "aib" {
  source                    = "./modules/azure_image_builder"
  env                       = var.env
  location                  = module.mgmt.resource_group.location
  resource_group_name       = module.mgmt.resource_group.name
  identity_name             = "user-${var.env}-aib-${var.primary_region}"
  network_resource_group_id = data.azurerm_resource_group.rg_network.id
  images_resource_group_id  = azurerm_resource_group.rg_images.id
  avdmgmt_resource_group_id = module.mgmt.resource_group.id
  tags                      = var.tags
}

/*
  _   _      _                      _    
 | \ | |    | |                    | |   
 |  \| | ___| |___      _____  _ __| | __
 | . ` |/ _ \ __\ \ /\ / / _ \| '__| |/ /
 | |\  |  __/ |_ \ V  V / (_) | |  |   < 
 |_| \_|\___|\__| \_/\_/ \___/|_|  |_|\_\

Network configuration

* /

# Subnets
# -----------------------------------------------------------------------------
data "azurerm_resource_group" "rg_network" {
  name = var.network_resource_group_name
}
resource "azurerm_subnet" "subnet_mgmt" {
  name                 = var.subnets.mgmt_name1
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
  address_prefixes     = [var.subnets.mgmt_subnet1]
}
## Used for azure image builder, required to access resources over private link
resource "azurerm_subnet" "subnet_infra" {
  name                                          = var.subnets.infra_name1
  resource_group_name                           = var.network_resource_group_name
  virtual_network_name                          = var.virtual_network_name
  address_prefixes                              = [var.subnets.infra_subnet1]
  private_link_service_network_policies_enabled = false
  #enforce_private_link_service_network_policies = true
}

resource "azurerm_subnet" "subnet_palo1" {
  name                 = var.subnets.palo_name1
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
  address_prefixes     = [var.subnets.palo_subnet1]
}

resource "azurerm_subnet" "subnet_palo2" {
  name                 = var.subnets.palo_name2
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
  address_prefixes     = [var.subnets.palo_subnet2]
}

resource "azurerm_subnet" "subnet_palo3" {
  name                 = var.subnets.palo_name3
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
  address_prefixes     = [var.subnets.palo_subnet3]
}

resource "azurerm_subnet" "subnet_desktop1" {
  name                 = var.subnets.desktop_name1
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
  address_prefixes     = [var.subnets.desktop_subnet1]
}
resource "azurerm_subnet" "subnet_desktop2" {
  name                 = var.subnets.desktop_name2
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
  address_prefixes     = [var.subnets.desktop_subnet2]
}
resource "azurerm_subnet" "subnet_desktop3" {
  name                 = var.subnets.desktop_name3
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
  address_prefixes     = [var.subnets.desktop_subnet3]
}
# Network Security Group and association
# -----------------------------------------------------------------------------
## NSG
resource "azurerm_network_security_group" "nsg_desktop" {
  name                = "nsg-avd-${var.env}-desktop-all"
  location            = module.mgmt.resource_group.location
  resource_group_name = module.mgmt.resource_group.name
  tags                = var.tags
}
## NSG association to subnets
resource "azurerm_subnet_network_security_group_association" "nsg_desktop_subnet1_assoc" {
  subnet_id                 = azurerm_subnet.subnet_desktop1.id
  network_security_group_id = azurerm_network_security_group.nsg_desktop.id
}
resource "azurerm_subnet_network_security_group_association" "nsg_desktop_subnet2_assoc" {
  subnet_id                 = azurerm_subnet.subnet_desktop2.id
  network_security_group_id = azurerm_network_security_group.nsg_desktop.id
}
resource "azurerm_subnet_network_security_group_association" "nsg_desktop_subnet3_assoc" {
  subnet_id                 = azurerm_subnet.subnet_desktop3.id
  network_security_group_id = azurerm_network_security_group.nsg_desktop.id
}
# Route Tables and associations
# -----------------------------------------------------------------------------
## Route table for Palo interface
resource "azurerm_route_table" "rt_external" {
  name                          = "rt-avd-${var.env}-palo-external-${var.primary_region}"
  location                      = module.mgmt.resource_group.location
  resource_group_name           = module.mgmt.resource_group.name
  disable_bgp_route_propagation = false
  tags                          = var.tags
  route = [
    {
      address_prefix         = var.route_palo.address_prefix
      name                   = var.route_palo.name
      next_hop_in_ip_address = var.route_palo.next_hop_in_ip_address
      next_hop_type          = "VirtualAppliance"
    } 
  ]
}
#Associate Subnets with RouteTable
resource "azurerm_subnet_route_table_association" "rt_desktop_subnet1_assoc" {
  subnet_id      = azurerm_subnet.subnet_desktop1.id
  route_table_id = azurerm_route_table.rt_external.id
}
resource "azurerm_subnet_route_table_association" "rt_desktop_subnet2_assoc" {
  subnet_id      = azurerm_subnet.subnet_desktop2.id
  route_table_id = azurerm_route_table.rt_external.id
}
resource "azurerm_subnet_route_table_association" "rt_desktop_subnet3_assoc" {
  subnet_id      = azurerm_subnet.subnet_desktop3.id
  route_table_id = azurerm_route_table.rt_external.id
}

*/
/*
data "azurerm_resource_group" "rg_network" {
  name = var.network_resource_group_name
}
data "azurerm_subnet" "subnet_mgmt" {
  name                 = var.subnets.mgmt_name1
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
}
data "azurerm_subnet" "subnet_desktop1" {
  name                 = var.subnets.desktop_name1
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
}
data "azurerm_subnet" "subnet_desktop2" {
  name                 = var.subnets.desktop_name2
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
}
data "azurerm_subnet" "subnet010" {
  name                 = var.subnets.subnet010
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
}
data "azurerm_subnet" "subnet011" {
  name                 = var.subnets.subnet011
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
}
data "azurerm_subnet" "subnet012" {
  name                 = var.subnets.subnet012
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
}
data "azurerm_subnet" "subnet013" {
  name                 = var.subnets.subnet013
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
}
data "azurerm_subnet" "subnet014" {
  name                 = var.subnets.subnet014
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
}
data "azurerm_subnet" "subnet015" {
  name                 = var.subnets.subnet015
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
}
data "azurerm_subnet" "subnet016" {
  name                 = var.subnets.subnet016
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
}
data "azurerm_subnet" "subnet017" {
  name                 = var.subnets.subnet017
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
}
data "azurerm_subnet" "subnet018" {
  name                 = var.subnets.subnet018
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
}
data "azurerm_subnet" "subnet019" {
  name                 = var.subnets.subnet019
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
}
data "azurerm_subnet" "subnet020" {
  name                 = var.subnets.subnet020
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
}
data "azurerm_subnet" "subnet021" {
  name                 = var.subnets.subnet021
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
}
data "azurerm_subnet" "subnet022" {
  name                 = var.subnets.subnet022
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
}
data "azurerm_subnet" "subnet023" {
  name                 = var.subnets.subnet023
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
}
data "azurerm_subnet" "subnet024" {
  name                 = var.subnets.subnet024
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
}
data "azurerm_subnet" "subnet025" {
  name                 = var.subnets.subnet025
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
}
*/

/*
  ______ _____ _                 _      
 |  ____/ ____| |               (_)     
 | |__ | (___ | |     ___   __ _ ___  __
 |  __| \___ \| |    / _ \ / _` | \ \/ /
 | |    ____) | |___| (_) | (_| | |>  < 
 |_|   |_____/|______\___/ \__, |_/_/\_\
                            __/ |       
                           |___/        

Storage dedicated to User Profile Containers. 
*/

#Module: Azure Storage Dedicated to FSlogix Profiles
# -----------------------------------------------------------------------------
module "fslogix_storage" {
  source                       = "./modules/avd_fslogix"
  resource_group_name          = module.mgmt.resource_group.name
  resource_group_location      = module.mgmt.resource_group.location
  profile_storage_account_name = var.storage_account_name #!!---needs to be less than 15 chars & unique across all Azure!!
  account_replication_type     = var.account_replication_type
  account_tier                 = var.account_tier
  account_kind                 = var.account_kind
  tags                         = var.tags
  env                          = var.env
  storage_sid                  = var.storage_sid
  storage_quota                = var.storage_quota
  # subnet_id_list = [
  #     azurerm_subnet.subnet_desktop1.id,
  #     azurerm_subnet.subnet_desktop2.id,
  #     azurerm_subnet.subnet_desktop3.id
  # ]
}
/*
//Status=400 Code="NetworkAclsValidationFailure" Message="Validation of network acls failure: SubnetsHaveNoServiceEndpointsConfigured:Subnets subnet-01, subnet-02, subnet-03
#Assign Firewall scope to Storage Account. 
resource "azurerm_storage_account_network_rules" "nr_fslogix_storage" {
  storage_account_id = module.fslogix_storage.storage_account.id
  default_action     = "Deny"
  ip_rules           = []
  bypass             = ["AzureServices"]
  virtual_network_subnet_ids = [
    azurerm_subnet.subnet_desktop1.id,
    azurerm_subnet.subnet_desktop2.id,
    azurerm_subnet.subnet_desktop3.id
  ]
}
*/

/*
  _____                                 
 |_   _|                                
   | |  _ __ ___   __ _  __ _  ___  ___ 
   | | | '_ ` _ \ / _` |/ _` |/ _ \/ __|
  _| |_| | | | | | (_| | (_| |  __/\__ \
 |_____|_| |_| |_|\__,_|\__, |\___||___/
                         __/ |          
                        |___/           

Images versions are created using Azure Image Builder (AIB) and referenced using
image definitions. The image definitions are stored in the shared image gallery
where it's distributed to defined regions where it's available to be used.

*/


# Shared image gallery - store images and distribute regionally
# -----------------------------------------------------------------------------
resource "azurerm_resource_group" "rg_images" {
  name     = "rg-avd-${var.env}-images-${var.primary_region}"
  location = var.primary_region
  tags     = var.tags
}

resource "azurerm_shared_image_gallery" "gal" {
  name                = "gal_avd_${var.env}_${var.primary_region}"
  location            = azurerm_resource_group.rg_images.location
  resource_group_name = azurerm_resource_group.rg_images.name
  description         = "Shared images for Azure Virtual Desktop."
  tags                = var.tags
}

# Image definitions - publish image into gallery
# -----------------------------------------------------------------------------

## Win 10 Multi-session (V2)
resource "azurerm_shared_image" "image_evd_v2" {
  name                = "img-avd-${var.env}-evd_v2-${var.primary_region}"
  location            = azurerm_resource_group.rg_images.location
  resource_group_name = azurerm_resource_group.rg_images.name
  gallery_name        = azurerm_shared_image_gallery.gal.name
  os_type             = "Windows"
  tags                = var.tags
  hyper_v_generation  = "V2"

  identifier {
    publisher = "AZ_ImageBuilder"
    offer     = "Windows-10"
    sku       = "win10-22h2-avd-g2"
  }
}
## Win 11 Multi-session (V2)
resource "azurerm_shared_image" "image_w11" {
  name                = "img-avd-${var.env}-w11-${var.primary_region}"
  location            = azurerm_resource_group.rg_images.location
  resource_group_name = azurerm_resource_group.rg_images.name
  gallery_name        = azurerm_shared_image_gallery.gal.name
  os_type             = "Windows"
  tags                = var.tags
hyper_v_generation  = "V2"

  identifier {
    publisher = "AZ_ImageBuilder"
    offer     = "Windows-11"
    sku       = "win11-22h2-avd"
  }
}
## Win 10 Single-Session (V2) 
##Developer(contractors & employees)
resource "azurerm_shared_image" "image_dev" {
  name                = "img-avd-${var.env}-dev-${var.primary_region}"
  location            = azurerm_resource_group.rg_images.location
  resource_group_name = azurerm_resource_group.rg_images.name
  gallery_name        = azurerm_shared_image_gallery.sig.name
  os_type             = "Windows"
  tags                = var.tags
  hyper_v_generation  = "V2"

  identifier {
    publisher = "AZ_ImageBuilder"
    offer     = "Windows-10"
    sku       = "win10-22h2-ent-g2"
  }
}


/*
 __          __        _                                  
 \ \        / /       | |                                 
  \ \  /\  / /__  _ __| | _____ _ __   __ _  ___ ___  ___ 
   \ \/  \/ / _ \| '__| |/ / __| '_ \ / _` |/ __/ _ \/ __|
    \  /\  / (_) | |  |   <\__ \ |_) | (_| | (_|  __/\__ \
     \/  \/ \___/|_|  |_|\_\___/ .__/ \__,_|\___\___||___/
                               | |                        
                               |_|                        

*/

# AVD Workspaces - Organization and presentation of desktop and applications
# -----------------------------------------------------------------------------
## Desktops
module "desktop_workspace_desktops" {
  source                  = "./modules/avd_workspace"
  resource_group_object   = module.mgmt.resource_group
  workspace_name          = "vdws-${var.env}-desktops-${module.mgmt.resource_group.location}"
  workspace_friendly_name = "Desktops${var.env == "prod" ? "" : " (NonProd)"}"
  log_analytics_id        = module.mgmt.log_analytics.id
  eventhub_name           = module.mgmt.event_hub.name
  eventhub_namespace_name = module.mgmt.eventhub_namespace.name
  tags                    = var.tags
}

## RemoteApps General
module "desktop_workspace_remoteapps_general" {
  source                  = "./modules/avd_workspace"
  resource_group_object   = module.mgmt.resource_group
  workspace_name          = "vdws-${var.env}-rageneral-${module.mgmt.resource_group.location}"
  workspace_friendly_name = "RemoteApps General${var.env == "prod" ? "" : " (NonProd)"}"
  log_analytics_id        = module.mgmt.log_analytics.id
  eventhub_name           = module.mgmt.event_hub.name
  eventhub_namespace_name = module.mgmt.eventhub_namespace.name
  tags                    = var.tags
}

## RemoteApps Secure
module "desktop_workspace_remoteapps_secure" {
  source                  = "./modules/avd_workspace"
  resource_group_object   = module.mgmt.resource_group
  workspace_name          = "vdws-${var.env}-rasecure-${module.mgmt.resource_group.location}"
  workspace_friendly_name = "RemoteApps Secure${var.env == "prod" ? "" : " (NonProd)"}"
  log_analytics_id        = module.mgmt.log_analytics.id
  eventhub_name           = module.mgmt.event_hub.name
  eventhub_namespace_name = module.mgmt.eventhub_namespace.name
  tags                    = var.tags
}

/*
   _____               _               _    _           _     _____            _     
  / ____|             (_)             | |  | |         | |   |  __ \          | |    
 | (___   ___  ___ ___ _  ___  _ __   | |__| | ___  ___| |_  | |__) |__   ___ | |___ 
  \___ \ / _ \/ __/ __| |/ _ \| '_ \  |  __  |/ _ \/ __| __| |  ___/ _ \ / _ \| / __|
  ____) |  __/\__ \__ \ | (_) | | | | | |  | | (_) \__ \ |_  | |  | (_) | (_) | \__ \
 |_____/ \___||___/___/_|\___/|_| |_| |_|  |_|\___/|___/\__| |_|   \___/ \___/|_|___/
                                                                                     
Session Host Pools (!) Pool names must be unique (!)

*/

# Session Pool - Personal Developer
# -----------------------------------------------------------------------------
module "pool_desktops_dev" {
  source                           = "./modules/avd_hostpool"
  env                              = var.env
  location                         = var.primary_region
  host_pool_name                   = "dev"
  host_pool_type                   = "personal"
  pool_set_validate                = false
  pool_set_load_balancer_type      = "Persistent"
  pool_set_autostart_vm            = true
  subnet_name                      = data.azurerm_subnet.subnet_desktop2.name
  subnet_vnet_name                 = data.azurerm_subnet.subnet_desktop2.virtual_network_name
  subnet_resource_group            = data.azurerm_subnet.subnet_desktop2.resource_group_name
  eventhub_name                    = module.mgmt.event_hub.name
  eventhub_namespace_object        = module.mgmt.eventhub_namespace
  log_analytics_id                 = module.mgmt.log_analytics.id
  storage_account_key              = module.mgmt.storage_account.primary_access_key
  storage_account_name             = module.mgmt.storage_account.name
  url_ccm_agent                    = var.url_ccm_agent
  url_avd_agent                    = var.url_avd_agent
  tags                             = var.tags
  session_host_count               = 0 # if set to 0, all variables below will not be used
  session_host_prefix              = upper("avpe-${var.env_shortName}-dev")
  session_host_size                = "Standard_B2s"
  session_host_disk_type           = var.session_host_disk_type
  shared_image_id                  = azurerm_shared_image.image_dev.id
  vm_admin_username                = var.local_admin_username
  vm_admin_pw                      = var.local_admin_pw # from CICD variables
  vm_domain_join_upn               = var.domain_join_upn
  vm_domain_join_pw                = var.domain_join_pw # from CICD variables
  log_analytics_workspace_id       = module.mgmt.log_analytics.workspace_id
  log_analytics_primary_shared_key = module.mgmt.log_analytics.primary_shared_key
}

# Session Pool - Windows 10 General (pooled)
# -----------------------------------------------------------------------------
module "pool_desktops_w10general" {
  source                           = "./modules/avd_hostpool"
  env                              = var.env
  location                         = var.primary_region
  host_pool_name                   = "gen10"
  host_pool_type                   = "pooled"
  pool_set_validate                = false
  pool_set_load_balancer_type      = "DepthFirst"
  pool_set_max_sessions            = 10
  pool_set_autostart_vm            = true
  subnet_name                      = data.azurerm_subnet.subnet_desktop1.name
  subnet_vnet_name                 = data.azurerm_subnet.subnet_desktop1.virtual_network_name
  subnet_resource_group            = data.azurerm_subnet.subnet_desktop1.resource_group_name
  session_host_count               = var.w10general_host_count
  session_host_prefix              = upper("avms-${var.env_shortName}-gen10")
  session_host_size                = var.w10general_host_size
  session_host_disk_type           = var.session_host_disk_type
  shared_image_id                  = azurerm_shared_image.image_evd.id
  vm_admin_username                = var.local_admin_username
  vm_admin_pw                      = var.local_admin_pw # from CICD variables
  vm_domain_join_upn               = var.domain_join_upn
  vm_domain_join_pw                = var.domain_join_pw # from CICD variables
  log_analytics_workspace_id       = module.mgmt.log_analytics.workspace_id
  log_analytics_primary_shared_key = module.mgmt.log_analytics.primary_shared_key
  log_analytics_id                 = module.mgmt.log_analytics.id
  storage_account_key              = module.mgmt.storage_account.primary_access_key
  storage_account_name             = module.mgmt.storage_account.name
  url_ccm_agent                    = var.url_ccm_agent
  eventhub_name                    = module.mgmt.event_hub.name
  eventhub_namespace_object        = module.mgmt.eventhub_namespace
  url_avd_agent                    = var.url_avd_agent
  tags                             = var.tags
}

# Session Pool - Windows 11 General (pooled)
# -----------------------------------------------------------------------------
module "pool_desktops_w11general" {
  source                           = "./modules/avd_hostpool"
  env                              = var.env
  location                         = var.primary_region
  host_pool_name                   = "gen11"
  host_pool_type                   = "pooled"
  pool_set_validate                = false
  pool_set_load_balancer_type      = "DepthFirst"
  pool_set_max_sessions            = 10
  pool_set_autostart_vm            = true
  subnet_name                      = data.azurerm_subnet.subnet_desktop1.name
  subnet_vnet_name                 = data.azurerm_subnet.subnet_desktop1.virtual_network_name
  subnet_resource_group            = data.azurerm_subnet.subnet_desktop1.resource_group_name
  session_host_count               = var.w11general_host_count
  session_host_prefix              = upper("avms-${var.env_shortName}-gen11")
  session_host_size                = var.w11general_host_size
  session_host_disk_type           = var.session_host_disk_type
  shared_image_id                  = azurerm_shared_image.image_w11_v2.id
  vm_admin_username                = var.local_admin_username
  vm_admin_pw                      = var.local_admin_pw # from CICD variables
  vm_domain_join_upn               = var.domain_join_upn
  vm_domain_join_pw                = var.domain_join_pw # from CICD variables
  log_analytics_workspace_id       = module.mgmt.log_analytics.workspace_id
  log_analytics_primary_shared_key = module.mgmt.log_analytics.primary_shared_key
  log_analytics_id                 = module.mgmt.log_analytics.id
  storage_account_key              = module.mgmt.storage_account.primary_access_key
  storage_account_name             = module.mgmt.storage_account.name
  url_ccm_agent                    = var.url_ccm_agent
  eventhub_name                    = module.mgmt.event_hub.name
  eventhub_namespace_object        = module.mgmt.eventhub_namespace
  url_avd_agent                    = var.url_avd_agent
  tags                             = var.tags
}

# Session Pool - RemoteApps PCI (pooled)
# -----------------------------------------------------------------------------
module "pool_remoteapps_pci" {
  source                           = "./modules/avd_hostpool"
  env                              = var.env
  location                         = var.primary_region
  host_pool_name                   = "rapci"
  host_pool_type                   = "pooled"
  pool_set_validate                = false
  pool_set_load_balancer_type      = "DepthFirst"
  pool_set_max_sessions            = 30
  pool_set_autostart_vm            = true
  subnet_name                      = data.azurerm_subnet.subnet010.name
  subnet_vnet_name                 = data.azurerm_subnet.subnet010.virtual_network_name
  subnet_resource_group            = data.azurerm_subnet.subnet010.resource_group_name
  ip_allocation_type               = "Static"
  session_host_count               = var.remoteapps_pci_host_count
  session_host_prefix              = upper("avms-${var.env_shortName}-rapci")
  session_host_size                = var.remoteapps_pci_host_size
  session_host_disk_type           = var.session_host_disk_type
  shared_image_id                  = azurerm_shared_image.image_evd.id
  vm_admin_username                = var.local_admin_username
  vm_admin_pw                      = var.local_admin_pw # from CICD variables
  vm_domain_join_upn               = var.domain_join_upn
  vm_domain_join_pw                = var.domain_join_pw # from CICD variables
  log_analytics_workspace_id       = module.mgmt.log_analytics.workspace_id
  log_analytics_primary_shared_key = module.mgmt.log_analytics.primary_shared_key
  log_analytics_id                 = module.mgmt.log_analytics.id
  storage_account_key              = module.mgmt.storage_account.primary_access_key
  storage_account_name             = module.mgmt.storage_account.name
  url_ccm_agent                    = var.url_ccm_agent
  eventhub_name                    = module.mgmt.event_hub.name
  eventhub_namespace_object        = module.mgmt.eventhub_namespace
  url_avd_agent                    = var.url_avd_agent
  tags                             = var.tags
}

# Session Pool - RemoteApps General (pooled)
# -----------------------------------------------------------------------------
module "pool_remoteapps_general" {
  source                           = "./modules/avd_hostpool"
  env                              = var.env
  location                         = var.primary_region
  host_pool_name                   = "ragen"
  host_pool_type                   = "pooled"
  pool_set_validate                = false
  pool_set_load_balancer_type      = "DepthFirst"
  pool_set_max_sessions            = 30
  pool_set_autostart_vm            = true
  subnet_name                      = data.azurerm_subnet.subnet_desktop1.name
  subnet_vnet_name                 = data.azurerm_subnet.subnet_desktop1.virtual_network_name
  subnet_resource_group            = data.azurerm_subnet.subnet_desktop1.resource_group_name
  session_host_count               = var.remoteapps_general_host_count
  session_host_prefix              = upper("avms-${var.env_shortName}-ragen")
  session_host_size                = var.remoteapps_general_host_size
  session_host_disk_type           = var.session_host_disk_type
  shared_image_id                  = azurerm_shared_image.image_evd_v2.id
  vm_admin_username                = var.local_admin_username
  vm_admin_pw                      = var.local_admin_pw # from CICD variables
  vm_domain_join_upn               = var.domain_join_upn
  vm_domain_join_pw                = var.domain_join_pw # from CICD variables
  log_analytics_workspace_id       = module.mgmt.log_analytics.workspace_id
  log_analytics_primary_shared_key = module.mgmt.log_analytics.primary_shared_key
  log_analytics_id                 = module.mgmt.log_analytics.id
  storage_account_key              = module.mgmt.storage_account.primary_access_key
  storage_account_name             = module.mgmt.storage_account.name
  url_ccm_agent                    = var.url_ccm_agent
  eventhub_name                    = module.mgmt.event_hub.name
  eventhub_namespace_object        = module.mgmt.eventhub_namespace
  url_avd_agent                    = var.url_avd_agent
  tags                             = var.tags
}

/*
                       _ _           _   _                _____                           
     /\               | (_)         | | (_)              / ____|                          
    /  \   _ __  _ __ | |_  ___ __ _| |_ _  ___  _ __   | |  __ _ __ ___  _   _ _ __  ___ 
   / /\ \ | '_ \| '_ \| | |/ __/ _` | __| |/ _ \| '_ \  | | |_ | '__/ _ \| | | | '_ \/ __|
  / ____ \| |_) | |_) | | | (_| (_| | |_| | (_) | | | | | |__| | | | (_) | |_| | |_) \__ \
 /_/    \_\ .__/| .__/|_|_|\___\__,_|\__|_|\___/|_| |_|  \_____|_|  \___/ \__,_| .__/|___/
          | |   | |                                                            | |        
          |_|   |_|                                                            |_|        

*/

# Application Groups
# -----------------------------------------------------------------------------
/*
module "example_appgroup" {
  source                  = "./modules/avd_appgroup"
  resource_group_object   = module.pool_example_general.resource_group
  appgroup_name           = "vdag-${var.env}-EXAMPLE-${module.pool_remoteapps_general.resource_group.location}"
  default_desktop_name    = "Example"
  appgroup_type           = "RemoteApp"
  desktop_pool_id         = module.pool_remoteapps_general.host_pool.id
  log_analytics_id        = module.mgmt.log_analytics.id
  eventhub_name           = module.mgmt.event_hub.name
  eventhub_namespace_name = module.mgmt.eventhub_namespace.name
  eventhub_rg_name        = module.mgmt.resource_group.name
  workspace_id            = module.desktop_workspace_remoteapps_general.virtual_desktop_workspace.id
  tags                    = var.tags
  group_assignment_principal_id = [
    #<AzureAD_ObjectID>#
  ]
}
*/
## Desktop - Developers Personal
module "appgroup_desktop_dev" {
  source                  = "./modules/avd_appgroup"
  resource_group_object   = module.pool_desktops_dev.resource_group
  appgroup_name           = "vdag-${var.env}-dev-${module.pool_desktops_dev.resource_group.location}"
  default_desktop_name    = "Personal Developer Desktop"
  appgroup_type           = "Desktop"
  desktop_pool_id         = module.pool_desktops_dev.host_pool.id
  log_analytics_id        = module.mgmt.log_analytics.id
  eventhub_name           = module.mgmt.event_hub.name
  eventhub_namespace_name = module.mgmt.eventhub_namespace.name
  eventhub_rg_name        = module.mgmt.resource_group.name
  workspace_id            = module.desktop_workspace_desktops.virtual_desktop_workspace.id
  tags                    = var.tags
  pool_assignment_principal_id = [
    "azureAD.ObjectID",                                               
    (var.env == "prod" ? "prod-azureAD.ObjectID" : "Nonprod-azureAD.ObjectID"),
  ]
}

## Desktop - Windows 10 General
module "appgroup_desktop_w10general" {
  source                  = "./modules/avd_appgroup"
  resource_group_object   = module.pool_desktops_w10general.resource_group
  appgroup_name           = "vdag-${var.env}-desktopgen10-${module.pool_desktops_w10general.resource_group.location}"
  default_desktop_name    = "Windows 10 General"
  appgroup_type           = "Desktop"
  desktop_pool_id         = module.pool_desktops_w10general.host_pool.id
  log_analytics_id        = module.mgmt.log_analytics.id
  eventhub_name           = module.mgmt.event_hub.name
  eventhub_namespace_name = module.mgmt.eventhub_namespace.name
  eventhub_rg_name        = module.mgmt.resource_group.name
  workspace_id            = module.desktop_workspace_desktops.virtual_desktop_workspace.id
  tags                    = var.tags
  pool_assignment_principal_id = [
    "azureAD.ObjectID",                                               
    (var.env == "prod" ? "prod-azureAD.ObjectID" : "Nonprod-azureAD.ObjectID"),
  ]
}

## Desktop - Windows 11 General
module "appgroup_desktop_w11general" {
  source                  = "./modules/avd_appgroup"
  resource_group_object   = module.pool_desktops_w11general.resource_group
  appgroup_name           = "vdag-${var.env}-desktopgen11-${module.pool_desktops_w11general.resource_group.location}"
  default_desktop_name    = "Windows 11 General"
  appgroup_type           = "Desktop"
  desktop_pool_id         = module.pool_desktops_w11general.host_pool.id
  log_analytics_id        = module.mgmt.log_analytics.id
  eventhub_name           = module.mgmt.event_hub.name
  eventhub_namespace_name = module.mgmt.eventhub_namespace.name
  eventhub_rg_name        = module.mgmt.resource_group.name
  workspace_id            = module.desktop_workspace_desktops.virtual_desktop_workspace.id
  tags                    = var.tags
  group_assignment_principal_id = [
    (var.env == "prod" ? "prod-azureAD.ObjectID" : "Nonprod-azureAD.ObjectID"),
  ]
}

## RemoteApps - PCI - ConfigMgr
module "appgroup_remoteapps_secureconfigmgr" {
  source                  = "./modules/avd_appgroup"
  resource_group_object   = module.pool_remoteapps_pci.resource_group
  appgroup_name           = "vdag-${var.env}-SecureCM-${module.pool_remoteapps_pci.resource_group.location}"
  default_desktop_name    = "null"
  appgroup_type           = "RemoteApp"
  desktop_pool_id         = module.pool_remoteapps_pci.host_pool.id
  log_analytics_id        = module.mgmt.log_analytics.id
  eventhub_name           = module.mgmt.event_hub.name
  eventhub_namespace_name = module.mgmt.eventhub_namespace.name
  eventhub_rg_name        = module.mgmt.resource_group.name
  workspace_id            = module.desktop_workspace_remoteapps_general.virtual_desktop_workspace.id
  tags                    = var.tags
  group_assignment_principal_id = [
    "azureAD.ObjectID",                                               
    (var.env == "prod" ? "prod-azureAD.ObjectID" : "Nonprod-azureAD.ObjectID"),
  ]
}

## RemoteApps - ConfigMgr
module "appgroup_remoteapps_configmgr" {
  source                  = "./modules/avd_appgroup"
  resource_group_object   = module.pool_remoteapps_general.resource_group
  appgroup_name           = "vdag-${var.env}-configmgr-${module.pool_remoteapps_general.resource_group.location}"
  default_desktop_name    = "null"
  appgroup_type           = "RemoteApp"
  desktop_pool_id         = module.pool_remoteapps_general.host_pool.id
  log_analytics_id        = module.mgmt.log_analytics.id
  eventhub_name           = module.mgmt.event_hub.name
  eventhub_namespace_name = module.mgmt.eventhub_namespace.name
  eventhub_rg_name        = module.mgmt.resource_group.name
  workspace_id            = module.desktop_workspace_remoteapps_general.virtual_desktop_workspace.id
  tags                    = var.tags
  pool_assignment_principal_id = [
    "azureAD.ObjectID",                                               
    (var.env == "prod" ? "prod-azureAD.ObjectID" : "Nonprod-azureAD.ObjectID"),
  ]
}

## RemoteApps - General
module "appgroup_remoteapps_general" {
  source                  = "./modules/avd_appgroup"
  resource_group_object   = module.pool_remoteapps_general.resource_group
  appgroup_name           = "vdag-${var.env}-rageneral-${module.pool_remoteapps_general.resource_group.location}"
  default_desktop_name    = "null"
  appgroup_type           = "RemoteApp"
  desktop_pool_id         = module.pool_remoteapps_general.host_pool.id
  log_analytics_id        = module.mgmt.log_analytics.id
  eventhub_name           = module.mgmt.event_hub.name
  eventhub_namespace_name = module.mgmt.eventhub_namespace.name
  eventhub_rg_name        = module.mgmt.resource_group.name
  workspace_id            = module.desktop_workspace_remoteapps_general.virtual_desktop_workspace.id
  tags                    = var.tags
  pool_assignment_principal_id = [
    "azureAD.ObjectID",                                               
    (var.env == "prod" ? "prod-azureAD.ObjectID" : "Nonprod-azureAD.ObjectID"),
  ]
}

## RemoteApps - RSAT
module "appgroup_remoteapps_rsat" {
  source                  = "./modules/avd_appgroup"
  resource_group_object   = module.pool_remoteapps_general.resource_group
  appgroup_name           = "vdag-${var.env}-rsat-${module.pool_remoteapps_general.resource_group.location}"
  default_desktop_name    = "null"
  appgroup_type           = "RemoteApp"
  desktop_pool_id         = module.pool_remoteapps_general.host_pool.id
  log_analytics_id        = module.mgmt.log_analytics.id
  eventhub_name           = module.mgmt.event_hub.name
  eventhub_namespace_name = module.mgmt.eventhub_namespace.name
  eventhub_rg_name        = module.mgmt.resource_group.name
  workspace_id            = module.desktop_workspace_remoteapps_general.virtual_desktop_workspace.id
  tags                    = var.tags
  pool_assignment_principal_id = [
    "azureAD.ObjectID",                                               
    (var.env == "prod" ? "prod-azureAD.ObjectID" : "Nonprod-azureAD.ObjectID"),
  ]
}

## RemoteApps - PowerBI
module "appgroup_remoteapps_pbi" {
  source                  = "./modules/avd_appgroup"
  resource_group_object   = module.pool_remoteapps_general.resource_group
  appgroup_name           = "vdag-${var.env}-powerbi-${module.pool_remoteapps_general.resource_group.location}"
  default_desktop_name    = "null"
  appgroup_type           = "RemoteApp"
  desktop_pool_id         = module.pool_remoteapps_general.host_pool.id
  log_analytics_id        = module.mgmt.log_analytics.id
  eventhub_name           = module.mgmt.event_hub.name
  eventhub_namespace_name = module.mgmt.eventhub_namespace.name
  eventhub_rg_name        = module.mgmt.resource_group.name
  workspace_id            = module.desktop_workspace_remoteapps_general.virtual_desktop_workspace.id
  tags                    = var.tags
  pool_assignment_principal_id = [
    "azureAD.ObjectID",                                               
    (var.env == "prod" ? "prod-azureAD.ObjectID" : "Nonprod-azureAD.ObjectID"),
  ]
}

## RemoteApps - Powershell
module "appgroup_remoteapps_pwsh" {
  source                  = "./modules/avd_appgroup"
  resource_group_object   = module.pool_remoteapps_general.resource_group
  appgroup_name           = "vdag-${var.env}-pwsh-${module.pool_remoteapps_general.resource_group.location}"
  default_desktop_name    = "null"
  appgroup_type           = "RemoteApp"
  desktop_pool_id         = module.pool_remoteapps_general.host_pool.id
  log_analytics_id        = module.mgmt.log_analytics.id
  eventhub_name           = module.mgmt.event_hub.name
  eventhub_namespace_name = module.mgmt.eventhub_namespace.name
  eventhub_rg_name        = module.mgmt.resource_group.name
  workspace_id            = module.desktop_workspace_remoteapps_general.virtual_desktop_workspace.id
  tags                    = var.tags
   pool_assignment_principal_id = [
    "azureAD.ObjectID",                                               
    (var.env == "prod" ? "prod-azureAD.ObjectID" : "Nonprod-azureAD.ObjectID"),
  ]
}

## RemoteApps - SFTP (putty,WinSCP))
module "appgroup_remoteapps_sftp" {
  source                  = "./modules/avd_appgroup"
  resource_group_object   = module.pool_remoteapps_general.resource_group
  appgroup_name           = "vdag-${var.env}-sftp-${module.pool_remoteapps_general.resource_group.location}"
  default_desktop_name    = "null"
  appgroup_type           = "RemoteApp"
  desktop_pool_id         = module.pool_remoteapps_general.host_pool.id
  log_analytics_id        = module.mgmt.log_analytics.id
  eventhub_name           = module.mgmt.event_hub.name
  eventhub_namespace_name = module.mgmt.eventhub_namespace.name
  eventhub_rg_name        = module.mgmt.resource_group.name
  workspace_id            = module.desktop_workspace_remoteapps_general.virtual_desktop_workspace.id
  tags                    = var.tags
  pool_assignment_principal_id = [
    "azureAD.ObjectID",                                               
    (var.env == "prod" ? "prod-azureAD.ObjectID" : "Nonprod-azureAD.ObjectID"),
  ]
}

## RemoteApps - KeyPass
module "appgroup_remoteapps_keypass" {
  source                  = "./modules/avd_appgroup"
  resource_group_object   = module.pool_remoteapps_general.resource_group
  appgroup_name           = "vdag-${var.env}-keypass-${module.pool_remoteapps_general.resource_group.location}"
  default_desktop_name    = "null"
  appgroup_type           = "RemoteApp"
  desktop_pool_id         = module.pool_remoteapps_general.host_pool.id
  log_analytics_id        = module.mgmt.log_analytics.id
  eventhub_name           = module.mgmt.event_hub.name
  eventhub_namespace_name = module.mgmt.eventhub_namespace.name
  eventhub_rg_name        = module.mgmt.resource_group.name
  workspace_id            = module.desktop_workspace_remoteapps_general.virtual_desktop_workspace.id
  tags                    = var.tags
  pool_assignment_principal_id = [
    "azureAD.ObjectID",                                               
    (var.env == "prod" ? "prod-azureAD.ObjectID" : "Nonprod-azureAD.ObjectID"),
  ]
}

## RemoteApps - LAPS UI
module "appgroup_remoteapps_lapsui" {
  source                  = "./modules/avd_appgroup"
  resource_group_object   = module.pool_remoteapps_general.resource_group
  appgroup_name           = "vdag-${var.env}-lapsui-${module.pool_remoteapps_general.resource_group.location}"
  default_desktop_name    = "null"
  appgroup_type           = "RemoteApp"
  desktop_pool_id         = module.pool_remoteapps_general.host_pool.id
  log_analytics_id        = module.mgmt.log_analytics.id
  eventhub_name           = module.mgmt.event_hub.name
  eventhub_namespace_name = module.mgmt.eventhub_namespace.name
  eventhub_rg_name        = module.mgmt.resource_group.name
  workspace_id            = module.desktop_workspace_remoteapps_general.virtual_desktop_workspace.id
  tags                    = var.tags
  pool_assignment_principal_id = [
    "azureAD.ObjectID",                                               
    (var.env == "prod" ? "prod-azureAD.ObjectID" : "Nonprod-azureAD.ObjectID"),
  ]
}

## RemoteApps - MS Project
module "appgroup_remoteapps_project" {
  source                  = "./modules/avd_appgroup"
  resource_group_object   = module.pool_remoteapps_general.resource_group
  appgroup_name           = "vdag-${var.env}-project-${module.pool_remoteapps_general.resource_group.location}"
  default_desktop_name    = "null"
  appgroup_type           = "RemoteApp"
  desktop_pool_id         = module.pool_remoteapps_general.host_pool.id
  log_analytics_id        = module.mgmt.log_analytics.id
  eventhub_name           = module.mgmt.event_hub.name
  eventhub_namespace_name = module.mgmt.eventhub_namespace.name
  eventhub_rg_name        = module.mgmt.resource_group.name
  workspace_id            = module.desktop_workspace_remoteapps_general.virtual_desktop_workspace.id
  tags                    = var.tags
  pool_assignment_principal_id = [
    "azureAD.ObjectID",                                               
    (var.env == "prod" ? "prod-azureAD.ObjectID" : "Nonprod-azureAD.ObjectID"),
  ]
}

## RemoteApps - MS Visio
module "appgroup_remoteapps_visio" {
  source                  = "./modules/avd_appgroup"
  resource_group_object   = module.pool_remoteapps_general.resource_group
  appgroup_name           = "vdag-${var.env}-visio-${module.pool_remoteapps_general.resource_group.location}"
  default_desktop_name    = "null"
  appgroup_type           = "RemoteApp"
  desktop_pool_id         = module.pool_remoteapps_general.host_pool.id
  log_analytics_id        = module.mgmt.log_analytics.id
  eventhub_name           = module.mgmt.event_hub.name
  eventhub_namespace_name = module.mgmt.eventhub_namespace.name
  eventhub_rg_name        = module.mgmt.resource_group.name
  workspace_id            = module.desktop_workspace_remoteapps_general.virtual_desktop_workspace.id
  tags                    = var.tags
  pool_assignment_principal_id = [
    "azureAD.ObjectID",                                               
    (var.env == "prod" ? "prod-azureAD.ObjectID" : "Nonprod-azureAD.ObjectID"),
  ]
}

## RemoteApps - MS SQL MGMT Studio
module "appgroup_remoteapps_ssms" {
  source                  = "./modules/avd_appgroup"
  resource_group_object   = module.pool_remoteapps_general.resource_group
  appgroup_name           = "vdag-${var.env}-ssms-${module.pool_remoteapps_general.resource_group.location}"
  default_desktop_name    = "null"
  appgroup_type           = "RemoteApp"
  desktop_pool_id         = module.pool_remoteapps_general.host_pool.id
  log_analytics_id        = module.mgmt.log_analytics.id
  eventhub_name           = module.mgmt.event_hub.name
  eventhub_namespace_name = module.mgmt.eventhub_namespace.name
  eventhub_rg_name        = module.mgmt.resource_group.name
  workspace_id            = module.desktop_workspace_remoteapps_general.virtual_desktop_workspace.id
  tags                    = var.tags
  group_assignment_principal_id = [
    "azureAD.ObjectID",                                               
    (var.env == "prod" ? "prod-azureAD.ObjectID" : "Nonprod-azureAD.ObjectID"),
  ]
}

## RemoteApps - MS Remote Desktop
module "appgroup_remoteapps_mstsc" {
  source                  = "./modules/avd_appgroup"
  resource_group_object   = module.pool_remoteapps_general.resource_group
  appgroup_name           = "vdag-${var.env}-mstsc-${module.pool_remoteapps_general.resource_group.location}"
  default_desktop_name    = "null"
  appgroup_type           = "RemoteApp"
  desktop_pool_id         = module.pool_remoteapps_general.host_pool.id
  log_analytics_id        = module.mgmt.log_analytics.id
  eventhub_name           = module.mgmt.event_hub.name
  eventhub_namespace_name = module.mgmt.eventhub_namespace.name
  eventhub_rg_name        = module.mgmt.resource_group.name
  workspace_id            = module.desktop_workspace_remoteapps_general.virtual_desktop_workspace.id
  tags                    = var.tags
  group_assignment_principal_id = [
    "azureAD.ObjectID",                                               
    (var.env == "prod" ? "prod-azureAD.ObjectID" : "Nonprod-azureAD.ObjectID"),
  ]
}

/*
  _____                      _                                
 |  __ \                    | |         /\                    
 | |__) |___ _ __ ___   ___ | |_ ___   /  \   _ __  _ __  ___ 
 |  _  // _ \ '_ ` _ \ / _ \| __/ _ \ / /\ \ | '_ \| '_ \/ __|
 | | \ \  __/ | | | | | (_) | ||  __// ____ \| |_) | |_) \__ \
 |_|  \_\___|_| |_| |_|\___/ \__\___/_/    \_\ .__/| .__/|___/
                                             | |   | |        
                                             |_|   |_|        

*/
# AVD RemoteApps, located in the vars section
#-----------------------------------------------------------------------------
/*
module "example_remoteapp" {
  source            = "./modules/avd_remoteapps"
  for_each          = var.example_remote_app
  name              = each.value.name
  appgroup_id       = module.example_appgroup.virtual_desktop_application_group.id
  friendly_name     = each.value.friendly_name
  description       = each.value.description
  path              = each.value.path
  command_line_pol  = each.value.command_line_argument_policy
  command_line_args = each.value.command_line_arguments
  icon_path         = each.value.icon_path
  icon_index        = each.value.icon_index
}
*/
module "apps_remoteapps_configmgr" {
  source            = "./modules/avd_remoteapps"
  for_each          = var.remoteapps_configmgr
  name              = each.value.name
  appgroup_id       = module.appgroup_remoteapps_configmgr.virtual_desktop_application_group.id
  friendly_name     = each.value.friendly_name
  description       = each.value.description
  path              = each.value.path
  command_line_pol  = each.value.command_line_argument_policy
  command_line_args = each.value.command_line_arguments
  icon_path         = each.value.icon_path
  icon_index        = each.value.icon_index
}

module "apps_remoteapps_secureconfigmgr" {
  source            = "./modules/avd_remoteapps"
  for_each          = var.remoteapps_secureconfigmgr
  name              = each.value.name
  appgroup_id       = module.appgroup_remoteapps_secureconfigmgr.virtual_desktop_application_group.id
  friendly_name     = each.value.friendly_name
  description       = each.value.description
  path              = each.value.path
  command_line_pol  = each.value.command_line_argument_policy
  command_line_args = each.value.command_line_arguments
  icon_path         = each.value.icon_path
  icon_index        = each.value.icon_index
}

module "apps_remoteapps_general" {
  source            = "./modules/avd_remoteapps"
  for_each          = var.remoteapps
  name              = each.value.name
  appgroup_id       = module.appgroup_remoteapps_general.virtual_desktop_application_group.id
  friendly_name     = each.value.friendly_name
  description       = each.value.description
  path              = each.value.path
  command_line_pol  = each.value.command_line_argument_policy
  command_line_args = each.value.command_line_arguments
  icon_path         = each.value.icon_path
  icon_index        = each.value.icon_index
}

module "apps_remoteapps_rsat" {
  source            = "./modules/avd_remoteapps"
  for_each          = var.remoteapps_rsat
  name              = each.value.name
  appgroup_id       = module.appgroup_remoteapps_rsat.virtual_desktop_application_group.id
  friendly_name     = each.value.friendly_name
  description       = each.value.description
  path              = each.value.path
  command_line_pol  = each.value.command_line_argument_policy
  command_line_args = each.value.command_line_arguments
  icon_path         = each.value.icon_path
  icon_index        = each.value.icon_index
}

module "apps_remoteapps_pbi" {
  source            = "./modules/avd_remoteapps"
  for_each          = var.remoteapps_pbi
  name              = each.value.name
  appgroup_id       = module.appgroup_remoteapps_pbi.virtual_desktop_application_group.id
  friendly_name     = each.value.friendly_name
  description       = each.value.description
  path              = each.value.path
  command_line_pol  = each.value.command_line_argument_policy
  command_line_args = each.value.command_line_arguments
  icon_path         = each.value.icon_path
  icon_index        = each.value.icon_index
}

module "apps_remoteapps_pwsh" {
  source            = "./modules/avd_remoteapps"
  for_each          = var.remoteapps_pwsh
  name              = each.value.name
  appgroup_id       = module.appgroup_remoteapps_pwsh.virtual_desktop_application_group.id
  friendly_name     = each.value.friendly_name
  description       = each.value.description
  path              = each.value.path
  command_line_pol  = each.value.command_line_argument_policy
  command_line_args = each.value.command_line_arguments
  icon_path         = each.value.icon_path
  icon_index        = each.value.icon_index
}

module "apps_remoteapps_sftp" {
  source            = "./modules/avd_remoteapps"
  for_each          = var.remoteapps_sftp
  name              = each.value.name
  appgroup_id       = module.appgroup_remoteapps_sftp.virtual_desktop_application_group.id
  friendly_name     = each.value.friendly_name
  description       = each.value.description
  path              = each.value.path
  command_line_pol  = each.value.command_line_argument_policy
  command_line_args = each.value.command_line_arguments
  icon_path         = each.value.icon_path
  icon_index        = each.value.icon_index
}

module "apps_remoteapps_keypass" {
  source            = "./modules/avd_remoteapps"
  for_each          = var.remoteapps_keypass
  name              = each.value.name
  appgroup_id       = module.appgroup_remoteapps_keypass.virtual_desktop_application_group.id
  friendly_name     = each.value.friendly_name
  description       = each.value.description
  path              = each.value.path
  command_line_pol  = each.value.command_line_argument_policy
  command_line_args = each.value.command_line_arguments
  icon_path         = each.value.icon_path
  icon_index        = each.value.icon_index
}

module "apps_remoteapps_lapsui" {
  source            = "./modules/avd_remoteapps"
  for_each          = var.remoteapps_lapsui
  name              = each.value.name
  appgroup_id       = module.appgroup_remoteapps_lapsui.virtual_desktop_application_group.id
  friendly_name     = each.value.friendly_name
  description       = each.value.description
  path              = each.value.path
  command_line_pol  = each.value.command_line_argument_policy
  command_line_args = each.value.command_line_arguments
  icon_path         = each.value.icon_path
  icon_index        = each.value.icon_index
}

module "apps_remoteapps_project" {
  source            = "./modules/avd_remoteapps"
  for_each          = var.remoteapps_project
  name              = each.value.name
  appgroup_id       = module.appgroup_remoteapps_project.virtual_desktop_application_group.id
  friendly_name     = each.value.friendly_name
  description       = each.value.description
  path              = each.value.path
  command_line_pol  = each.value.command_line_argument_policy
  command_line_args = each.value.command_line_arguments
  icon_path         = each.value.icon_path
  icon_index        = each.value.icon_index
}

module "apps_remoteapps_visio" {
  source            = "./modules/avd_remoteapps"
  for_each          = var.remoteapps_visio
  name              = each.value.name
  appgroup_id       = module.appgroup_remoteapps_visio.virtual_desktop_application_group.id
  friendly_name     = each.value.friendly_name
  description       = each.value.description
  path              = each.value.path
  command_line_pol  = each.value.command_line_argument_policy
  command_line_args = each.value.command_line_arguments
  icon_path         = each.value.icon_path
  icon_index        = each.value.icon_index
}

module "apps_remoteapps_ssms" {
  source            = "./modules/avd_remoteapps"
  for_each          = var.remoteapps_ssms
  name              = each.value.name
  appgroup_id       = module.appgroup_remoteapps_ssms.virtual_desktop_application_group.id
  friendly_name     = each.value.friendly_name
  description       = each.value.description
  path              = each.value.path
  command_line_pol  = each.value.command_line_argument_policy
  command_line_args = each.value.command_line_arguments
  icon_path         = each.value.icon_path
  icon_index        = each.value.icon_index
}

module "apps_remoteapps_avaya" {
  source            = "./modules/avd_remoteapps"
  for_each          = var.remoteapps_avaya
  name              = each.value.name
  appgroup_id       = module.appgroup_remoteapps_general.virtual_desktop_application_group.id
  friendly_name     = each.value.friendly_name
  description       = each.value.description
  path              = each.value.path
  command_line_pol  = each.value.command_line_argument_policy
  command_line_args = each.value.command_line_arguments
  icon_path         = each.value.icon_path
  icon_index        = each.value.icon_index
}

module "apps_remoteapps_mstsc" {
  source            = "./modules/avd_remoteapps"
  for_each          = var.remoteapps_mstsc
  name              = each.value.name
  appgroup_id       = module.appgroup_remoteapps_mstsc.virtual_desktop_application_group.id
  friendly_name     = each.value.friendly_name
  description       = each.value.description
  path              = each.value.path
  command_line_pol  = each.value.command_line_argument_policy
  command_line_args = each.value.command_line_arguments
  icon_path         = each.value.icon_path
  icon_index        = each.value.icon_index
}

/*
   _____           _ _             _____  _                 
  / ____|         | (_)           |  __ \| |                
 | (___   ___ __ _| |_ _ __   __ _| |__) | | __ _ _ __  ___ 
  \___ \ / __/ _` | | | '_ \ / _` |  ___/| |/ _` | '_ \/ __|
  ____) | (_| (_| | | | | | | (_| | |    | | (_| | | | \__ \
 |_____/ \___\__,_|_|_|_| |_|\__, |_|    |_|\__,_|_| |_|___/
                              __/ |                         
                             |___/                                                                                                            
*/

#AutoScaling Plans for "pooled" Host Pools
# -----------------------------------------------------------------------------
resource "azurerm_virtual_desktop_scaling_plan" "scaling_plan" {
  name                = "AutoScalePlan-Weekday-${var.env}"
  location            = var.primary_region
  resource_group_name = module.mgmt.resource_group.name
  time_zone           = "Pacific Standard Time"
  schedule {
    name                                 = "Weekdays"
    days_of_week                         = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
    ramp_up_start_time                   = "04:00"
    ramp_up_load_balancing_algorithm     = "DepthFirst"
    ramp_up_minimum_hosts_percent        = 30
    ramp_up_capacity_threshold_percent   = 50
    peak_start_time                      = "05:00"
    peak_load_balancing_algorithm        = "BreadthFirst"
    ramp_down_start_time                 = "18:00"
    ramp_down_load_balancing_algorithm   = "DepthFirst"
    ramp_down_minimum_hosts_percent      = 30
    ramp_down_force_logoff_users         = true
    ramp_down_wait_time_minutes          = 45
    ramp_down_notification_message       = "Please log off in the next 45 minutes, or risk loosing work."
    ramp_down_stop_hosts_when            = "ZeroActiveSessions"
    ramp_down_capacity_threshold_percent = 50
    off_peak_start_time                  = "19:00"
    off_peak_load_balancing_algorithm    = "DepthFirst"
  }
  schedule {
    name                                 = "Maintenance"
    days_of_week                         = ["Saturday"]
    ramp_up_start_time                   = "00:00"
    ramp_up_load_balancing_algorithm     = "DepthFirst"
    ramp_up_minimum_hosts_percent        = 100
    ramp_up_capacity_threshold_percent   = 60
    peak_start_time                      = "00:30"
    peak_load_balancing_algorithm        = "DepthFirst"
    ramp_down_start_time                 = "04:30"
    ramp_down_load_balancing_algorithm   = "DepthFirst"
    ramp_down_minimum_hosts_percent      = 10
    ramp_down_force_logoff_users         = true
    ramp_down_wait_time_minutes          = 30
    ramp_down_notification_message       = "Please log off in the next 30 minutes, or risk loosing work."
    ramp_down_capacity_threshold_percent = 90
    ramp_down_stop_hosts_when            = "ZeroSessions"
    off_peak_start_time                  = "05:00"
    off_peak_load_balancing_algorithm    = "DepthFirst"
  }

  host_pool {
    hostpool_id          = module.pool_remoteapps_pci.host_pool.id
    scaling_plan_enabled = true
  }
  host_pool {
    hostpool_id          = module.pool_remoteapps_general.host_pool.id
    scaling_plan_enabled = true
  }
  host_pool {
    hostpool_id          = module.pool_desktops_w10general.host_pool.id
    scaling_plan_enabled = true
  }
}

/*
   _____  ____  _        _____        _        _                    
  / ____|/ __ \| |      |  __ \      | |      | |                   
 | (___ | |  | | |      | |  | | __ _| |_ __ _| |__   __ _ ___  ___ 
  \___ \| |  | | |      | |  | |/ _` | __/ _` | '_ \ / _` / __|/ _ \
  ____) | |__| | |____  | |__| | (_| | || (_| | |_) | (_| \__ \  __/
 |_____/ \___\_\______| |_____/ \__,_|\__\__,_|_.__/ \__,_|___/\___|
                                                                    
*/

# AVD Workspaces - Organization and presentation of desktop and applications
# -----------------------------------------------------------------------------
resource "azurerm_mssql_server" "sql_server" {
  name                         = "sql-avd-${var.env}-${var.primary_region}"
  location                     = module.mgmt.resource_group.location
  resource_group_name          = module.mgmt.resource_group.name
  version                      = "12.0"
  administrator_login          = var.local_admin_username
  administrator_login_password = var.local_admin_pw
  minimum_tls_version          = "1.2"
  tags                         = var.tags
}

resource "azurerm_mssql_database" "sqldb_avd" {
  name                        = "db-avd-${var.env}-${var.primary_region}"
  server_id                   = azurerm_mssql_server.sql_server.id
  collation                   = "SQL_Latin1_General_CP1_CI_AS"
  auto_pause_delay_in_minutes = 60
  max_size_gb                 = 1
  min_capacity                = 0.5
  sku_name                    = "GP_S_Gen5_1"
  tags                        = var.tags

}


/*
TESTING Monitor Alert Group and Rules. 
Create Monitor and Alert Module  -or- Add into MGMT module.
Call from Main and assign it to SessionHosts as needed
Network In/Out only supports assignment to a single resource item. 
* /
#-------------------------------------------------------
resource "azurerm_monitor_action_group" "actiongroup" {
  name                = "Monitor-ActionGroup-${var.env}"
  resource_group_name = module.pool_remoteapps_general.resource_group.name
  #resource_group_name = module.mgmt.resource_group.name
  short_name = "agalert1"

  email_receiver {
    name                    = "Email_-EmailAction-"
    email_address           = "email.address@domain.com"
    use_common_alert_schema = true
  }
}
resource "azurerm_monitor_metric_alert" "availMemBytes" {
  name                = "Available Memory Bytes"
  resource_group_name = module.pool_remoteapps_general.resource_group.name
  scopes = [
    "/subscriptions/####/resourceGroups/rg-avd-nonprod-remoteapps/providers/Microsoft.Compute/virtualMachines/AVD-RAGEN-1",
    "/subscriptions/####/resourceGroups/rg-avd-nonprod-remoteapps/providers/Microsoft.Compute/virtualMachines/AVD-RAGEN-2"
  ] #scopes              = [azurerm_storage_account.to_monitor.id]
  description              = ""
  enabled                  = true
  severity                 = "3"
  target_resource_type     = "Microsoft.Compute/virtualMachines"
  frequency                = "PT5M"
  window_size              = "PT5M"
  auto_mitigate            = true
  target_resource_location = "westus2"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    #name= "Metric1"
    skip_metric_validation = false #default is false. 
    aggregation            = "Average"
    operator               = "LessThan"
    threshold              = 1000000000
    metric_name            = "Available Memory Bytes"
    #criterionType= "StaticThresholdCriterion"
  }

  action {
    action_group_id = azurerm_monitor_action_group.actiongroup.id
  }
}
resource "azurerm_monitor_metric_alert" "cpuPercent" {
  name                = "Percentage CPU"
  resource_group_name = module.pool_remoteapps_general.resource_group.name
  scopes = [
    "/subscriptions/####/resourceGroups/rg-avd-nonprod-remoteapps/providers/Microsoft.Compute/virtualMachines/AVD-RAGEN-1",
    "/subscriptions/####/resourceGroups/rg-avd-nonprod-remoteapps/providers/Microsoft.Compute/virtualMachines/AVD-RAGEN-2"
  ] #scopes              = [azurerm_storage_account.to_monitor.id]
  description              = ""
  enabled                  = true
  severity                 = "3"
  target_resource_type     = "Microsoft.Compute/virtualMachines"
  window_size              = "PT5M"
  frequency                = "PT5M"
  auto_mitigate            = true
  target_resource_location = "westus2"


  criteria {
    metric_namespace       = "Microsoft.Compute/virtualMachines"
    aggregation            = "Average"
    operator               = "GreaterThan"
    threshold              = 80
    metric_name            = "Percentage CPU"
    skip_metric_validation = false #default is false. 
  }

  action {
    action_group_id = azurerm_monitor_action_group.actiongroup.id
  }
}
resource "azurerm_monitor_metric_alert" "dataDisk_iopPercent" {
  name                = "Data Disk IOPS Consumed Percentage"
  resource_group_name = module.pool_remoteapps_general.resource_group.name
  scopes = [
    "/subscriptions/####/resourceGroups/rg-avd-nonprod-remoteapps/providers/Microsoft.Compute/virtualMachines/AVD-RAGEN-1",
    "/subscriptions/####/resourceGroups/rg-avd-nonprod-remoteapps/providers/Microsoft.Compute/virtualMachines/AVD-RAGEN-2"
  ] #scopes              = [azurerm_storage_account.to_monitor.id]
  description              = ""
  enabled                  = true
  severity                 = "3"
  target_resource_type     = "Microsoft.Compute/virtualMachines"
  window_size              = "PT5M"
  frequency                = "PT5M"
  auto_mitigate            = true
  target_resource_location = "westus2"

  criteria {
    metric_namespace       = "Microsoft.Compute/virtualMachines"
    aggregation            = "Average"
    operator               = "GreaterThan"
    threshold              = 95
    metric_name            = "Data Disk IOPS Consumed Percentage"
    skip_metric_validation = false #default is false. 
  }

  action {
    action_group_id = azurerm_monitor_action_group.actiongroup.id
  }
}
resource "azurerm_monitor_metric_alert" "osDisk_iopPercent" {
  name                = "OS Disk IOPS Consumed Percentage"
  resource_group_name = module.pool_remoteapps_general.resource_group.name
  scopes = [
    "/subscriptions/####/resourceGroups/rg-avd-nonprod-remoteapps/providers/Microsoft.Compute/virtualMachines/AVD-RAGEN-1",
    "/subscriptions/####/resourceGroups/rg-avd-nonprod-remoteapps/providers/Microsoft.Compute/virtualMachines/AVD-RAGEN-2"
  ] #scopes              = [azurerm_storage_account.to_monitor.id]
  description              = ""
  enabled                  = true
  severity                 = "3"
  target_resource_type     = "Microsoft.Compute/virtualMachines"
  window_size              = "PT5M"
  frequency                = "PT5M"
  auto_mitigate            = true
  target_resource_location = "westus2"

  criteria {
    metric_namespace       = "Microsoft.Compute/virtualMachines"
    aggregation            = "Average"
    operator               = "GreaterThan"
    threshold              = 95
    metric_name            = "OS Disk IOPS Consumed Percentage"
    skip_metric_validation = false #default is false. 
  }

  action {
    action_group_id = azurerm_monitor_action_group.actiongroup.id
  }
}
resource "azurerm_monitor_metric_alert" "netInTotal" { #Only supports a single resource
  name                = "Network In Total"
  resource_group_name = module.pool_remoteapps_general.resource_group.name
  scopes = [
    #"/subscriptions/####/resourceGroups/rg-avd-nonprod-remoteapps/providers/Microsoft.Compute/virtualMachines/AVD-RAGEN-1",
    "/subscriptions/####/resourceGroups/rg-avd-nonprod-remoteapps/providers/Microsoft.Compute/virtualMachines/AVD-RAGEN-2"
  ] #scopes              = [azurerm_storage_account.to_monitor.id]
  description              = ""
  enabled                  = true
  severity                 = "3"
  target_resource_type     = "Microsoft.Compute/virtualMachines"
  window_size              = "PT5M"
  frequency                = "PT5M"
  auto_mitigate            = true
  target_resource_location = "westus2"

  criteria {
    metric_namespace       = "Microsoft.Compute/virtualMachines"
    aggregation            = "Total"
    operator               = "GreaterThan"
    threshold              = 500000000000
    metric_name            = "Network In Total"
    skip_metric_validation = false #default is false. 
  }

  action {
    action_group_id = azurerm_monitor_action_group.actiongroup.id
  }
}
resource "azurerm_monitor_metric_alert" "netOutTotal" { #Only supports a single resource
  name                = "Network Out Total"
  resource_group_name = module.pool_remoteapps_general.resource_group.name
  scopes = [
    #"/subscriptions/####/resourceGroups/rg-avd-nonprod-remoteapps/providers/Microsoft.Compute/virtualMachines/AVD-RAGEN-1",
    "/subscriptions/####/resourceGroups/rg-avd-nonprod-remoteapps/providers/Microsoft.Compute/virtualMachines/AVD-RAGEN-2"
  ]
  #scopes              = [azurerm_storage_account.to_monitor.id]
  description              = ""
  enabled                  = true
  severity                 = "3"
  target_resource_type     = "Microsoft.Compute/virtualMachines"
  window_size              = "PT5M"
  frequency                = "PT5M"
  auto_mitigate            = true
  target_resource_location = "westus2"

  criteria {
    metric_namespace       = "Microsoft.Compute/virtualMachines"
    aggregation            = "Total"
    operator               = "GreaterThan"
    threshold              = 200000000000
    metric_name            = "Network Out Total"
    skip_metric_validation = false #default is false. 
  }

  action {
    action_group_id = azurerm_monitor_action_group.actiongroup.id
  }
}
*/

/*
  _                 _                                 
 | |               (_)          /\                    
 | |     ___   __ _ _  ___     /  \   _ __  _ __  ___ 
 | |    / _ \ / _` | |/ __|   / /\ \ | '_ \| '_ \/ __|
 | |___| (_) | (_| | | (__   / ____ \| |_) | |_) \__ \
 |______\___/ \__, |_|\___| /_/    \_\ .__/| .__/|___/
               __/ |                 | |   | |        
              |___/                  |_|   |_|        

Logic Apps are manually created. This section is kept here
as a reminder they exist.

lapp-avd-{env}-newvm-{region}
- Microsoft Form trigger to start runbook
- Runbook creates a new VM using a template spec
- User is emailed upon completion

lapp-avd-{env}-removevm-{region}
- Microsoft Form trigger to start runbook
- Runbook deletes a VM
- User is emailed upon completion
*/

/*
  _______                   _       _          _____                     
 |__   __|                 | |     | |        / ____|                    
    | | ___ _ __ ___  _ __ | | __ _| |_ ___  | (___  _ __   ___  ___ ___ 
    | |/ _ \ '_ ` _ \| '_ \| |/ _` | __/ _ \  \___ \| '_ \ / _ \/ __/ __|
    | |  __/ | | | | | |_) | | (_| | ||  __/  ____) | |_) |  __/ (__\__ \
    |_|\___|_| |_| |_| .__/|_|\__,_|\__\___| |_____/| .__/ \___|\___|___/
                     | |                            | |                  
                     |_|                            |_|                  

Template specs are manually created. This section is kept here
as a reminder they exist.

ts-avd-{env}-personalhost-{region}
*/