#https://docs.microsoft.com/en-us/fslogix/

#New Blank GPO
#$GPO = New-FSlogixGPO -NamingScheme $NamingScheme -GPO_Type $MultiSession
function New-FSlogixGPO {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True)][string] $NamingScheme,
        [Parameter(Mandatory=$True)][ValidateSet("SingleSession","MultiSession")][string] $GPO_Type
    )
    $GPOName = "FSLogix_$($GPO_Type)_$($NamingScheme)-$(Get-Date -f yy.MM)a"
    $GPO = New-GPO -Name $GPOName
    return $GPO
}

#Set GPO Delegated Permissions
#Set-Fslogix-DelegatedAdmins -GPO $GPO
function Set-Fslogix-DelegatedAdmins{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ([Parameter(Mandatory=$True)][string] $GPO)
    Write-Output "Setting GPO Permissions"
    Set-GPPermission -Name $GPO -Replace -PermissionLevel GpoEditDeleteModifySecurity -TargetName "GroupPolicyManagement-CorpClientGPOs-FullControl" -TargetType Group  | Out-Null       
}

#Set FSlogix Profile Contriner Config
#Set-FSlogixGPO-Profile_Config -GPO $GPO
function Set-FSlogixGPO-Profile_Config {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ([Parameter(Mandatory=$True)][string] $GPO)
    Set-GPRegistryValue -Name $GPO -Key "HKLM\Software\FSLogix\Profiles" -ValueName "Enabled" -Type DWord -Value 1 | Out-Null
    Set-GPRegistryValue -Name $GPO -Key "HKLM\Software\FSLogix\Profiles" -ValueName "FlipFlopProfileDirectoryName" -Type DWord -Value 1 | Out-Null
    Set-GPRegistryValue -Name $GPO -Key "HKLM\Software\FSLogix\Profiles" -ValueName "OutlookCachedMode" -Type DWord -Value 1 | Out-Null
}

#Set FSlogix Office Contriner Config
#Set-FSlogixGPO-Office_Config -GPO $GPO
function Set-FSlogixGPO-Office_Config {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ([Parameter(Mandatory=$True)][string] $GPO)
    try {
        Set-GPRegistryValue -Name $GPO -Key "HKLM\Software\Policies\FSLogix\ODFC" -ValueName "Enabled" -Type DWord -Value 1 | Out-Null
        Set-GPRegistryValue -Name $GPO -Key "HKLM\Software\Policies\FSLogix\ODFC" -ValueName "FlipFlopProfileDirectoryName" -Type DWord -Value 1 | Out-Null
        Set-GPRegistryValue -Name $GPO -Key "HKLM\Software\Policies\FSLogix\ODFC" -ValueName "IncludeOfficeActivation" -Type DWord -Value 1 | Out-Null
        Set-GPRegistryValue -Name $GPO -Key "HKLM\Software\Policies\FSLogix\ODFC" -ValueName "IncludeOfficeFileCache" -Type DWord -Value 1 | Out-Null
        Set-GPRegistryValue -Name $GPO -Key "HKLM\Software\Policies\FSLogix\ODFC" -ValueName "IncludeOneDrive" -Type DWord -Value 1 | Out-Null
        Set-GPRegistryValue -Name $GPO -Key "HKLM\Software\Policies\FSLogix\ODFC" -ValueName "IncludeOneNote" -Type DWord -Value 1 | Out-Null
        Set-GPRegistryValue -Name $GPO -Key "HKLM\Software\Policies\FSLogix\ODFC" -ValueName "IncludeOutlook" -Type DWord -Value 1 | Out-Null
        Set-GPRegistryValue -Name $GPO -Key "HKLM\Software\Policies\FSLogix\ODFC" -ValueName "IncludeOutlookPersonalization" -Type DWord -Value 1 | Out-Null
        Set-GPRegistryValue -Name $GPO -Key "HKLM\Software\Policies\FSLogix\ODFC" -ValueName "IncludeSharepoint" -Type DWord -Value 1 | Out-Null
        Set-GPRegistryValue -Name $GPO -Key "HKLM\Software\Policies\FSLogix\ODFC" -ValueName "IncludeTeams" -Type DWord -Value 1 | Out-Null
        Set-GPRegistryValue -Name $GPO -Key "HKLM\Software\Policies\FSLogix\ODFC" -ValueName "RemoveOrphanedOSTFilesOnLogoff" -Type DWord -Value 1 | Out-Null
    }
    catch{$Error}
}

#Set the FSlogix Container Volume Type to VHDX
#Set-FSlogixGPO-Volume_Type -GPO $GPO
function Set-FSlogixGPO-Volume_Type {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ([Parameter(Mandatory=$True)][string] $GPO)
    Set-GPRegistryValue -Name $GPO -Type String -Key "HKLM\Software\FSLogix\Profiles" -ValueName "VolumeType" -Value "VHDX" | Out-Null     
    Set-GPRegistryValue -Name $GPO -Type String -Key "HKLM\Software\Policies\FSLogix\ODFC" -ValueName "VolumeType" -Value "VHDX" | Out-Null
}

##Search Roaming
#https://docs.microsoft.com/en-us/fslogix/configure-search-roaming-ht#configure-multi-user-search
#1=SingleSession  |  2=MultiSession
#Set-FSlogixGPO-Search_Roaming -GPO $GPO -RoamSearch <0,1,2>
function Set-FSlogixGPO-Search_Roaming {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True)][string] $GPO,
        [Parameter(Mandatory=$True,HelpMessage="0 for disabled, 1 for singleSession, 2 for multi session")][ValidateSet(0,1,2)][int]$RoamSearch
    )
    Set-GPRegistryValue -Name $GPO -Key "HKLM\Software\FSLogix\Profiles" -ValueName "RoamSearch" -Type DWord -Value $RoamSearch | Out-Null
    Set-GPRegistryValue -Name $GPO -Key "HKLM\Software\FSLogix\Apps" -ValueName "RoamSearch" -Type DWord -Value $RoamSearch | Out-Null
}

#Set FSlogix File Paths for Redirection.xml and FSlogix Profile/Office Coontainers
#Set-FSlogixGPO-FolderPath -GPO $GPO -FolderPath "\\stavdfslogixdev.file.core.windows.net\fslogix-profiles" -UserProfileShare "RAGEN"
function Set-FSlogixGPO-FolderPath {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True)][string]$GPO,
        [Parameter(Mandatory=$True)][string]$FolderPath,
        [Parameter(Mandatory=$True)][string]$UserProfileShare
    )
Set-GPRegistryValue -Name $GPO -Type String -Key "HKLM\Software\FSLogix\Profiles"-ValueName "RedirXMLSourceFolder" -Value $("$($FolderPath)\Redirections") | Out-Null
Set-GPRegistryValue -Name $GPO -Type String -Key "HKLM\Software\FSLogix\Profiles"-ValueName "VHDLocations" -Value $($FolderPath)\$($UserProfileShare) | Out-Null
Set-GPRegistryValue -Name $GPO -Type String -Key "HKLM\Software\Policies\FSLogix\ODFC" -ValueName "VHDLocations"  -Value $($FolderPath)\$($UserProfileShare) | Out-Null
}

 function New-GPO_from_null{
      $GPO = New-FSlogixGPO -NamingScheme RAGEN -GPO_Type MultiSession
      Set-GPRegistryValue -Name $GPO.DisplayName -Key "HKLM\Software\FSLogix\Logging" -ValueName "LoggingEnabled" -Type DWord -Value 0 | Out-Null
      (Get-GPO $($GPO.DisplayName)).GpoStatus = "UserSettingsDisabled"
      Set-FSlogixGPO-Profile_Config -GPO $GPO.DisplayName
      Set-FSlogixGPO-Office_Config -GPO $GPO.DisplayName
      Set-FSlogixGPO-Volume_Type -GPO $GPO.DisplayName
      Set-FSlogixGPO-Search_Roaming -GPO $GPO.DisplayName -RoamSearch 1
      Set-FSlogixGPO-FolderPath -GPO $GPO.DisplayName -FolderPath $FolderPath -UserProfileShare $UserProfileShare
      Set-Fslogix-DelegatedAdmins -GPO $GPO.DisplayName -Unit $UnitName
 }


<#

#Create New GPO from Starter GPO
function New-FSLogixGPO {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True,HelpMessage="SingleSession or MultiSession")][ValidateSet("SingleSession","MultiSession")][string] $SearchRoaming,
        [Parameter()][string]$NamingScheme
    )
    if (!($NamingScheme)){Write-Error "Missing Naming Scheme"; break}
    switch ($SearchRoaming) {
        #Enable search roaming
        #######################
        SingleSession {
            #single session search
            $SourceGPO = "Fslogix_SingleSession_Computer"
            $NewGPOName = "FSLlogix_singlesession_$NamingScheme-$(Get-Date -f yy.MM)a"
            break
        } 
        MultiSession {
            #multi session search
            $SourceGPO = "Fslogix_MultiSession_Computer"
            $NewGPOName = "FSLogix_multisession_$NamingScheme-$(Get-Date -f yy.MM)a"
            break
        }
    }
    if (@(Get-GPO $NewGPOName -ErrorAction SilentlyContinue).Count) {
        Write-Error "GPO '$($NewGPOName)' already exists"; break} 
    else {
        Write-Host -ForegroundColor DarkYellow "GPO '$($NewGPOName)' not found in domain, creating New GPO"
        New-GPO -Name $NewGPOName -StarterGpoName $SourceGPO | Out-Null
        Write-Host -ForegroundColor DarkYellow "Waiting for AD replication...";Start-Sleep -Seconds 10
    }
    $GPOName = (Get-GPO -Name $NewGPOName).DisplayName
    return $GPOName
}

function New-FSlogixGPO_from_StarterGPO {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True)][string] $UnitName,$NamingScheme,
        [Parameter(Mandatory=$True)][ValidateSet("SingleSession","MultiSession")][string] $GPO_Type
    )
    $GPOName = "Xen-Fslogix-$UnitName-$NamingScheme-$GPO_Type"
    $GPO = switch ($GPO_Type){
        SingleSession {New-GPO -Name $GPOName -StarterGpoName Fslogix_MultiSession_Computer}
        MultiSession {New-GPO -Name $GPOName -StarterGpoName Fslogix_SingleSession_Computer}
    }
    return $GPOName
}

function New-GPO_from_StarterGPO{
    $GPO = New-FSlogixGPO_from_StarterGPO -UnitName OIT -NamingScheme 2021 -GPO_Type SingleSession
    Set-FSlogixGPO-FolderPath -GPO $GPO.DisplayName -FolderPath $FolderPath -UserProfileShare $UserProfileShare
    Set-Fslogix-DelegatedAdmins -GPO $GPO.DisplayName -Unit $UnitName
 }

#Default Log Dir %ProgramData%\FSLogix\Logs
#https://docs.microsoft.com/en-us/fslogix/logging-diagnostics-reference#logging-settings-and-configuration
Set-GPRegistryValue -Name $GPO.DisplayName -Key "HKLM\Software\FSLogix\Logging" -ValueName "LoggingEnabled" -Type DWord -Value 0 | Out-Null

#Disable GPO User Settings
(Get-GPO $($GPO.DisplayName)).GpoStatus = "UserSettingsDisabled"

#>