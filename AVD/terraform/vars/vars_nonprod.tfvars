# Define the variables declared in variables.tf
# -------------------------------------------------------------------------------------------------------

# tags
tags = {
  description = "Azure Virtual Desktop"
  managedBy   = "terraform"
  env         = "nonprod"
}

# subscription
primary_region = "westus2"

# virtual machines
local_admin_username = "localadmin"
domain_join_upn      = "adjoin@domain.com"
url_avd_agent        = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_03-24-2022.zip"
url_ccm_agent        = "https://az-storage-account.blob.core.windows.net/armdeployments/ccmbootstrap.ps1"

# networking
network_resource_group_name = "Subscription_Network_RG"
virtual_network_name        = "internal-network"

# subnet info
subnets = {
  mgmt_name1   = "internal-mgmt-01"
  mgmt_subnet1 = ""

  infra_name1   = "internal-infra-01"
  infra_subnet1 = ""

  # Palo Alto FW subnets
  palo_name1   = "internal-palo-01"
  palo_subnet1 = ""

  palo_name2   = "internal-palo-02"
  palo_subnet2 = ""

  palo_name3   = "internal-palo-03"
  palo_subnet3 = ""

  # Desktop subnets
  desktop_name1   = "internal-desktops-01"
  desktop_subnet1 = ""

  desktop_name2   = "internal-desktops-02"
  desktop_subnet2 = ""

  desktop_name3   = "internal-desktops-03"
  desktop_subnet3 = ""
}

route_palo_loop = {
  name                   = ""
  address_prefix         = ""
  next_hop_in_ip_address = ""
}

# route_palo = {
#   name                   = "Default"
#   address_prefix         = "0.0.0.0/0"
#   next_hop_in_ip_address = ""
# }

# log analytics
log_analytics_sku               = "PerGB2018"
log_analytics_retention_in_days = "30"

# event hub
event_hub_name_message_retention = "1"

#fslogix storage vars
storage_account_name     = "AZ_StorageAccount_Name_Prod"
storage_sid              = "" #AD SID for binding Storage Account
storage_quota            = 100
account_replication_type = "LRS"
account_tier             = "Standard"
account_kind             = "StorageV2"

#Used for SessionHost env Abbreviation 
env_shortName = "N"

#SessionHost (VM) OS Disk Type 
session_host_disk_type = "Standard_LRS"

#SessionHost Count
w10general_host_count         = "1"
w11general_host_count         = "0"
remoteapps_pci_host_count     = "2"
remoteapps_general_host_count = "1"

#SessionHost Size
w10general_host_size         = "Standard_D2as_v5"
w11general_host_size         = "Standard_D2as_v5"
remoteapps_pci_host_size     = "Standard_D2as_v5"
remoteapps_general_host_size = "Standard_D2as_v5"