<#
.SYNOPSIS
This was designed to provision new resources within Azure Virtual Desktop. 
Custom functions can be combined to fully provision resources. 

.DESCRIPTION
REQUIRES Modules: AZ, Az.DesktopVirtualization, AzureAD, & ActiveDirectory.

Call functions as needed. Use tab complete on each function to see available parameters.
Functions were designed to be modular and used in combination to simplify routine tasks. 
Some functions will stop on error, while others will alert and continue.
Parameters could be optional or mandatory. If a parameter is not provided, some functions will auto-generate results. 
Assign a variable to a function, and use the variable in other functions as an input parameter.

.NOTES
To Package: Azure Virtual Desktop Agent and Azure Virtual Desktop Agent Bootloader???
Located Here: https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv & https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH
https://docs.microsoft.com/en-us/azure/virtual-desktop/create-host-pools-powershell#prepare-the-virtual-machines-for-azure-virtual-desktop-agent-installations
https://docs.microsoft.com/en-us/azure/virtual-desktop/create-host-pools-powershell#register-the-virtual-machines-to-the-azure-virtual-desktop-host-pool

.EXAMPLE

Connect with psRemote to run command on remote Azure VM.
Add-LocalAdmin -VMName $VMName -ADUser $ADUser


.Notes
Add Drain Mode Function On/OFF
Add Scaling Plan function
Add Az-WvdMsixPackage? 
#>

[CmdletBinding(SupportsShouldProcess=$True)]
Param(
    [Parameter(Mandatory=$false,HelpMessage="Azure Region")]
    [String]$LocationName="westus2",
    [Parameter(Mandatory=$true,HelpMessage="AD Domain Name")]
    [String]$DomainName,
    [Parameter(Mandatory=$true,HelpMessage="Prod or NonProd")]
    [ValidateSet("prod","nonprod")][String]$Environment
)

#  [Parameter(Mandatory=$true,HelpMessage="Pool or Personal")]
#  [ValidateSet("pool","personal")][String]$PoolType,


#Install Modules if needed. 
if (!(Get-Module AZ -ListAvailable)) {
    #Install-Module -Name Az -AllowClobber -Force -Confirm:$false | Out-Null
    import-Module -Name Az
}
if (!(Get-Module Az.DesktopVirtualization)) {
    #Install-Module -Name Az.DesktopVirtualization -Force -Confirm:$false | Out-Null
    import-Module -Name Az.DesktopVirtualization
}
if (!(Get-Module AzureAD)) {
    #Install-Module -Name AzureAD -Force -Confirm:$false | Out-Null
    import-Module -Name AzureAD
}

#Connect to Azure and AzureAD
#OKTA Web prompt
Connect-AzAccount 
Connect-AzureAD 

<#
##Connect with RunAs for AZ Automation
$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection"
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Connect-AzAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}
#>

##Set naming scheme to name resources. (Examples: 2021,Test,Staff)
#$NamingScheme = (Set-NamingScheme -NamingScheme TEST)
function Set-NamingScheme {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$True,HelpMessage="Naming Scheme will be used to name and organize resources.")]
        [ValidateLength(2,7)][string] $NamingScheme
    ) 
    Write-Output "You selected '$NamingScheme'"
    return $NamingScheme
}

#region Azure Functions
function Set-SubscriptionID {
   <#
   .SYNOPSIS
    Selects and Returns Azure Subscription ID. 
   
   .DESCRIPTION
    Take in mandatory parameter Environment will select NonProd or Prod subscription.
   
   .EXAMPLE
    $SubscriptionID = Set-SubscriptionID -Environment <nonprod/prod>
   #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ([Parameter(Mandatory=$true,HelpMessage="Select Prod or NonProd Subscription")]
    [ValidateSet("prod","nonprod")][string]$Environment)
    if ($Environment -like "nonprod"){
        #Write-Output "Selecting NonProd Subscription"
        $NonProd = (Get-AzSubscription -SubscriptionName "NonProd-VDI")
        Select-AzSubscription -Subscription $NonProd | out-null
        $SubscriptionID = $NonProd.Id
    }
    if ($Environment -like "prod"){
        #Write-Output "Selecting Prod Subscription"
        $Prod = (Get-AzSubscription -SubscriptionName "Prod-VDI")
        Select-AzSubscription -Subscription $Prod | out-null
        $SubscriptionID = $Prod.Id
    }
    return $SubscriptionID    
}

function New-ResourceGroup {
    <#
   .SYNOPSIS
    Create New Azure Resource Group.
   
   .DESCRIPTION
    Take in mandatory parameter ResourceGroupName will create new RG with that param.
    Will Error is Location is missing. 
    Returns Resource Group
   
   .EXAMPLE
    $RG = (New-ResourceGroup -ResourceGroupName <RecourceGroup_Name>)
   #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ([Parameter(Mandatory=$True)][string]$ResourceGroupName)
    $ResourceGroupName = "rg-avd-prod-pool-$NamingScheme-$LocationName"
    if (!($LocationName)){Write-Error "Missing Location Name"; break}
    $RG = (Get-AzResourceGroup $ResourceGroupName -ErrorVariable NotPresent -ErrorAction SilentlyContinue)
    if(!($RG)) {
            Write-Output "Resource Group not found, creating '$($ResourceGroupName)'."
            $RG = (New-AzResourceGroup -Name $ResourceGroupName -Location $LocationName)
    }
    else {Write-Error "Error: Resource Group already exists."}
    return $RG
}

function Set-ResourceGroup {
    <#
   .SYNOPSIS
    Selects and Returns (existing) Azure Resource Group.
   
   .DESCRIPTION
    Take in mandatory parameter ResourceGroupName will select RG from that param.
    Validate Resource Group or provides error. 
    Returns Resource Group
   
   .EXAMPLE
    $RG = (Set-ResourceGroup -ResourceGroupName <$ResourceGroupName>)
   #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ([Parameter(Mandatory=$True)][string]$ResourceGroupName)
    if (!($LocationName)){Write-Error "Missing Location Name"; break}
    $RG = (Get-AzResourceGroup $ResourceGroupName -ErrorVariable NotPresent -ErrorAction SilentlyContinue)
    if(!($RG)) {Write-Error "Resource Group not found.";break}
    return $RG
}

function Remove-ResourceGroup {
    <#
   .SYNOPSIS
    Delete Azure Resource Group.
   
   .DESCRIPTION
    Take in mandatory parameter ResourceGroupName will delete RG from that param.
   
   .EXAMPLE
    Remove-ResourceGroup -ResourceGroupName <$ResourceGroupName>
   #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ([Parameter(Mandatory=$True)][string]$ResourceGroupName)
    if (!($LocationName)){Write-Error "Missing Location Name"; break}
    Write-Output "Deleting ResourceGroup $ResourceGroupName"
    Remove-AzResourceGroup -Name $ResourceGroupName -Confirm:$false -Force
}

function New-AZAdminGroup{
    <#
   .SYNOPSIS
    Create New Azure ActiveDirectory Group.
   
   .DESCRIPTION
    Take in mandatory parameter AZAdminGroup will create new AZ AD Group from that param.
    Also, takes in parameter Owner UPN, and Adds UPN as Owner to new Group.
    Returns AZ AD Group
   
   .EXAMPLE
    $AZAdminGroup = (New-AzAdminGroup -AZAdminGroup <AZ_AD_GroupName> -OwnerUPN user.name@domain.com)
   #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True)][string] $AZAdminGroup
        #[Parameter(Mandatory=$True)][string] $OwnerUPN
    )
    $Group = (Get-AzADGroup -DisplayName $AZAdminGroup)
    if (@($Group)){Write-Error "Azure AD Group already exists."; break}
    if (!$Group){
        $AZGroup = (New-AzADGroup -DisplayName $AZAdminGroup -MailNickname $AZAdminGroup)
        <#Add Group Owner is broken, unable to Connect-AzureAD.
        $AZOwner = (Get-AzADUser -UserPrincipalName $OwnerUPN)
        Write-Output "Adding Owner '$($OwnerUPN)' to group '$($AZAdminGroup)'..."
        Add-AzureADGroupOwner -ObjectId $($AZGroup.ID) -RefObjectId $($AZOwner.ID
        #>
        return $AZGroup    
    }
}

function Set-AzAdminGroup {
    <#
   .SYNOPSIS
    Select and Return Azure ActiveDirectory Group.

   .DESCRIPTION
    Take in mandatory parameter AZAdminGroup, and will select AZ AD Group from that param.
    Validates Group, or provides error. 
    Returns AZ AD Group
   
   .EXAMPLE
    $AZAdminGroup = (Set-AzAdminGroup -AZAdminGroup <AZ_AD_Group_Name>)
   #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$True)][string] $AZAdminGroup
    )
    $AZGroup = (Get-AZADGroup -DisplayName $AZAdminGroup)
    if (!($AZGroup)){Write-Error "AZ AD Group not found, use function New-AZAdminGroup"; break } 
    else {Write-Output "You selected '$AZAdminGroup'"}
    return $AZGroup
}

function Remove-AzAdminGroup {
    <#
   .SYNOPSIS
    Remove Azure ActiveDirectory Group.

   .DESCRIPTION
    Take in mandatory parameter AZAdminGroup, and will select AZ AD Group from that param.
    Validates Group, or provides error. 
    Returns AZ AD Group
   
   .EXAMPLE
    Remove-AzAdminGroup -AZAdminGroup <AZ_AD_Group_Name>
   #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$True)][string] $AZAdminGroup
    )
    $AZGroup = (Get-AZADGroup -DisplayName $AZAdminGroup)
    if(!($AZGroup)){Write-Error "No AZ AD Group found.";break}
    if($AZGroup.count -gt 1){Write-Error "Too many results";break}
    Remove-AzADGroup -ObjectId $AZGroup.Id -Confirm:$false -Force
}

function Set-AccessRole {
    <#
   .SYNOPSIS
    Assign Role to Resource Group.

   .DESCRIPTION
    Take in mandatory parameters ResourceGroupName and AZGroupID. Validates RG and GroupID, or throw error. 
    Take in parameter RoleName, and select azure role based on param. Three options are approved (Contributor,Owner,Reader).
    Assign the ResourceGroup the provided Role to the AZGroup
    Returns Assignment for confirmation.
   
   .EXAMPLE
    Set-AccessRole -ResourceGroupName $ResourceGroupName -AZAdminGroupID $AZGroup.Id -Role Owner  
   #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True)][string]$ResourceGroupName,
        [Parameter(Mandatory=$True)][string]$AZGroupID,
        [Parameter(Mandatory=$True)][ValidateSet("Contributor","Reader","Owner")][string]$RoleName
    )
    $Role = (Get-AzRoleDefinition $RoleName)
    $RG = (Get-AzResourceGroup -Name $ResourceGroupName -ErrorVariable NotPresent -ErrorAction SilentlyContinue)
    $AZGroup = (Get-AzADGroup -ObjectId $AZGroupID -ErrorVariable NotPresent -ErrorAction SilentlyContinue)
    if(!($RG)){Write-Error "Resource Group not found."; break}
    if(!($AZGroup)){Write-Error "AZ AD Group not found."; break}
    else {
        New-AzRoleAssignment -ResourceGroupName $ResourceGroupName -ObjectId $AZGroupID -RoleDefinitionName $Role.Name    
        $assignment = (Get-AzRoleAssignment -ObjectId $AZGroupID -ResourceGroupName $ResourceGroupName)
        return $assignment
    }
}
#endRegion

#region Active Directory Functions
function New-OU {
    <#
   .SYNOPSIS
    Create new Active Directory Organizational Unit (OU).

   .DESCRIPTION
    Take in mandatory parameter NewOU, and creates new OU named by the param.  
    Takes in mandatory parameter Environment to determine if NewOU will be under NonProd or Prod.
    Takes in mandatory parameter OU_Type to determine is NewOU will be for Personal or Pooled HostPool.
    Returns AD OU.
   
   .EXAMPLE
    $OU = (New-OU -NewOU "OU-Name" -Environment Non/Prod -OU_type Personal/Pooled)
   #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True,HelpMessage="New AD OU Name")][string] $NewOU,
        [Parameter(Mandatory=$True,HelpMessage="Environment (prod/nonprod)")][ValidateSet("NonProd","Prod")][string] $Environment,
        [Parameter(Mandatory=$True,HelpMessage="OU Type Pooled/Personal")][ValidateSet("Personal","Pooled")][string] $OU_type
    )
    #Root OU
    $Root = "OU=AVD,OU=Workstations,DC=domain,DC=net"
    #Path to create New OU
    $OUpath = "OU=$OU_Type,OU=$Environment,$Root"
    #NewOU Full Path
    $OU = "OU=$NewOU,$OUpath"
    try {
        Get-ADOrganizationalUnit $OU -ErrorAction SilentlyContinue | out-null
        Write-Error "OU already exists."
    }
    catch {
        Write-Output "'$($NewOU)' does not exists, creating OU..." 
        New-ADOrganizationalUnit -Name $NewOU -Path $OUPath
        Start-Sleep -Seconds 1
    }
    return (Get-ADOrganizationalUnit -Identity $OU)
}

function Set-OU {
    <#
   .SYNOPSIS
    Select and Return (existing) Active Directory Organizational Unit (OU).

   .DESCRIPTION
    Take in optional parameter OU distinguishedName, and select OU based on the param.  
    IF No OU DN is provided, OU will be selected from two optional parameters Environment & OU_Type.
    Throw error if no OU is found. 
    Returns AD OU.
   
   .EXAMPLE
    $OU = (Set-OU -OU "OU=AVD,OU=Workstations,DC=domain,DC=net")
    $OU = (Set-OU -OUName "OU_Name" -Environment NonProd -OU_type Personal)
   #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [Parameter(Mandatory=$False,HelpMessage="Enter OU distinguishedName")][string] $OU,
        [Parameter(Mandatory=$False,HelpMessage="Enter OU Name")][string] $OUName,
        [Parameter(Mandatory=$False,HelpMessage="Environment (prod/nonprod)")][ValidateSet("NonProd","Prod")][string] $Environment,
        [Parameter(Mandatory=$False,HelpMessage="OU Type Pooled/Personal")][ValidateSet("Personal","Pooled")][string] $OU_type
    )
    $Root = "OU=AVD,OU=Workstations,DC=domain,DC=net"
    if(!($OU)) {
        if(!($OU_type)){Write-Error "Missing OU_Type, please define Pooled or Personal."; break}
        if(!($Environment)){Write-Error "Missing Environment, please define Prod or NonProd."; break}
        if(!($OUName)){Write-Error "Missing OU's Name, please define the OU's Name."; break}
        try {
            $OrgUnit = (Get-ADOrganizationalUnit -Identity "OU=$OU_Type,OU=$Environment,$Root" -ErrorAction SilentlyContinue)
            Write-Output "No OU defined in parameter, auto-selected '$OrgUnit'."
        }
        catch{Write-Error "No OU found. Please check parameters, and verify OU exists."; break}
        #if(!($OrgUnit)){Write-Error "No OU found. Please check parameters, and verify OU exists."; break}
    }
    else{
        try {$OrgUnit = (Get-ADOrganizationalUnit -Identity $OU -ErrorAction SilentlyContinue)}
        catch{Write-Error "No OU found.";break}
    }
    return $OrgUnit
}

function Remove-OU {
    <#
   .SYNOPSIS
    Delete Active Directory Organizational Unit (OU)and ALL child items!

   .DESCRIPTION
    Take in mandatory parameter OU distinguishedName, and delete OU based on the param.  
   
   .EXAMPLE
    Remove-OU -OU "OU=test,OU=Workstations,DC=domain,DC=net"
   #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [Parameter(Mandatory=$False,HelpMessage="Enter OU distinguishedName")][string] $OU
    )
    try{
        $OrgUnit = (Get-ADOrganizationalUnit -Identity $OU -ErrorAction SilentlyContinue)
    }
    catch{Write-Error "No OU found.";break}
    #if(!($OrgUnit)){}
    $OrgUnit | Set-ADObject -ProtectedFromAccidentalDeletion:$false -PassThru 
    $OrgUnit | Remove-ADOrganizationalUnit -Recursive -Confirm:$false | Out-Null
    #Remove-ADOrganizationalUnit -Identity $OU -Confirm:$false
    #}
}

function Set-ComputerName {
    <#
   .SYNOPSIS
    Set ActiveDirectory Computer Object Name

   .DESCRIPTION
    ComputerName can not be shorter than 4 chars and longer than 15. 
    Once ComputerName has been set, it can be passed to other functions as a variable. 
   
   .EXAMPLE
    $ComputerName = (Set-ComputerName -ComputerName <ComputerName>)
   #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ([Parameter(Mandatory=$True)][ValidateLength(4,15)][string]$ComputerName)
    #if (!($ComputerName)) {$ComputerName = Read-Host "Enter Computer Name"}
    return $ComputerName
}

function New-Computer {
    <#
   .SYNOPSIS
    Set ActiveDirectory Computer Object Name and Validate it is within 15 chars.

   .DESCRIPTION
    Create New AD Computer Object based on mandatory parameters ComputerName and OU. 
    Will prompt for user confirmation if Computer Object already exists.
   
   .EXAMPLE
    $ComputerName = (New-Computer -ComputerName $ComputerName -OU $OU.DistinguishedName)
   #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [Parameter(Mandatory=$True)][ValidateLength(4,15)][string] $ComputerName,
        [Parameter(Mandatory=$True)][string] $OU,
        [Parameter(Mandatory=$false)][string] $AD_Creds = $(Get-Credential)
    )
    #verify ou exists
    try {$OrgUnit = (Get-ADOrganizationalUnit -Identity $OU -ErrorAction SilentlyContinue)}
    catch{Write-Error "No OU found.";break}
    #verify the computer object does not exist
    try {
        $ComputerObj = (Get-ADComputer $ComputerName -ErrorAction SilentlyContinue)
        Write-Output `n"Warning!!!`nComputer Object '$($ComputerName)' already exists."
        Write-Output "If you proceed, it will break the existing computer's domain trust."`n
        #prompt for user confirmation
        $userinput = $(Write-Host "Do you want to override this Computer Name? (y)es/(n)o: " -NoNewline; Read-Host)
        switch ($userinput){
            y {Write-Output "'$($ComputerName)' is set."; break} 
            n {
                Write-Output "Please select a new computer name."
                [ValidateLength(4,15)][string] $ComputerName = $(Write-Output "Enter the new Computer Name: " -ForegroundColor Green -NoNewline; Read-Host) 
                Write-Output "New Computer Name is '$($ComputerName)'" ; break
                New-ADComputer -Name $ComputerName -SamAccountName $ComputerName -Path $OU
            }
        }#End Switch
    } 
    catch {
        Write-Output "Computer Object not found in the domain, creating '$($ComputerName)' in OU '$($OU)'"
        New-ADComputer -Name $ComputerName -SamAccountName $ComputerName -Path $OU
    }
    return $ComputerName
}

function New-MultipleComputers {
    <#
   .SYNOPSIS
    Creates Multiple Computer Objects in the desired OU

   .DESCRIPTION
    Create New AD Computer Object based on mandatory parameters Number of ComputerObjects, ComputerNamePrefix, and OU. 
   
   .EXAMPLE
    New-MultipleComputers -ComputerPrefix "AVD-TEST" -NumberOfComputers '15'
   #>
    [CmdletBinding(SupportsShouldProcess=$true)]
        Param(
            [Parameter(Mandatory=$True)][ValidateLength(4,12)][string] $ComputerPrefix,
            [Parameter(Mandatory=$True)][int]$NumberOfComputers,
            [Parameter(Mandatory=$True)][string] $OU
    )
    try {$OrgUnit = (Get-ADOrganizationalUnit -Identity $OU -ErrorAction SilentlyContinue)}
    catch{Write-Error "No OU found.";break}
    #Start Array at 01.    
    $ComputerArray = (1..$NumberOfComputers)
    foreach ($item in $ComputerArray){
        if($item -lt 10){$ComputerName="$ComputerPrefix-0$item"}#Format Name to include "0"
        else {$ComputerName="$ComputerPrefix-$item"}
        try {
            $ComputerObj = (Get-ADComputer $ComputerName -ErrorAction SilentlyContinue)
            Write-Output "Warning!!!`nComputer Object '$($ComputerName)' already exists!"
        }
        catch{
            Write-Output "Create AD Computer '$ComputerName'"
            New-Computer -ComputerName $ComputerName -OU $OU | Out-Null    
        }
    }
}

#New Blank GPO
#$GPO = New-FSlogixGPO -NamingScheme $NamingScheme -GPOtype $MultiSession
function New-FSlogixGPO {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True)][string] $NamingScheme,
        [Parameter(Mandatory=$True)][ValidateSet("SingleSession","MultiSession")][string] $GPOtype
    )
    $GPOName = "NonProd_C_fslogix_$($GPOtype)_$($NamingScheme)-$(Get-Date -f yy.MM)a"
    if (@(Get-GPO $GPOName -ErrorAction SilentlyContinue).Count) {
        Write-Error "GPO '$($GPOName)' already exists!"} 
    else {
        Write-Output "Creating GPO '$($GPOName)'"
        $GPO = New-GPO -Name $GPOName 
        Write-Host -ForegroundColor DarkYellow "Waiting for AD replication...";Start-Sleep -Seconds 10
    }
    return $GPO
}

#Set GPO Delegated Permissions
#Set-Fslogix-DelegatedAdmins -GPO $GPO
function Set-GPOpermissions{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ([Parameter(Mandatory=$True)][string] $GPO)
    Write-Output "Set GPO Permissions"
    Set-GPPermission -Name $GPO -Replace -PermissionLevel GpoEditDeleteModifySecurity -TargetName "GroupPolicyManagement-GPOs-FullControl" -TargetType Group  | Out-Null       
}

#Set FSlogix Profile Contriner Config
#Set-FslogixGPOconfig -GPO $GPO -FolderPath "\\AZ_Storeage_Location.file.core.windows.net\fslogix-profiles" -UserProfileShare "RAGEN" -RoamSearch 2
#https://docs.microsoft.com/en-us/fslogix/configure-search-roaming-ht#configure-multi-user-search
#https://docs.microsoft.com/en-us/fslogix/
#Set-FslogixGPOconfig -GPO "NonProd_C_fslogix_MultiSession_RAGEN-22.03a" -UserProfileShare "Profiles\RAGEN-TEST" -FolderPath "\\AZ_Storeage_Location.file.core.windows.net\fslogix-profiles" -RoamSearch 2
function Set-FslogixGPOconfig {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True)][string]$GPO, $UserProfileShare, $FolderPath,
        [Parameter(Mandatory=$True,HelpMessage="0 for disabled, 1 for singleSession, 2 for multi session")][ValidateSet(0,1,2)][int]$RoamSearch
    )
    Write-Output "Configure FSLogix GPO '$($GPO)'"
    Write-Output "Configure FSLogix Profile Container"
    Set-GPRegistryValue -Name $GPO -Key "HKLM\Software\FSLogix\Profiles" -ValueName "Enabled" -Type DWord -Value 1 | Out-Null
    Set-GPRegistryValue -Name $GPO -Key "HKLM\Software\FSLogix\Profiles" -ValueName "FlipFlopProfileDirectoryName" -Type DWord -Value 1 | Out-Null
    Set-GPRegistryValue -Name $GPO -Key "HKLM\Software\FSLogix\Profiles" -ValueName "OutlookCachedMode" -Type DWord -Value 1 | Out-Null
    Write-Output "Configure FSLogix Office Container"
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
    Write-Output "Configure FSLogix Volume Type (VHDX)"
    Set-GPRegistryValue -Name $GPO -Type String -Key "HKLM\Software\FSLogix\Profiles" -ValueName "VolumeType" -Value "VHDX" | Out-Null     
    Set-GPRegistryValue -Name $GPO -Type String -Key "HKLM\Software\Policies\FSLogix\ODFC" -ValueName "VolumeType" -Value "VHDX" | Out-Null
    Write-Output "Configure FSLogix Search Roaming to '$($RoamSearch)'"
    Set-GPRegistryValue -Name $GPO -Key "HKLM\Software\FSLogix\Profiles" -ValueName "RoamSearch" -Type DWord -Value $RoamSearch | Out-Null
    Set-GPRegistryValue -Name $GPO -Key "HKLM\Software\FSLogix\Apps" -ValueName "RoamSearch" -Type DWord -Value $RoamSearch | Out-Null
    Write-Output "Configure FSlogix file path for Redirection.xml and Containers"
    Set-GPRegistryValue -Name $GPO -Type String -Key "HKLM\Software\FSLogix\Profiles"-ValueName "RedirXMLSourceFolder" -Value $("$($FolderPath)\Redirections") | Out-Null
    Set-GPRegistryValue -Name $GPO -Type String -Key "HKLM\Software\FSLogix\Profiles"-ValueName "VHDLocations" -Value "$($FolderPath)\$($UserProfileShare)" | Out-Null
    Set-GPRegistryValue -Name $GPO -Type String -Key "HKLM\Software\Policies\FSLogix\ODFC" -ValueName "VHDLocations"  -Value "$($FolderPath)\$($UserProfileShare)" | Out-Null

}
#DeleteLocalProfileWhenVHDShouldApply, 1, This setting avoids errors while logging in with an existing local profile. It removes the profile first, if any already exists.

#Combine above functions into a single function
#New-FSLogixGPOConfigured -NamingScheme $NamingScheme -UserProfileShare $FolderName -FolderPath "\\AZ_Storeage_Location.file.core.windows.net\fslogix-profiles" -GPOtype MultiSession -RoamSearch 2
function New-FSLogixGPOConfigured {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True)][string]$NamingScheme, $UserProfileShare, $FolderPath,
        [Parameter(Mandatory=$True)][ValidateSet("SingleSession","MultiSession")][string] $GPOtype,
        [Parameter(Mandatory=$True,HelpMessage="0 for disabled, 1 for singleSession, 2 for multi session")][ValidateSet(0,1,2)][int]$RoamSearch
    )
    $GPO = New-FSlogixGPO -NamingScheme $NamingScheme -GPOtype $GPOtype
    
    Set-GPOpermissions -GPO $GPO.DisplayName
    
    Write-Output "Disable GPO User Settings"
    (Get-GPO $($GPO.DisplayName)).GpoStatus = "UserSettingsDisabled"
    
    #Default Log Dir %ProgramData%\FSLogix\Logs
    #https://docs.microsoft.com/en-us/fslogix/logging-diagnostics-reference#logging-settings-and-configuration
    # Set-GPRegistryValue -Name $GPO.DisplayName -Key "HKLM\Software\FSLogix\Logging" -ValueName "LoggingEnabled" -Type DWord -Value 0 | Out-Null
    # Set-GPRegistryValue -Name $GPO.DisplayName -Key "HKLM\Software\FSLogix\Logging" -ValueName "LoggingLevel" -Type DWord -Value 3 | Out-Null
    
    Set-FSlogixGPOConfig -GPO $GPO.DisplayName -FolderPath $FolderPath -UserProfileShare $UserProfileShare -RoamSearch $RoamSearch
    Write-Out "GPO was created, please review."
}

##Set GPO Link for above GPO and OU
#Set-GPLink -NewGPO $NewGPO.DisplayName -OU $OU
function Set-GPLink {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ([Parameter(Mandatory=$True)][string] $GPO,$OU)
    $GPLinks = (Get-GPInheritance -Target $OU)
    if (($link)){Write-Error "'$($GPO)' is already linked to '$($OU)'"}
    else {
        Write-Output "Link GPO '$GPO' to OU '$($OU)'"
        New-GPLink -Name $GPO -Target $OU -LinkEnabled Yes | Out-Null
    }
}
 $link = $GPLinks.GpoLinks | Where {$_.DisplayName -like $GPO}

#EndRegion

#region AVD Functions

function New-Workspace{
    <#
   .SYNOPSIS
    Creates AVD Workspace based on parameters for WorkspaceName & WorkspaceResourceGroup.
   
   .DESCRIPTION
    Take in mandatory parameter WorkspaceName and create new WorkSpace.
    Returns WorkSpace
   
   .EXAMPLE
    $Workspace = (New-Workspace -WorkspaceName "Test-Workspace" -WS_ResourceGroup <WorkSpaceResourceGroupName>)
    $Workspace = (New-Workspace -WorkspaceName "Test-Workspace" -WS_ResourceGroup $RG.ResourceGroupName)
   #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True)][string] $WorkspaceName,
        [Parameter(Mandatory=$True)][string] $WS_ResourceGroup,
        [Parameter(Mandatory=$False)][string] $WS_Description
    )
    if(!($SubscriptionID)){Write-Error "Missing AZ Subscription ID"; break}
    $WSRG = (Get-AzResourceGroup $WS_ResourceGroup -ErrorVariable NotPresent -ErrorAction SilentlyContinue)
    if(!($WSRG)) {Write-Error "WorkSpace Resource Group not found.";break}
    $Workspace = (Get-AzWVDWorkspace -Name $WorkspaceName -ResourceGroupName $WS_ResourceGroup -ErrorVariable NotPresent -ErrorAction SilentlyContinue)
    if (!($Workspace)){
        Write-Output "Workspace '$($WorkspaceName)' does not exist in ResourceGroup '$($WS_ResourceGroup)'."
        Write-Output "Creating Workspace..."
        New-AzWVDWorkspace  -ResourceGroupName $WS_ResourceGroup `
                            -Name $WorkspaceName `
                            -Location $WSRG.Location `
                            -FriendlyName $WorkspaceName `
                            -ApplicationGroupReference $null `
                            -Description $WS_Description `
                            -SubscriptionId "$SubscriptionID" `
                            | Out-Null
    }
    else {Write-Error "Workspace '$($WorkspaceName)' already exists"}
    $WS = (Get-AzWVDWorkspace -Name $WorkspaceName -ResourceGroupName $WS_ResourceGroup)
    return $WS
}

#Example. $Workspace = (Set-Workspace -WorkspaceName -ResourceGroupName $RG.ResourceGroupName)
function Set-Workspace {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([parameter(Mandatory=$True)][string]$WorkspaceName, $ResourceGroupName)
    $WS = (Get-AzWVDWorkspace -Name $WorkspaceName -ResourceGroupName $ResourceGroupName)
    return $ws
}

function Remove-Workspace {
    <#
   .SYNOPSIS
    Delete AVD Workspace.
   
   .DESCRIPTION
    Take in mandatory parameter WorkspaceName and delete WorkSpace.
   
   .EXAMPLE
    Remove-Workspace -WorkspaceName "Test-Workspace" -WS_ResourceGroup <WorkSpaceResourceGroupName>
   #>
   [CmdletBinding(SupportsShouldProcess=$true)]
   param (
       [Parameter(Mandatory=$True)][string] $WorkspaceName,
       [Parameter(Mandatory=$True)][string] $WS_ResourceGroup
   )
    $Workspace = (Get-AzWVDWorkspace -Name $WorkspaceName -ResourceGroupName $WS_ResourceGroup -ErrorVariable NotPresent -ErrorAction SilentlyContinue)
    if(!($Workspace)){Write-Error "Missing Workspace.";break}
    else{Remove-AzWvdWorkspace -Name $WorkspaceName -ResourceGroupName $WS_ResourceGroup -Confirm:$false}
}

# New-AzWvdHostPool -Name "pool-nonprod-pooled-FSLogix-RAGEN" `
#                     -ResourceGroupName "rg-avd-nonprod-pool-ragen-westus2" `
#                     -HostPoolType 'Pooled' `
#                     -LoadBalancerType 'BreadthFirst' `
#                     -PreferredAppGroupType 'RailApplications' `
#                     -Location westus2 `
#                     -MaxSessionLimit 10 `
#                     -StartVMOnConnect 
function New-HostPool {
    <#
   .SYNOPSIS
    Create new host pool.
     
   .DESCRIPTION
    Takes in parameter HostPoolName, looks for existing HostPool with that Name, if none found created HostPool
    Takes in ResourceGroupName, SessionLimit, HostPoolType, and AppGroupType to configure HostPool
   
   .EXAMPLE
    $HostPool = (New-HostPool -HostPoolName "AVD-TEST" -ResourceGroupName $RG.ResourceGroupName -SessionLimit 4 -HostPoolType Pooled)
   #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True)][string] $HostPoolName,
        [Parameter(Mandatory=$True)][string] $ResourceGroupName,
        [Parameter(Mandatory=$True)][int]$SessionLimit,
        [Parameter(Mandatory=$True)][ValidateSet("Pooled","Personal")][string]$HostPoolType,
        [Parameter(Mandatory=$False)][ValidateSet("Desktop","RemoteApp")][string]$AppGroupType
    )
    $RG = (Get-AzResourceGroup $ResourceGroupName -ErrorVariable NotPresent -ErrorAction SilentlyContinue)
    if(!($RG)) {Write-Error "Resource Group not found.";break}
    $HostPool = (Get-AzWVDHostPool -Name $HostPoolName -ResourceGroupName $ResourceGroupName -ErrorVariable NotPresent -ErrorAction SilentlyContinue)
    if (!($HostPool)){
        Write-Output "Host Pool '$($HostPoolName)' does not exist..."
        Write-Output "Creating Host Pool '$($HostPoolName)' in Resource Group '$($ResourceGroupName)'"
        Write-Output "$AppGroupType"
        New-AzWVDHostPool   -Name $HostPoolName `
                            -ResourceGroupName $ResourceGroupName `
                            -Location $LocationName `
                            -HostPoolType $HostPoolType `
                            -PreferredAppGroupType $AppGroupType `
                            -LoadBalancerType BreadthFirst `
                            -MaxSessionLimit $SessionLimit `
                            | out-null 
    } 
    else {Write-Error "Host Pool '$($HostPoolName)' already exists"; break}
    $HP = (Get-AzWVDHostPool -Name $HostPoolName -ResourceGroupName $ResourceGroupName)
    return $HP
}

function Set-HostPool {
    [CmdletBinding()]
    param (
        [Parameter()][string]$HostPoolName, $ResourceGroupName
    )
    $HP = (Get-AzWVDHostPool -ResourceGroupName $ResourceGroupName -Name $HostPoolName)
    return $HP
}

function Update-HostPool {
    <#
   .SYNOPSIS
    Update host pool.
     
   .DESCRIPTION
    Takes in parameter HostPoolName, select HostPool with that Name
    Takes in ResourceGroupName
   
   .EXAMPLE

   #>
   [CmdletBinding(SupportsShouldProcess=$true)]
   param (
       [Parameter(Mandatory=$True)][string] $HostPoolName,
       [Parameter(Mandatory=$True)][string] $ResourceGroupName,
       [Parameter(Mandatory=$False)][int]$SessionLimit
   )
    #Use this function to update FriendlyName, ResourceGroup, SessionLimit, Descrition, MaxSessions, VM Template.
    $HostPool = (Get-AzWVDHostPool -Name $HostPoolName -ResourceGroupName $ResourceGroupName -ErrorVariable NotPresent -ErrorAction SilentlyContinue)
    if(!($HostPool)){Write-Error "Missing HoptPool";break}
    else{Update-AzWVDHostPool -Name $HostPoolName -ResourceGroupName $ResourceGroupName -SessionLimit $SessionLimit}
}

function Remove-HostPool {
    <#
   .SYNOPSIS
    Delete host pool.
     
   .DESCRIPTION
    Takes in parameter HostPoolName, deleted HostPool
   
   .EXAMPLE
    Remove-HostPool -HostPoolName "AVD-TEST" -ResourceGroupName $ResourceGroupName
   #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True)][string] $HostPoolName,
        [Parameter(Mandatory=$True)][string] $ResourceGroupName
    )
    $RG = (Get-AzResourceGroup $ResourceGroupName -ErrorVariable NotPresent -ErrorAction SilentlyContinue)
    if(!($RG)) {Write-Error "Resource Group not found.";break}
    $HostPool = (Get-AzWVDHostPool -Name $HostPoolName -ResourceGroupName $ResourceGroupName -ErrorVariable NotPresent -ErrorAction SilentlyContinue)
    if (!($HostPool)){Write-Error "Host Pool '$($HostPoolName)'not found."; break}
    Remove-AzWvdHostPool -ResourceGroupName $ResourceGroupName -Name $HostPoolName -Confirm:$false
}

function Set-RegKey {
    <#
    .SYNOPSIS
    Create new host pool.
        
    .DESCRIPTION
    Takes in mandatory parameter HostPoolName, looks for existing HostPool with that Name, updates HostPool
    Takes in optional parameter Expiration as number of days before the token expires. 
    Returns HostPool Token 

    .EXAMPLE
    $Token = (Set-RegKey -HostPoolName $HostPool.Name -ResourceGroupName $RG.ResourceGroupName)    
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True)][string] $HostPoolName,
        [Parameter(Mandatory=$True)][string] $ResourceGroupName,
        [Parameter(Mandatory=$False,HelpMessage="Number of Days before Registration Token Expires")]
        [ValidateRange("1","27")][int]$Expiration ='2'
    )
    if(!($SubscriptionID)){Write-Error "Missing Subscription ID.";break}
    $RG = (Get-AzResourceGroup $ResourceGroupName -ErrorVariable NotPresent -ErrorAction SilentlyContinue)
    if(!($RG)) {Write-Error "Resource Group not found.";break}
    $HostPool = (Get-AzWVDHostPool -Name $HostPoolName -ResourceGroupName $ResourceGroupName -ErrorVariable NotPresent -ErrorAction SilentlyContinue)
    if (!($HostPool)){Write-Error "No Host Pool found.";break}
    $GetToken = (New-AzWvdRegistrationInfo -SubscriptionId $SubscriptionID `
                                           -ResourceGroupName $ResourceGroupName `
                                           -HostPoolName $HostPoolName `
                                           -ExpirationTime (Get-Date).AddDays($Expiration) `
                                           -ErrorAction SilentlyContinue)
    return $GetToken
}

##Create Desktop Application Group
function New-ApplicationGroup {
    <#
    .SYNOPSIS
    Create new Application Group. 
        
    .DESCRIPTION
    Takes in mandatory parameter ResourceGroupName and HostPoolName
    Takes in optional parameter for the Application Group Name. 
    Takes in optional parameter for the type of resource for the application group.
    Returns Application Group 

    .EXAMPLE
    $AppGroup = (New-ApplicationGroup -ResourceGroupName $RG.ResourceGroupName -HostPoolName $HostPool.Name)
    $AppGroup = (New-ApplicationGroup -ResourceGroupName $RG.ResourceGroupName -HostPoolName $HostPool.Name -AppGroupName "AVD-TEST-DAG")
    #>

    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True)][string] $ResourceGroupName,
        [Parameter(Mandatory=$True)][string] $HostPoolName,
        [Parameter(Mandatory=$True)][string]$AppGroupName,
        [Parameter(Mandatory=$False)][ValidateSet("Desktop","RailApplications")][string]$AppGroupType = "Desktop"
    )
    $RG = (Get-AzResourceGroup $ResourceGroupName)
    $HostPool = (Get-AzWvdHostPool -Name $HostPoolName -ResourceGroupName $ResourceGroupName)
    $AG = (Get-AzWvdApplicationGroup -Name $AppGroupName -ResourceGroupName $ResourceGroupName)
    if (!($RG)) {Write-Error "Missing Resource Group"; break}
    if (!($HostPool)){Write-Error "Missing Host Pool"; break}
    if ($($AG)){Write-Error "Application Group '$($AppGroupName)' already exists"; break}
    else {
        Write-Output "Resource Group: '$($ResourceGroupName)'"
        Write-Output "Host Pool: '$($HostPoolName)'"
        Write-Output "Creating Application Group '$($AppGroupName)'."
        New-AzWvdApplicationGroup   -Name $AppGroupName `
                                    -ResourceGroupName $ResourceGroupName `
                                    -ApplicationGroupType $AppGroupType `
                                    -HostPoolArmPath $HostPool.id `
                                    -Location $LocationName `
                                    | Out-Null
    }
    $AppGroup = (Get-AzWvdApplicationGroup -Name $AppGroupName -ResourceGroupName $RG.ResourceGroupName)
    return $AppGroup
}	

function Set-ApplicationGroup {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True)][string] $ResourceGroupName,
        [Parameter(Mandatory=$True)][string]$AppGroupName
    )
    $RG = (Get-AzResourceGroup $ResourceGroupName)
    if (!($RG)) {Write-Error "Missing Resource Group"; break}
    $AppGroup = (Get-AzWvdApplicationGroup -Name $AppGroupName -ResourceGroupName $ResourceGroupName)
    return $AppGroup
}

##Register AG with Workspace
#Set-AppGroupWorkspace -AppGroupName $AppGroup.Name -WorkspaceName $Workspace.Name -ResourceGroupName $RG.ResourceGroupName 
function Set-AppGroupWorkspace {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True)][string] $AppGroupName,$WorkspaceName,$ResourceGroupName,
        [Parameter(Mandatory=$False)][string] $WS_ResourceGroupName = $ResourceGroupName
    )
    $AG = (Get-AzWvdApplicationGroup -Name $AppGroupName -ResourceGroupName $ResourceGroupName)
    $WS = (Get-AzWvdWorkspace -Name $WorkspaceName -ResourceGroupName $WS_ResourceGroupName)
    $AZSubID = $SubscriptionID
    if (!($AG)){Write-Error "Missing Application Group"; break}
    if (!($WS)){Write-Error "Missing Workspace"; break}
    $Verify = "/subscriptions/$($AZSubID)/resourcegroups/$($ResourceGroupName)/providers/Microsoft.DesktopVirtualization/applicationgroups/$AppGroupName"
    if ($WS.ApplicationGroupReference -contains $Verify ){Write-Error "Application Group already registered"; break}
    else {
            Write-Output "Workspace Name: '$($WorkspaceName)'"
            Write-Output "Workspace Resource Group: '$($WS_ResourceGroupName)'"
            Write-Output "Application Group: '$($AppGroupName)'"
            Write-Output "Registering Application Group '$($AppGroupName)' to Workspace '$($WorkspaceName)'"
            #Workspace Resource Group, not ApplicationGroup RG
            Register-AzWvdApplicationGroup  -ResourceGroupName $WS_ResourceGroupName `
                                            -WorkspaceName $WS.name `
                                            -ApplicationGroupPath $AG.id
    }
}

#EndRegion AVD Functions

#region Deploy Azure VM

##Get/Set Azure compute gallery image to create new VM 
##If no gallery image is selected, new VM will deploy from marketplace
#$Image = Set-AZImage
#$Image = Set-AZImage -Image_ResourceGroup_Name nonprod-images-westus2 -GalleryName sig_avd_nonprod -ImageName img-avd-nonprod-evd
function Set-AZImage {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$false)][ValidateSet("nonprod-images-westus2","prod-images-westus2")]
            [string] $Image_ResourceGroup_Name,
        [Parameter(Mandatory=$false)][ValidateSet("sig_avd_nonprod","sig_avd_prod")]
            [string] $GalleryName,
        [Parameter(Mandatory=$false)][ValidateSet("img-avd-nonprod-evd","img-avd-prod-evd")]
            [string] $ImageName,
        [Parameter(Mandatory=$false)][string] $Image_LocationName=$LocationName
    )
    if(!($GalleryName)){
        Write-Output "No Image Gallery defined"
        $Publisher = (Get-AzVMImagePublisher -Location $LocationName | where {$_.PublisherName -like "MicrosoftWindowsDesktop"})
        $Offer = (Get-AzVMImageOffer -Location $LocationName -PublisherName $Publisher.PublisherName | where {$_.Offer -like "windows-10"})
        $SKU = (Get-AzVMImageSku -Location $LocationName -PublisherName $Publisher.PublisherName -Offer $offer.Offer | Where {$_.skus -like "21h1-evd"})
        $Versions = (Get-AzVMImage -Location $LocationName -PublisherName $Publisher.PublisherName -Offer $offer.Offer -Sku $SKU.skus)
        $Latest = $Versions[-1]
        $ImageDefinition = $Latest
    }
    else{
        $ImageRG = (Get-AzResourceGroup -Location $Image_LocationName -Name $Image_ResourceGroup_Name)
        $ImageGallery = (Get-AzGallery -ResourceGroupName $ImageRG.ResourceGroupName -Name $GalleryName)
        $ImageDefinition = (Get-AzGalleryImageDefinition -ResourceGroupName $ImageRG.ResourceGroupName -GalleryName $GalleryName -Name $ImageName)
    }
    return $ImageDefinition
}

##Set Local UserName and Password
#$Local_Creds = Set-LocalUser
function Set-LocalUser {
    $VMLocalAdminUser = "LocalAdmin"
    #$VMLocalAdminSecurePassword = ConvertTo-SecureString "$(get-date -f dd-MM)-Password!" -AsPlainText -Force
    $VMLocalAdminSecurePassword = ConvertTo-SecureString "LocalPassword!" -AsPlainText -Force
    $Local_Creds = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);
    return $Local_Creds
}

##Set Networking
#$Subnet = Set-AZNetwork_Subnet
#$Subnet = Set-AZNetwork_Subnet -VNetName "internal-network" -SubnetName "internal-desktops-02"
function Set-AZNetwork_Subnet{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$False)][string] $VNetName = "internal-network",
        [Parameter(Mandatory=$False)][string] $SubnetName = "internal-desktops-02",
        [Parameter(Mandatory=$False)][string] $vNetRG = "Subscription_Network_RG"
    )
    $vNetwork = (Get-AzVirtualNetwork -Name $VNetName)
    $Subnet = (Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vNetwork -Name $SubnetName)
    if(!($Subnet)){
        Write-Output "No Subnet found, please select a subnet from the following list:"
        #$vNets = (Get-AzVirtualNetwork -ResourceGroupName $vNetRG -Name $VNet_Name -ExpandResource 'subnets/ipConfigurations')
        $vNet = (Get-AzVirtualNetwork -Name $vNetName)
        $Subnet = (Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vNet -Name $SubnetName)
        if(!($Subnet)){
            Write-Error "No subnet found"; break
            Write-Output "No Subnet found, please select a subnet from the following list."
            $vNets = (Get-AzVirtualNetwork -ResourceGroupName $vNetRG -Name $VNetName -ExpandResource 'subnets/ipConfigurations')
            foreach ($sub in $vNets.subnets){Write-Output "$($Sub.Name)"}
            Write-Output "Exiting...";break
        }
        Write-Output "Exiting...";break    
    }
    #$SubnetAddressPrefix = $Subnet.AddressPrefix
    #$VnetAddressPrefix = $VirtualNetwork.AddressSpace.AddressPrefixes
    return $Subnet
}

# ##Create vNIC
# #$NIC = (New-vNIC -ResourceGroupName $RG.ResourceGroupName -SubnetID $Subnet.Id -NICName "$($ComputerName.Name)-vNIC")
# function New-vNIC {
#     [CmdletBinding(SupportsShouldProcess=$true)]
#     param (
#         [Parameter(Mandatory=$True)][string] $ResourceGroupName,
#         [Parameter(Mandatory=$True)][string] $SubnetID,
#         [Parameter(Mandatory=$False)][string] $NICName = "$ComputerName-vNIC"
#     )
#     $NIC = (New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $LocationName -SubnetId $SubnetID)
#     return $NIC
# }

# ##Configure VM variables
# #$VirtualMachine = Set-AZVm -VMName $ComputerName.Name -SubnetName $Subnet.Name -NICId $NIC.Id 
# function Set-AZVM {
#     [CmdletBinding(SupportsShouldProcess=$true)]
#     param (
#         [Parameter(Mandatory=$True)][string] $VMName,
#         [Parameter(Mandatory=$True)][string] $SubnetName, $NICId,
#         [Parameter(Mandatory=$False)][string] $VMSize = "Standard_D4s_v5"
#     )
#     if(!($Local_Creds)){Write-Error "Missing Local User Credentials";break}
#     $VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize
#     $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $Local_Creds -ProvisionVMAgent -EnableAutoUpdate
#     $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NICId
#     #$VirtualMachine = Set-AzVMBootDiagnostic -VM $VirtualMachine -ResourceGroupName $RG.ResourceGroupName -Disable
#     #if no gallery image was selected select from marketplace
#     #Write-Output "Missing VM Source Image, Selecting from Azure Marketplace"
#     if (!$($ImageDefinition)) {
#         $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine `
#                     -PublisherName "MicrosoftWindowsDesktop" `
#                     -Offer "Windows-10" `
#                     -Skus "21h1-evd" `
#                     -Version "19043.1466.220108"
#     }
#     else{$VirtualMachine = Set-AzVMSourceImage -Id $Image.Id -VM $VirtualMachine}
#     return $VirtualMachine
# }

# #Deploy VM
# #$VM = New-AzVirtualMachine -VMName $ComputerName.Name -ResourceGroupName $RG.ResourceGroupName
# function New-AzVirtualMachine {
#     [CmdletBinding(SupportsShouldProcess=$true)]
#     param (
#         [Parameter(Mandatory=$True)][string] $VMName,
#         [Parameter(Mandatory=$True)][string] $ResourceGroupName
#     )
#     if (!($LocationName)) {Write-Error "Missing Location Name"; break}
#     if (!($VirtualMachine)) {Write-Error "Missing VirtualMachine, run Set-AZVM"; break}
#     if(!($VMName)){$VMName=$ComputerName}
#     $RG = (Get-AzResourceGroup $ResourceGroupName)
#     if (!($RG)) {Write-Error "Missing Resource Group"; break}
#     Write-Output "Check to see if '$($VMName)' exists..."
#     $VM = (Get-AZVM -Name $VMName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue)
#     if (!($VM)) {
#         Write-Output "Deploying VM '$($VMName)' to Resource Group '$($ResourceGroupName)'"
#         New-AzVM -ResourceGroupName $RG.ResourceGroupName -Location $LocationName -VM $VirtualMachine -Verbose 
#     }
#     else  {Write-Error "'$($VMName)' already exists!"; break}

#     $VM = (Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName)
#     return $VM
# }

##Prompts to enter AD Join Credentials. 
#$AD_Creds = Set-DomainJoinCreds
function Set-DomainJoinCreds {
    [CmdletBinding(SupportsShouldProcess=$true)]param ()
    #Write-Output "Enter Domain Join Credentials"  
    $domain_creds = Get-Credential DOMAIN\UserName -Message "Domain Join Credentials"
    return $domain_creds
}

##Join AZ VM to AD Domain
#NetJoinDomain function - https://docs.microsoft.com/en-us/windows/win32/api/lmjoin/nf-lmjoin-netjoindomain
#Join-ADDomain -VMName $VM.Name -ResourceGroupName $RG.ResourceGroupName -OU $OU.DistinguishedName
function Join-ADDomain {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter()][string] $VMName, $ResourceGroupName, $OU
    )
    $JoinOpt = "0x00000003" #specifies the option to join a domain, 0x00000001 + 0x00000002
    $VM = (Get-AZVM -Name $VMName)
    $RG = (Get-AzResourceGroup $ResourceGroupName)
    if (!($VM)) {Write-Error "'Missing VM"; break}
    if (!($RG)) {Write-Error "Missing Resource Group"; break}
    if (!($LocationName)) {Write-Error "Missing Location Name"; break}
    if (!($DomainName)) {Write-Error "Missing Domain Name"; break}
    if (!($OU)) {Write-Error "Missing AD OU"}
    if (!($AD_Creds)) {Write-Error "Missing AD Creds"}
    else {
        Write-Host "Joining domain $DomainName. '$(Get-Date)'"
        Set-AzVMADDomainExtension `
            -DomainName $DomainName `
            -VMName $VMName `
            -ResourceGroupName $ResourceGroupName `
            -Location $LocationName `
            -Credential $AD_Creds `
            -OUPath $OU `
            -JoinOption $JoinOpt `
            -Restart `
            -Verbose 
        Write-Host "Completed at $(Get-Date)"
    }
}

##Install RDInfra Agent and Boot Loader
##Pass Token as Parameter
#Install-Agents -VMName $VMName -ResourceGroupName $ResourceGroupName
function Install-Agents {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True)][string] $VMName,
        [Parameter(Mandatory=$True)][string] $ResourceGroupName
        #[Parameter(Mandatory=$True)][string] $Token
    )
    $VM = (Get-AZVM -Name $VMName)
    $RG = (Get-AzResourceGroup $ResourceGroupName)
    if (!($VM)) {Write-Error "'Missing VM";break}
    if (!($RG)) {Write-Error "Missing Resource Group";break}
    if (!($Token)) {Write-Error "Missing Token";break}
    else {
        Write-Host "Installing AVD Agents..."
        #Install_RD-Agents.ps1 in same github dir.
        Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -Name $VMName -CommandId 'RunPowerShellScript' -ScriptPath  '.\Install_RDSAgent.ps1' -Parameter @{token=$Token.Token}
    }
}

function Add-LocalAdmin {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$true)][string] $VMName,$ADUser
    ) 
    [System.String]$ScriptBlock = {
        param ($UserID)
        $Administrators = (Get-LocalGroup -Name "Administrators")
        Add-LocalGroupMember -Group $Administrators -Member $UserID
    }
    $TempScript = "LocalAdminScript.ps1"
    Out-File -FilePath $TempScript -InputObject $ScriptBlock -NoNewline
    $AZVM = (Get-AzVM -Name $VMName)
    if(!($AZVM)){Write-Error "No VM Found.";break}
    else{
        Write-Output "Attempting to run script...$(Get-Date -f HH:mm)"
        Invoke-AzVMRunCommand -ResourceGroupName $AZVM.ResourceGroupName -Name $VMName -CommandId 'RunPowerShellScript' -ScriptPath $TempScript -Parameter @{UserID=$ADUser}
        Write-Output "Script completed...$(Get-Date -f HH:mm)"
    }
    Remove-Item -Path $TempScript -Force -ErrorAction SilentlyContinue
}
#EndRegion Deploy Azure VM

#####################
#####END of MAIN#####
#####################

####################
#Region Scratch 

<#
##Creates FSlogix GPO for Windows10-EVD Multi-Session/Remote Desktop Session Host. 
#$NewGPO =(New-FSLogixGPO)
function New-FSLogixGPO {
    [CmdletBinding(SupportsShouldProcess=$true)]param ()
    if (!($NamingScheme)){Write-Error "Missing Naming Scheme"; break}
    #Source GPO is a Domain Starter GPO
    $SourceGPO = "Fslogix_MultiSession_Computer"
    $NewGPOName = "FSLogix-$NamingScheme"
    if (@(Get-GPO $NewGPOName -ErrorAction SilentlyContinue).Count) {
        Write-Error "GPO '$($NewGPOName)' already exists!"} 
    else {
        Write-Output "GPO '$($NewGPOName)' not found in domain, creating New GPO"
        New-GPO -Name $NewGPOName -StarterGpoName $SourceGPO | Out-Null
        Write-Output "Waiting for AD replication...";Start-Sleep -Seconds 10
    }
    $GPO = (Get-GPO -Name $NewGPOName)
    return $GPO
}

##Set GPO Delegated Permissions
#Set-FslogixDelegatedAdmins -GpoName $NewGPO.DisplayName -ADAdminGroup $ADAdminGroup.Name
function Set-FslogixDelegatedAdmins{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True)][string] $GpoName,
        [Parameter(Mandatory=$True)][string] $ADAdminGroup
    )
    #Set-GPPermission -Name $GpoName -Replace -PermissionLevel GpoRead -TargetName "Everyone" -TargetType Group | Out-Null
    Set-GPPermission -Name $GpoName -Replace -PermissionLevel GpoEditDeleteModifySecurity -TargetName "Domain-ADMINS" -TargetType Group | Out-Null       
    Set-GPPermission -Name $GpoName -Replace -PermissionLevel GpoEdit -TargetName $ADAdminGroup -TargetType Group | Out-Null
}

##Set/Configure GPO based on above vars (GPO Name and FSlogix Folder Path)
#Set-FSLogixFolderPath -GpoName $NewGPO.DisplayName -FolderPath $NewFolderPath
function Set-FSLogixFolderPath {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True)][string] $GpoName,$FolderPath,
        [Parameter(Mandatory=$False)][string] $UserProfileShare ="\\fileServer.domain.net\fslogix-westus"
    )
    if (!($FolderPath)){Write-Error "New Folder Path Missing";break}
    if (!($GPOName)){Write-Error "GPO Name Missing";break}
    if (!($UserProfileShare)){Write-Error "User Profile Share Missing"}
    else {
        Write-Output "Configuring GPO '$($GPOName)' for FSLogix VHD and Redirection Locations."
        Write-Output "VHDLocations set to '$($FolderPath)'"
        Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\FSLogix\Profiles" -ValueName "VHDLocations" -Value $($FolderPath) -Type String | Out-Null
        Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\FSLogix\ODFC" -ValueName "VHDLocations" -Value $($FolderPath) -Type String | Out-Null
        Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\FSLogix\Profiles" -ValueName "RedirXMLSourceFolder" -Value $("$($UserProfileShare)\Redirections") -Type String | Out-Null
    }
}

##Set GPO Link for above GPO and OU
#Set-GPLink -NewGPO $NewGPO.DisplayName -OU $OU
function Set-GPLink {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ([Parameter(Mandatory=$True)][string] $NewGPO,$OU)
    if (!($NewGPO)){Write-Error "GPO Name Missing";break}
    if (!($OU)){Write-Error "OU Missing";break}
    $GPLinks = (Get-GPInheritance -Target $OU)
    if (($link)){Write-Error "'$($NewGPO)' is already linked to '$($OU)'!"}
    else {
        Write-Output "Link GPO '$NewGPO' to OU '$($OU)'"
        New-GPLink -Name $NewGPO -Target $OU -LinkEnabled Yes | Out-Null
    }
}
 $link = $GPLinks.GpoLinks | Where {$_.DisplayName -like $NewGPO}


##Set AD Group for administrators
#$ADAdminGroup = (Set-ADAdminGroup)
function Set-ADAdminGroup {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter()][string] $ADAdminGroup
    )
    $Admins = (Get-ADGroup $ADAdminGroup)
    if (!($Admins)){Write-Error "No Administrators Found";break}
    else {Write-Host "Admins are set to '$($Admins.Name)'"}
    return $Admins
}

##Create New FSlogix Folder. Requires Access to Folder Path
#$NewFolderPath = (New-FSlogixFolder)
#$NewFolderPath = (New-FSlogixFolder -FolderName UserProfiles-TEST)
function New-FSlogixFolder {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$false)][string] $UserProfileShare = "\\fileserver.domain.net\fslogix-eastus",
        [Parameter(Mandatory=$false)][string] $FolderName

    )
    if (!(Test-Path $UserProfileShare)){Write-Error "Missing User Profile Share";break}
    if (!($FolderName)){
            if (!($NamingScheme)){Write-Error "Missing Naming Scheme"; break}
            $FolderName = "$NamingScheme"
    }
    $FolderPath = "$UserProfileShare\$FolderName"
    if (@(Test-Path $FolderPath)){Write-Error "Folder already exists!"}
    if (!(Test-Path $FolderPath)) {    
        Write-Output "Folder '$($FolderPath)' was not found."
        Write-Output "Creating folder' $($FolderPath)'."
        New-Item -Path $FolderPath -ItemType Directory | Out-Null   
    } 
    return $FolderPath
}

##Sets ACLs on FSlogix Directory
#Set-FolderPermission -FolderPath $NewFolderPath -ADAdminGroup $ADAdminGroup.Name
function Set-FolderPermission {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter()][string] $FolderPath, $ADAdminGroup
    )
    if(!($ADAdminGroup)){Write-Error "Missing Delegated Administrators";break}
    if(!($FolderPath)){Write-Error "Missing Folder Path";break}
    
    #Disable Folder Inheritance
    Write-Output "Remove Inheritance on '$($FolderPath)"
    icacls $FolderPath /inheritance:d

    #Remove Permission for Everyone
    Write-Output "Remove 'NT Authority\Everyone' from '$($FolderPath)'"
    icacls $FolderPath /remove 'NT Authority\Everyone' /t /c

    #Set ACLs
    #https://docs.microsoft.com/en-us/fslogix/fslogix-storage-config-ht
    $objACL = Get-ACL -Path $FolderPath
    $objACL.SetAccessRuleProtection($True, $False)

    $FullRights = [System.Security.AccessControl.FileSystemRights]::FullControl
    $ModifyRights = [System.Security.AccessControl.FileSystemRights]::Modify
    $InheritanceYes = [System.Security.AccessControl.InheritanceFlags]::"ContainerInherit","ObjectInherit"
    $InheritanceNo = [System.Security.AccessControl.InheritanceFlags]::None
    $PropagationFlag = [System.Security.AccessControl.PropagationFlags]::None
    $objType =[System.Security.AccessControl.AccessControlType]::Allow 

    $objUser = New-Object System.Security.Principal.NTAccount("NT AUTHORITY\SYSTEM") 
    $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule($objUser, $FullRights, $InheritanceYes, $PropagationFlag, $objType) 
    $objACL.SetAccessRule($objACE) 
    Write-Output "'$($objUser)' permissions are $($FullRights), $($InheritanceYes), $($PropagationFlag), $($objType)"

    $objUser = New-Object System.Security.Principal.NTAccount("AD\$ADAdminGroup") 
    $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule($objUser, $FullRights, $InheritanceYes, $PropagationFlag, $objType) 
    $objACL.AddAccessRule($objACE)
    Write-Output "'$($objUser)' permissions are $($FullRights), $($InheritanceYes), $($PropagationFlag), $($objType)"
 
    $PropagationFlag = [System.Security.AccessControl.PropagationFlags]::InheritOnly
    $objUser = New-Object System.Security.Principal.NTAccount("CREATOR OWNER") 
    $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule($objUser, $FullRights, $InheritanceYes, $PropagationFlag, $objType) 
    $objACL.AddAccessRule($objACE)
    Write-Output "'$($objUser)' permissions are $($FullRights), $($InheritanceYes), $($PropagationFlag), $($objType)"

    $objUser = New-Object System.Security.Principal.NTAccount("NT Authority\Authenticated Users") 
    $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule($objUser, $ModifyRights, $InheritanceNo, $PropagationFlag, $objType) 
    $objACL.AddAccessRule($objACE)
    Write-Output "'$($objUser)' permissions are $($ModifyRights), $($InheritanceNo), $($PropagationFlag), $($objType)"

    (Get-Item $FolderPath).SetAccessControl($objACL)
    Write-Output "Security settings have been set."
}

#>

#EndRegion
####################





