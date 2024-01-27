# Variables for main.tf file. These will get prompted at runtime or can be defined
# incline when running terraform. Additionally they can be declared in the .tfvar file
# in the variables folder

variable "env" {
  description = "Environment (prod, nonprod)"
  type        = string

  validation {
    condition     = contains(["prod", "nonprod"], var.env)
    error_message = "Valid values for var: env are (prod, nonprod)."
  }
}
# subscription
# -------------------------------------------------------------------------------------------------------
variable "primary_region" {
  description = "Primary Azure region to build resources."
  type        = string
}

# azure automation
# -------------------------------------------------------------------------------------------------------
variable "horizon_api_pw" {
  description = "Password for horizon api account."
  type        = string
  sensitive   = true
}

variable "hybrid_worker_pw" {
  description = "Password for hybrid worker service account."
  type        = string
  sensitive   = true
}

# storage
# -------------------------------------------------------------------------------------------------------
variable "storage_account_name" {
  description = "AZ storage account name. Must be under 15 chars and unique across all Azure."
  type        = string
}
variable "storage_sid" {
  description = "AZ storage account AD domain SID"
  type        = string
}
variable "storage_quota" {
  description = "AZ storage size quota"
  type        = number
}
variable "account_replication_type" {
  description = "AZ storage replication type"
  type        = string
}
variable "account_tier" {
  description = "AZ storage tier"
  type        = string
}
variable "account_kind" {
  description = "AZ storage kind"
  type        = string
}
# variable "subnet_id_list" {
#   description = "AllowList of Subnet IDs for Storage Access"
#   type        = list(any)
# }

# session hosts
# -------------------------------------------------------------------------------------------------------
variable "env_shortName" {
  description = "Abbreviation of Prod/NonProd"
  type        = string
}
variable "local_admin_username" {
  description = "Username for the local Administrator account."
  type        = string
}
variable "local_admin_pw" {
  description = "Virtual machine local admin password."
  type        = string
  sensitive   = true
}
variable "domain_join_upn" {
  description = "Domain join user principal name"
  sensitive   = true
}
variable "domain_join_pw" {
  description = "Domain join password"
  type        = string
  sensitive   = true
}
variable "url_avd_agent" {
  description = "URL of AVD agent install module from https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration.zip"
  type        = string
}
variable "url_ccm_agent" {
  description = "URL of custom powershell script"
  type        = string
}
variable "session_host_disk_type" {
  description = "Specify OS Disk Type."
  type        = string
}
variable "w10general_host_size" {
  description = "Azure VM Size."
  type        = string
}
variable "w11general_host_size" {
  description = "Azure VM Size."
  type        = string
}
variable "remoteapps_pci_host_size" {
  description = "Azure VM Size."
  type        = string
}
variable "remoteapps_general_host_size" {
  description = "Azure VM Size."
  type        = string
}
variable "w10general_host_count" {
  description = "Number of Session Hosts"
  type        = number
}
variable "w11general_host_count" {
  description = "Number of Session Hosts"
  type        = number
}
variable "remoteapps_pci_host_count" {
  description = "Number of Session Hosts"
  type        = number
}
variable "remoteapps_general_host_count" {
  description = "Number of Session Hosts"
  type        = number
}

# networking
# -------------------------------------------------------------------------------------------------------
variable "network_resource_group_name" {
  description = "Resource group name for networking resources."
  type        = string
}
variable "virtual_network_name" {
  description = "Name of Virtual Network (VNET)."
  type        = string
}
variable "subnets" {
  description = "Object containing subnet info"
  type        = map(any)
}
# variable "route_palo" {
#   description = "Object containing palo route info"
#   type        = map(any)
# }

# log analytics
# -------------------------------------------------------------------------------------------------------
variable "log_analytics_sku" {
  description = "Sku of the Log Analytics Workspace."
  type        = string
}
variable "log_analytics_retention_in_days" {
  description = "The workspace data retention in days."
  type        = number
}

# event hub
# -------------------------------------------------------------------------------------------------------
variable "event_hub_name_message_retention" {
  description = "Number of days to retain the events."
  type        = string
}

# tags
# -------------------------------------------------------------------------------------------------------
variable "tags" {
  description = "Resource tags."
  type        = map(any)
}

## applications
#-------------------------------------------------------------------------------------------------------
/* 
variable "example_remote_app" {
  description = "Map of Remote Apps to be provisioned together"
  type        = map(any)
  default = {
    RemoteApp_1 = {
      name                         = "App-Name-No-Spaces"
      friendly_name                = "Friendly Names can have spaces"
      description                  = "Descriptions can have spaces"
      path                         = "C:\\path\\example.exe"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\path\\example.exe"
      icon_index                   = 0
    }
    RemoteApp_2 = {...}
  }
 */ 
variable "remoteapps_configmgr" {
  description = "Map of ConfigManager apps to publish"
  type        = map(any)
  default = {
    ra_remoteviewer = {
      name                         = "CM-RemoteControlViewer"
      friendly_name                = "CM Remote Control Viewer"
      description                  = "CongifManager Remote Control Viewer"
      path                         = "C:\\Program Files (x86)\\Microsoft Endpoint Manager\\AdminConsole\\bin\\i386\\CmRcViewer.exe"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\Program Files (x86)\\Microsoft Endpoint Manager\\AdminConsole\\bin\\i386\\CmRcViewer.exe"
      icon_index                   = 0      
    },
    ra_supportcenter = {
      name                         = "CM-SupportCenter"
      friendly_name                = "CM Support Center Client Tools"
      description                  = "Support Center Client Tools"
      path                         = "C:\\Program Files (x86)\\Configuration Manager Support Center\\ConfigMgrClientTools.exe"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\Program Files (x86)\\Configuration Manager Support Center\\ConfigMgrClientTools.exe"
      icon_index                   = 0      
    },
    ra_cmconsole = {
      name                         = "CM-Console"
      friendly_name                = "Configuration Manager Console"
      description                  = "Configuration Manager Console"
      path                         = "C:\\Program Files (x86)\\Microsoft Endpoint Manager\\AdminConsole\\bin\\Microsoft.ConfigurationManagement.exe"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\Program Files (x86)\\Microsoft Endpoint Manager\\AdminConsole\\bin\\Microsoft.ConfigurationManagement.exe"
      icon_index                   = 0     
    }
  }
}

variable "remoteapps_secureconfigmgr" {
  description = "Map of ConfigManager apps to publish"
  type        = map(any)
  default = {
    ra_runas_remoteviewer = {
      name                         = "Secure-CM-RemoteControlViewer"
      friendly_name                = "Secure CM Remote Control Viewer"
      description                  = "Secure RunAs, will prompt for secondary credentials."
      path                         = "C:\\RunAs\\PSRunAs.vbs"
      command_line_argument_policy = "Require"
      command_line_arguments       = "C:\\Program Files (x86)\\Microsoft Endpoint Manager\\AdminConsole\\bin\\i386\\CmRcViewer.exe"
      icon_path                    = "C:\\Program Files (x86)\\Microsoft Endpoint Manager\\AdminConsole\\bin\\i386\\CmRcViewer.exe"
      icon_index                   = 0
      #show_in_portal               = false #Do Not show in Web Portal
    },
    ra_runas_supportcenter = {
      name                         = "Secure-CM-SupportCenter"
      friendly_name                = "Secure CM Support Center Client Tools"
      description                  = "Secure RunAs, will prompt for secondary credentials."
      path                         = "C:\\RunAs\\PSRunAs.vbs"
      command_line_argument_policy = "Require"
      command_line_arguments       = "C:\\Program Files (x86)\\Configuration Manager Support Center\\ConfigMgrClientTools.exe"
      icon_path                    = "C:\\Program Files (x86)\\Configuration Manager Support Center\\ConfigMgrClientTools.exe"
      icon_index                   = 0
    },
    ra_runas_cmconsole = {
      name                         = "Secure-CM-Console"
      friendly_name                = "Secure CM Console"
      description                  = "Secure RunAs, will prompt for secondary credentials."
      path                         = "C:\\RunAs\\PSRunAs.vbs"
      command_line_argument_policy = "Require"
      command_line_arguments       = "C:\\Program Files (x86)\\Microsoft Endpoint Manager\\AdminConsole\\bin\\Microsoft.ConfigurationManagement.exe"
      icon_path                    = "C:\\Program Files (x86)\\Microsoft Endpoint Manager\\AdminConsole\\bin\\Microsoft.ConfigurationManagement.exe"
      icon_index                   = 0
    }
  }
}

variable "remoteapps" {
  description = "Map of all RemoteApps to publish"
  type        = map(any)
  default = {
    ra_notepad = {
      name                         = "notepadplus"
      friendly_name                = "Notepad++"
      description                  = "Notepad++"
      path                         = "C:\\Program Files\\Notepad++\\notepad++.exe"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\Program Files\\Notepad++\\notepad++.exe"
      icon_index                   = 0
    },
    ra_adobe = {
      name                         = "adobereader"
      friendly_name                = "Adobe Reader DC"
      description                  = "Adobe Reader DC"
      path                         = "C:\\Program Files (x86)\\Adobe\\Acrobat Reader DC\\Reader\\AcroRd32.exe"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\Program Files (x86)\\Adobe\\Acrobat Reader DC\\Reader\\AcroRd32.exe"
      icon_index                   = 0
    },
    ra_ha = {
      name                         = "Microsoft-Edge-HorizonApps"
      friendly_name                = "Horizon Apps"
      description                  = "Modern Edge browser based on Chromium."
      path                         = "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe"
      command_line_argument_policy = "Require"
      command_line_arguments       = "https://HorizonApps.DOMAIN.net/portal/webclient/index.html"
      icon_path                    = "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe"
      icon_index                   = 0
    },
    ra_edge = {
      name                         = "Microsoft-Edge"
      friendly_name                = "Microsoft Edge"
      description                  = "Modern Edge browser based on Chromium."
      path                         = "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe"
      icon_index                   = 0
    }
  }
}

variable "remoteapps_rsat" {
  description = "Map of RSAT apps to publish"
  type        = map(any)
  default = {
    ra_adac = {
      name                         = "AD-AdministrativeCenter"
      friendly_name                = "Active Directory Administrative Center"
      description                  = "Active Directory Administrative Center"
      path                         = "C:\\Windows\\system32\\dsac.exe"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\Windows\\system32\\dsacn.dll"
      icon_index                   = 0
    },
    ra_aduc = {
      name                         = "AD-UsersComputers"
      friendly_name                = "Active Directory Users and Computers"
      description                  = "Active Directory Users and Computers"
      path                         = "C:\\Windows\\system32\\dsa.msc"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\Windows\\system32\\dsadmin.dll"
      icon_index                   = 0
    },
    ra_addfs = {
      name                         = "AD-DFSManagement"
      friendly_name                = "AD DFS Management"
      description                  = "Active Directory DFS Management"
      path                         = "C:\\Windows\\system32\\dfsmgmt.msc"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\Windows\\system32\\dfsres.dll"
      icon_index                   = 0
    },
    ra_addhcp = {
      name                         = "AD-DHCP"
      friendly_name                = "DHCP"
      description                  = "AD DHCP"
      path                         = "C:\\Windows\\system32\\dhcpmgmt.msc"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\Windows\\system32\\dhcpsnap.dll"
      icon_index                   = 0
    },
    ra_addns = {
      name                         = "AD-DNSManagement"
      friendly_name                = "DNS Management"
      description                  = "Active Directory DNS Management"
      path                         = "C:\\Windows\\system32\\dnsmgmt.msc"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\Windows\\system32\\dnsmgr.dll"
      icon_index                   = 0
    },
    ra_adgpmc = {
      name                         = "AD-GroupPolicyManagement"
      friendly_name                = "Group Policy Management"
      description                  = "AD Group Policy Management Console"
      path                         = "C:\\Windows\\system32\\gpmc.msc"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\Windows\\system32\\gpoadmin.dll"
      icon_index                   = 0
    },
    ra_prntmgmt = {
      name                         = "Print-Management"
      friendly_name                = "Print Management"
      description                  = "Print Management"
      path                         = "c:\\Windows\\System32\\printmanagement.msc"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "c:\\Windows\\System32\\pmcsnap.dll"
      icon_index                   = 0
    },
    ra_adsites = {
      name                         = "AD-Sites"
      friendly_name                = "Sites and Services"
      description                  = "AD Sites & Services"
      path                         = "c:\\Windows\\System32\\dssite.msc"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "c:\\Windows\\System32\\dsadmin.dll"
      icon_index                   = 2
    },
    ad_ac = {
      name                         = "Windows-AdminCenter"
      friendly_name                = "Windows Admin Center"
      description                  = "Windows Administration and Troubleshooting Console"
      path                         = "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe"
      command_line_argument_policy = "Require"
      icon_path                    = "C:\\Windows\\System32\\CompMgmtLauncher.exe"
      command_line_arguments       = "https://WinAdmin.Domain.net"
      icon_index                   = 0
      
    },
    ra_runas_adac = {
      name                         = "RunAs-AD-AdministrativeCenter"
      friendly_name                = "RunAs Active Directory Administrative Center"
      description                  = "RunAs, will prompt for secondary credentials."
      path                         = "C:\\RunAs\\PSRunAs.vbs"
      command_line_argument_policy = "Require"
      command_line_arguments       = "C:\\Windows\\system32\\dsac.exe"
      icon_path                    = "C:\\Windows\\system32\\dsacn.dll"
      icon_index                   = 0
    },
    ra_runas_aduc = {
      name                         = "RunAs-AD-UsersComputers"
      friendly_name                = "RunAs Active Directory Users and Computers"
      description                  = "RunAs, will prompt for secondary credentials."
      path                         = "C:\\RunAs\\PSRunAs.vbs"
      command_line_argument_policy = "Require"
      command_line_arguments       = "C:\\Windows\\system32\\dsa.msc"
      icon_path                    = "C:\\Windows\\system32\\dsadmin.dll"
      icon_index                   = 0
    },
    ra_runas_addfs = {
      name                         = "RunAs-AD-DFSManagement"
      friendly_name                = "RunAs AD DFS Management"
      description                  = "RunAs, will prompt for secondary credentials."
      path                         = "C:\\RunAs\\PSRunAs.vbs"
      command_line_argument_policy = "Require"
      command_line_arguments       = "C:\\Windows\\system32\\dfsmgmt.msc"
      icon_path                    = "C:\\Windows\\system32\\dfsres.dll"
      icon_index                   = 0
    },
    ra_runas_addhcp = {
      name                         = "RunAs-AD-DHCP"
      friendly_name                = "RunAs DHCP"
      description                  = "RunAs, will prompt for secondary credentials."
      path                         = "C:\\RunAs\\PSRunAs.vbs"
      command_line_argument_policy = "Require"
      command_line_arguments       = "C:\\Windows\\system32\\dhcpmgmt.msc"
      icon_path                    = "C:\\Windows\\system32\\dhcpsnap.dll"
      icon_index                   = 0
    },
    ra_runas_addns = {
      name                         = "RunAs-AD-DNSManagement"
      friendly_name                = "RunAs DNS Management"
      description                  = "RunAs, will prompt for secondary credentials."
      path                         = "C:\\RunAs\\PSRunAs.vbs"
      command_line_argument_policy = "Require"
      command_line_arguments       = "C:\\Windows\\system32\\dnsmgmt.msc"
      icon_path                    = "C:\\Windows\\system32\\dnsmgr.dll"
      icon_index                   = 0
    },
    ra_runas_adgpmc = {
      name                         = "RunAs-AD-GroupPolicyManagement"
      friendly_name                = "RunAs Group Policy Management"
      description                  = "RunAs, will prompt for secondary credentials."
      path                         = "C:\\RunAs\\PSRunAs.vbs"
      command_line_argument_policy = "Require"
      command_line_arguments       = "C:\\Windows\\system32\\gpmc.msc"
      icon_path                    = "C:\\Windows\\system32\\gpoadmin.dll"
      icon_index                   = 0
    },
    ra_runas_prntmgmt = {
      name                         = "RunAs-Print-Management"
      friendly_name                = "RunAs Print Management"
      description                  = "RunAs, will prompt for secondary credentials."
      path                         = "C:\\RunAs\\PSRunAs.vbs"
      command_line_argument_policy = "Require"
      command_line_arguments       = "c:\\Windows\\System32\\printmanagement.msc"
      icon_path                    = "c:\\Windows\\System32\\pmcsnap.dll"
      icon_index                   = 0
    },
    ra_runas_adsites = {
      name                         = "RunAs-AD-Sites"
      friendly_name                = "RunAs Sites and Services"
      description                  = "RunAs, will prompt for secondary credentials."
      path                         = "C:\\RunAs\\PSRunAs.vbs"
      command_line_argument_policy = "Require"
      command_line_arguments       = "c:\\Windows\\System32\\dssite.msc"
      icon_path                    = "c:\\Windows\\System32\\dsadmin.dll"
      icon_index                   = 2
      
    }
  }
}

variable "remoteapps_configmgr" {
  description = "Map of ConfigManager apps to publish"
  type        = map(any)
  default = {
    ra_remoteviewer = {
      name                         = "CM-RemoteControlViewer"
      friendly_name                = "CM Remote Control Viewer"
      description                  = "CongifManager Remote Control Viewer"
      path                         = "C:\\Program Files (x86)\\Microsoft Endpoint Manager\\AdminConsole\\bin\\i386\\CmRcViewer.exe"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\Program Files (x86)\\Microsoft Endpoint Manager\\AdminConsole\\bin\\i386\\CmRcViewer.exe"
      icon_index                   = 0
      
    },
    ra_supportcenter = {
      name                         = "CM-SupportCenter"
      friendly_name                = "CM Support Center Client Tools"
      description                  = "Support Center Client Tools"
      path                         = "C:\\Program Files (x86)\\Configuration Manager Support Center\\ConfigMgrClientTools.exe"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\Program Files (x86)\\Configuration Manager Support Center\\ConfigMgrClientTools.exe"
      icon_index                   = 0
      
    },
    ra_cmconsole = {
      name                         = "CM-Console"
      friendly_name                = "Configuration Manager Console"
      description                  = "Configuration Manager Console"
      path                         = "C:\\Program Files (x86)\\Microsoft Endpoint Manager\\AdminConsole\\bin\\Microsoft.ConfigurationManagement.exe"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\Program Files (x86)\\Microsoft Endpoint Manager\\AdminConsole\\bin\\Microsoft.ConfigurationManagement.exe"
      icon_index                   = 0
      
    },
    ra_runas_remoteviewer = {
      name                         = "RunAs-CM-RemoteControlViewer"
      friendly_name                = "RunAs CM Remote Control Viewer"
      description                  = "RunAs, will prompt for secondary credentials."
      path                         = "C:\\RunAs\\PSRunAs.vbs"
      command_line_argument_policy = "Require"
      command_line_arguments       = "C:\\Program Files (x86)\\Microsoft Endpoint Manager\\AdminConsole\\bin\\i386\\CmRcViewer.exe"
      icon_path                    = "C:\\Program Files (x86)\\Microsoft Endpoint Manager\\AdminConsole\\bin\\i386\\CmRcViewer.exe"
      icon_index                   = 0
      
    },
    ra_runas_supportcenter = {
      name                         = "RunAs-CM-SupportCenter"
      friendly_name                = "RunAs CM Support Center Client Tools"
      description                  = "RunAs, will prompt for secondary credentials."
      path                         = "C:\\RunAs\\PSRunAs.vbs"
      command_line_argument_policy = "Require"
      command_line_arguments       = "C:\\Program Files (x86)\\Configuration Manager Support Center\\ConfigMgrClientTools.exe"
      icon_path                    = "C:\\Program Files (x86)\\Configuration Manager Support Center\\ConfigMgrClientTools.exe"
      icon_index                   = 0
      
    },
    ra_runas_cmconsole = {
      name                         = "RunAs-CM-Console"
      friendly_name                = "RunAs Configuration Manager Console"
      description                  = "RunAs, will prompt for secondary credentials."
      path                         = "C:\\RunAs\\PSRunAs.vbs"
      command_line_argument_policy = "Require"
      command_line_arguments       = "C:\\Program Files (x86)\\Microsoft Endpoint Manager\\AdminConsole\\bin\\Microsoft.ConfigurationManagement.exe"
      icon_path                    = "C:\\Program Files (x86)\\Microsoft Endpoint Manager\\AdminConsole\\bin\\Microsoft.ConfigurationManagement.exe"
      icon_index                   = 0
      
    }
  }
}

variable "remoteapps_pbi" {
  description = "Map of Power BI apps to publish"
  type        = map(any)
  default = {
    ra_powerbi_desktop = {
      name                         = "PowerBI-Desktop"
      friendly_name                = "Power BI Desktop"
      description                  = "Microsoft Power BI Desktop"
      path                         = "C:\\Program Files\\Microsoft Power BI Desktop\\bin\\PBIDesktop.exe"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\Program Files\\Microsoft Power BI Desktop\\bin\\PBIDesktop.exe"
      icon_index                   = 0
    },
    ra_powerbi_reportbuilder = {
      name                         = "PowerBI-ReportBuilder"
      friendly_name                = "Power BI Report Builder"
      description                  = "Microsoft Power BI Report Builder"
      path                         = "C:\\Program Files\\Power BI Report Builder\\PowerBIReportBuilder.exe"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\Program Files\\Power BI Report Builder\\PowerBIReportBuilder.exe"
      icon_index                   = 0
    }
  }
}

variable "remoteapps_pwsh" {
  description = "Map of powershell apps to publish"
  type        = map(any)
  default = {
    ra_powershell7 = {
      name                         = "Powershell7"
      friendly_name                = "Powershell 7"
      description                  = "Powershell 7 (x64)"
      path                         = "C:\\Program Files\\PowerShell\\7\\pwsh.exe"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = ""
      icon_path                    = "C:\\Program Files\\PowerShell\\7\\pwsh.exe"
      icon_index                   = 0
    },
    ra_powershellise = {
      name                         = "Powershell-ISE"
      friendly_name                = "Powershell ISE"
      description                  = "Powershell 5"
      path                         = "c:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell_ise.exe"
      command_line_argument_policy = "Allow"
      command_line_arguments       = ""
      icon_path                    = "c:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell_ise.exe"
      icon_index                   = 0
    }
  }
}

variable "remoteapps_sftp" {
  description = "Map of MS Visio to publish"
  type        = map(any)
  default = {
    ra_putty = {
      name                         = "PuTTY"
      friendly_name                = "PuTTY"
      description                  = "Putty"
      path                         = "C:\\Program Files\\PuTTY\\putty.exe"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\Program Files\\PuTTY\\putty.exe"
      icon_index                   = 0
      
    },
    ra_winscp = {
      name                         = "WinSCP"
      friendly_name                = "WinSCP"
      description                  = "WinSCP"
      path                         = "C:\\Program Files (x86)\\WinSCP\\WinSCP.exe"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\Program Files (x86)\\WinSCP\\WinSCP.exe"
      icon_index                   = 0
    }
  }
}

variable "remoteapps_keypass" {
  description = "Map of Keypass to publish"
  type        = map(any)
  default = {
    ra_keypass = {
      name                         = "keypass"
      friendly_name                = "KeyPass"
      description                  = "KeyPass"
      path                         = "C:\\Program Files (x86)\\KeePass2x\\KeePass.exe"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\Program Files (x86)\\KeePass2x\\KeePassIcon.ico"
      icon_index                   = 0
    }
  }
}

variable "remoteapps_lapsui" {
  description = "Map of LAPS-UI to publish"
  type        = map(any)
  default = {
    ra_laps = {
      name                         = "LAPS-UI"
      friendly_name                = "LAPS UI"
      description                  = "LAPS UI"
      path                         = "C:\\Program Files\\LAPS\\AdmPwd.UI.exe"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\Program Files\\LAPS\\AdmPwd.UI.exe"
      icon_index                   = 0
    }
    ra_runaslaps = {
      name                         = "RunAs-LAPS-UI"
      friendly_name                = "RunAs-LAPS UI"
      description                  = "RunAs, will prompt for secondary credentials."
      path                         = "C:\\RunAs\\PSRunAs.vbs"
      command_line_argument_policy = "Require"
      command_line_arguments       = "C:\\Program Files\\LAPS\\AdmPwd.UI.exe"
      icon_path                    = "C:\\Program Files\\LAPS\\AdmPwd.UI.exe"
      icon_index                   = 0      
    }
  }
}

variable "remoteapps_project" {
  description = "Map of MS Project to publish"
  type        = map(any)
  default = {
    ra_project = {
      name                         = "Microsoft-Project"
      friendly_name                = "Microsoft Project"
      description                  = "Microsoft 365 Project"
      path                         = "C:\\Program Files\\Microsoft Office\\root\\Office16\\WINPROJ.EXE"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\Program Files\\Microsoft Office\\root\\Office16\\WINPROJ.EXE"
      icon_index                   = 0
      
    }
  }
}

variable "remoteapps_visio" {
  description = "Map of MS Visio to publish"
  type        = map(any)
  default = {
    ra_visio = {
      name                         = "Microsoft-Visio"
      friendly_name                = "Microsoft Visio"
      description                  = "Microsoft 365 Visio"
      path                         = "C:\\Program Files\\Microsoft Office\\root\\Office16\\VISIO.EXE"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\Program Files\\Microsoft Office\\root\\Office16\\VISIO.EXE"
      icon_index                   = 0
    }
  }
}

variable "remoteapps_ssms" {
  description = "Map of SQL Mgmt Studio to publish"
  type        = map(any)
  default = {
    ra_ssms = {
      name                         = "MSSQL-ManagementStudio"
      friendly_name                = "Microsoft SQL Server Management Studio 18"
      description                  = "Microsoft SQL Server Management Studio 18"
      path                         = "C:\\Program Files (x86)\\Microsoft SQL Server Management Studio 18\\Common7\\IDE\\Ssms.exe"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\Program Files (x86)\\Microsoft SQL Server Management Studio 18\\Common7\\IDE\\Ssms.exe"
      icon_index                   = 0
    }
  }
}
      
variable "remoteapps_avaya" {
  description = "Map of Avaya CMS Supervisor to publish"
  type        = map(any)
  default = {
    ra_avaya = {
      name                         = "Avaya-CMS-Supervisor"
      friendly_name                = "Avaya CMS Supervisor"
      description                  = "Avaya CMS Supervisor"
      path                         = "C:\\Program Files (x86)\\Avaya\\CMS Supervisor R19\\acsRun.exe"
      command_line_argument_policy = "Require"
      command_line_arguments       = "/L:enu"
      icon_path                    = "C:\\Program Files (x86)\\Avaya\\CMS Supervisor R19\\acsRun.exe"
      icon_index                   = 0
    }
  }
}

variable "remoteapps_mstsc" {
  description = "Map of Microsoft Remote Desktop Connection to publish"
  type        = map(any)
  default = {
    ra_mstsc = {
      name                         = "Remote-Desktop-Connection"
      friendly_name                = "Remote Desktop Connection"
      description                  = "Microsoft Remote Desktop Connection"
      path                         = "C:\\Windows\\System32\\mstsc.exe"
      command_line_argument_policy = "DoNotAllow"
      command_line_arguments       = null
      icon_path                    = "C:\\Windows\\System32\\mstsc.exe"
      icon_index                   = 0
    }
  }
}