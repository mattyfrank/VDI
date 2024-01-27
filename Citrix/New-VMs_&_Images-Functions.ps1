##author: Matthew.Franklin
##updated: 10-21-2021
<#
.SYNOPSIS
This was designed to provision new resources within VMware and ActiveDirectory. 
Custom functions can be combined to fully provision new VDI Images and all dependencies. 

.DESCRIPTION
!REQUIRED Modules! VMware PowerCLI & ActiveDirectory.

Call functions as needed. Use tab complete on each function to see available parameters.
Functions were designed to be modular and used in combination to simplify routine tasks. 
Some functions will stop on error, while others will alert and continue.
Parameters could be optional or mandatory. If a parameter is not provided, some functions will auto-generate results. 
Assign a variable to a function, and use the variable in other functions as an input parameter.

VMware/vCenter functions include:  Set-DCVariables, Connect-Vcenter, Set-DiskSize, Set-MemorySize, Set-CPU(count), Select-Template, Select-Cluster, Select-Network, 
Select-VMHost, New-VMFolder, Set-VMFolder, Set-VMName, New-VMcustomization, New-VirtualMachine, Set-VMNotes, Set-VMHardware, Set-VMcustomization, New-Snap, 
Shutdown-VirtualMachine, Start-VirtualMachine, Update-VMwareTools.

Functions include: Set-Administrators, New-OU, Set-OU, New-FSlogixGPO, Set-FSlogixDelegatedAdmins, Set-FSlogixFolderPath, Set-GPLink, Set-ComputerName, 
New-Computer, Set-IMG.

Admin functions include: New-FSlogixFolder, Set-FolderPermission, Set-DomainJoinCreds, Set-LocalAdminCreds.

Combined function examples include: New-VDI_IMG, New-PersistentDesktop, New-RDSH_IMG, New-SLA_VM

.EXAMPLE 
$ComputerName = Set-ComputerName -ComputerName $ComputerName
.EXAMPLE
New-RDSH_IMG -Datacenter VDI_DC2 -UnitName UNIT -NamingScheme 2022 -DiskSize 120 -Memory 12 -NumCPU 2 -Template "Win10-1909" -Cluster "DC1-C03-NonGPU" -Network "DC1-C03-VLAN344" -ComputerName "Xen-2022" -Administrators "Matthew.Franklin"
.EXAMPLE
New-PersistentDesktop -Datacenter VDI_DC2 -UnitName UNIT -DiskSize 120 -Memory 12 -NumCPU 2 -Template "vdi_win10-slim_20h2_20210824" -Cluster "DC1-C03-T4" -Network "DC1-C03-VLAN344" -ComputerName "Xen-2022" -Administrators "Matthew.Franklin"
.EXAMPLE
New-SLA_VM -Datacenter DC2 -$UnitName UNIT -ComputerName TEST-VM -DiskSize 128 -Memory 12 -CPU 2 -Administrtors OUAdmins

#>

##Import-Module ActiveDirectory
##Import-Module VMware.PowerCLI

#Disable VMware Customer Experience Program
#Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP $false -Confirm:$false

#### Set Env Variables for each datacenter####

function Set-DCVariables {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ([Parameter(Mandatory)][ValidateSet("VDI_DC1","VDI_DC2","DC2","DC1")][string] $DataCenter)
    $DCVars = switch ($DataCenter) {
        DC2{ 
            [PSCustomObject]@{
            datastore = "VDI_DC1_ssd1"
            vcenter = "vdi_vCenter1.DOMAIN.net"
            NetworkShare = "\\SERVER1\VDI_DC1-vdi-upm1"
            }
        }
        VDI_DC2{
            [PSCustomObject]@{
            datastore = "VDI_DC2_ssd"
            vcenter = "vdi_vCenter2.DOMAIN.net"
            NetworkShare = "\\SERVER2\VDI_DC2-vdi-upm"
            }
        }
        DC1{
            [PSCustomObject]@{
            datastore = "DC1-SSD"
            vcenter = "vCenter1.DOMAIN.net"
            }
        }
        DC2{
            [PSCustomObject]@{
            datastore = "DC2-SSD"
            vcenter = "vCenter2.DOMAIN.net"
            }
        }
    }
    return $DCVars
}

#Connect to preapproved vCenters
function Connect-Vcenter {
   [CmdletBinding(SupportsShouldProcess=$true)]
   param (
       [Parameter(Mandatory=$True,HelpMessage="Choose from VDI_DC1/VDI_DC2, or SLA DC2/DC1.")]
       [ValidateSet("vdi_vCenter.DOMAIN.net","vCenter1.DOMAIN.net","vCenter2.DOMAIN.net","vdi_vCenter2.DOMAIN.net")][string] $Datacenter
   )
    Write-Host -ForegroundColor Green "Connecting to '$($Datacenter)'"
    Connect-VIServer $Datacenter
}

#Set VM Hard Disk Size
function Set-DiskSize{
    [CmdletBinding(SupportsShouldProcess=$false)]
        param ([Parameter(Mandatory=$True,HelpMessage="VM Disk Size in GB, 30-1024")]
        [ValidateRange(30,1024)][int] $DiskSize
    )
    return $DiskSize
}

#Set VM Memory Size
function Set-MemorySize{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True,HelpMessage="VM Memory Size in GB, 1-32")]
        [ValidateRange(1,32)][int]$Memory
    )
    return $Memory
}

#Set VM CPU Count
function Set-CPU{
    [CmdletBinding(SupportsShouldProcess=$true)]
        param ([Parameter(Mandatory=$True,HelpMessage="VM CPU Count, 2,4,6,8")]
        [ValidateSet('2','4','6','8')][int] $NumCPU
    )
    return $NumCPU
}

#Get/Set Vcenter Template
function Select-Template {
    [CmdletBinding(SupportsShouldProcess=$true)]param($Template)
    if(!($Template)){
        $TemplateFolder = "Templates_Packer" 
        $Template = Get-Folder $TemplateFolder | Get-Template | Out-GridView -OutputMode:Single -Title "Select the template you would like to use."
    }
    Write-Host -ForegroundColor DarkYellow "You selected $($Template)"
    return $Template
}

#Get/Set Vcenter Compute Cluster
function Select-Cluster {
    [CmdletBinding(SupportsShouldProcess=$true)]param($Cluster)    
    if(!($Cluster)){$Cluster = Get-Cluster | Out-GridView -OutputMode:Single -Title "Select the compute cluster you would like to use."}
    Write-Host -ForegroundColor DarkYellow "You selected $($Cluster)"
    return $Cluster
}

#Get/Set VM Network 
function Select-Network {
    [CmdletBinding(SupportsShouldProcess=$true)]param($Network)
    if(!($Network)){
        $NetworkList = Get-VDPortgroup | Where {$_.Name -notlike "*VMKernel*" -and $_.Name -notlike "Management Network" -and $_.Name -notlike "Management" -and $_.Name -notlike "VDI6.5_dvSwitch*"}
        $Network = $NetworkList | Out-GridView -OutputMode:Single -Title "Select the virtual network you would like to use."
    }
    Write-Host -ForegroundColor DarkYellow "You selected $($Network)"
    return $Network
}

#Get/Set VM's Host. Required when DRS is not enabled
function Select-VMHost {
    [CmdletBinding(SupportsShouldProcess=$true)]param($VMHost)
    if(!($VMHost)){$VMHost = Get-Cluster $Cluster | Get-VMHost | where {$_.ConnectionState -like 'Connected'}| sort}
    Write-Host -ForegroundColor DarkYellow "Selected: $($VMHost[0])"
    return $($VMHost[0])
}

#Set UnitName for delegated access controls
function Set-UnitName{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$True,HelpMessage="UnitName will be used to name, organize, and delegate admin access.")]
        [ValidateLength(2,4)][string] $UnitName
    )
    Write-Host -ForegroundColor DarkYellow "You selected unit '$UnitName'"
    return $UnitName
}

#Set naming scheme to name resources. (Examples: 2021,Test,Staff)
function Set-NamingScheme {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$True,HelpMessage="Naming Scheme will be used to name and organize resources.")]
        [ValidateLength(2,7)][string] $NamingScheme
    )
    Write-Host -ForegroundColor DarkYellow "You selected unit '$NamingScheme'"
    return $NamingScheme

}

#Sets VM's Local Administrator. Auto selected based on UnitName, or can be overloaded by calling parameter.
function Set-Administrators {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([Parameter()][string] $Administrators)
    if(!($Administrators)) {
        if(!($UnitName)){Write-Error "Missing Unit Name"; break}
        else {$Administrators = "Xen-$UnitName-Admins"}
    }
    try {Get-ADGroup $Administrators | Out-Null}
    catch {Write-Error "AD Group does not exist"; break}
    Write-Host -ForegroundColor DarkYellow "You selected '$Administrators'"
    return $Administrators
    
}

####  Fslogix Folder ####
#Creates New Directory based on $DC.Vars
function New-FSlogixFolder {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True,HelpMessage="UNC Path to Network Share for User Profiles")]
        [ValidateSet("\\nas-upm.DOMAIN.net\vdi_upm","\\nas-vdi-upm.DOMAIN.net\VDI_DC2-upm")][string] $UserProfileShare
        #[Parameter()][string] $UnitName,
        #[Parameter()][string] $NamingScheme
    )
    if (!(Test-Path $UserProfileShare)){Write-Error "Missing User Profile Share";break}
    if (!($UnitName)){Write-Error "Missing Unit Name"; break}
    if (!($NamingScheme)){Write-Error "Missing Naming Scheme"; break}
    $FolderPath = "$UserProfileShare\$UnitName-$NamingScheme"
    if (@(Test-Path $FolderPath)){Write-Error "Folder already exists!"}
    if (!(Test-Path $FolderPath)) {    
        Write-Host -ForegroundColor DarkYellow "Folder '$($FolderPath)' was not found."
        Write-Host -ForegroundColor DarkYellow "Creating folder' $($FolderPath)'."
        New-Item -Path $FolderPath -ItemType Directory | Out-Null   
    } 
    return $FolderPath
}

#Sets ACLs on FSlogix Directory
function Set-FolderPermission {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter()][string] $FolderPath,
        [Parameter()][string] $Administrators
    )
    if(!($Administrators)){Write-Error "Missing Delegated Administrators";break}
    if(!($FolderPath)){Write-Error "Missing Folder Path";break}
    
    #Disable Folder Inheritance
    Write-Host -ForegroundColor DarkYellow "Remove Inheritance on '$($FolderPath)"
    icacls $FolderPath /inheritance:d

    #Remove Permission for Everyone
    Write-Host -ForegroundColor DarkYellow "Remove 'NT Authority\Everyone' from '$($FolderPath)'"
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
    Write-Host -ForegroundColor DarkYellow "'$($objUser)' permissions are $($FullRights), $($InheritanceYes), $($PropagationFlag), $($objType)"

    $objUser = New-Object System.Security.Principal.NTAccount("AD\$Administrators") 
    $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule($objUser, $FullRights, $InheritanceYes, $PropagationFlag, $objType) 
    $objACL.AddAccessRule($objACE)
    Write-Host -ForegroundColor DarkYellow "'$($objUser)' permissions are $($FullRights), $($InheritanceYes), $($PropagationFlag), $($objType)"
 
    $objUser = New-Object System.Security.Principal.NTAccount("AD\XEN-OUADMINS") 
    $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule($objUser, $FullRights, $InheritanceYes, $PropagationFlag, $objType) 
    $objACL.AddAccessRule($objACE)
    Write-Host -ForegroundColor DarkYellow "'$($objUser)' permissions are $($FullRights), $($InheritanceYes), $($PropagationFlag), $($objType)"

    $PropagationFlag = [System.Security.AccessControl.PropagationFlags]::InheritOnly
    $objUser = New-Object System.Security.Principal.NTAccount("CREATOR OWNER") 
    $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule($objUser, $FullRights, $InheritanceYes, $PropagationFlag, $objType) 
    $objACL.AddAccessRule($objACE)
    Write-Host -ForegroundColor DarkYellow "'$($objUser)' permissions are $($FullRights), $($InheritanceYes), $($PropagationFlag), $($objType)"

    $objUser = New-Object System.Security.Principal.NTAccount("NT Authority\Authenticated Users") 
    $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule($objUser, $ModifyRights, $InheritanceNo, $PropagationFlag, $objType) 
    $objACL.AddAccessRule($objACE)
    Write-Host -ForegroundColor DarkYellow "'$($objUser)' permissions are $($ModifyRights), $($InheritanceNo), $($PropagationFlag), $($objType)"

    (Get-Item $FolderPath).SetAccessControl($objACL)
    Write-Host -ForegroundColor DarkYellow "Security settings have been set."
}

#### Active Directory Functions
#Creates New AD Organization Unit (OU). OU Path is based on parameters for type of deployment selected.
function New-OU {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True,HelpMessage="NonPersistentSingleSession 'Workstation', VirtualDesktopServer 'RDSH', ApplicationServer 'AppSrv', Azure VirtualDesktop 'AVD'")]
        [ValidateSet("Workstation","RDSH","AppSrv, AVD")][string] $OU_Type
    )
    if (!($UnitName)){Write-Error "Missing Unit Name"; break}
    if (!($NamingScheme)){Write-Error "Missing Naming Scheme"; break}
    $OUPath = switch ($OU_Type) {
        Workstation {Get-ADOrganizationalUnit -Identity "OU=$UnitName,OU=VDI,OU=Workstations,OU=_XEN,DC=ad,DC=DOMAIN,DC=NET";break}
        RDSH {Get-ADOrganizationalUnit -Identity "OU=$UnitName,OU=Xen7 RDSH,OU=Servers,OU=_XEN,DC=ad,DC=DOMAIN,DC=NET";break} 
        AppSrv {Get-ADOrganizationalUnit -Identity "OU=$UnitName,OU=Xen7 App Servers,OU=Servers,OU=_XEN,DC=ad,DC=DOMAIN,DC=NET";break}
        AVD {Get-ADOrganizationalUnit -Identity "OU=$UnitName,OU=WVD,OU=Workstations,OU=_XEN,DC=ad,DC=DOMAIN,DC=NET";break}
    }
    Write-Host -ForegroundColor DarkYellow "Parent OU path is '$($OUPath)'."
    $NewOU = "$UnitName-$NamingScheme"
    try {
        $OU = ("OU=$NewOU,$OUPath")
        Get-ADOrganizationalUnit $OU -ErrorAction SilentlyContinue | Out-Null
        Write-Error "OU Already Exists!"
    } 
    catch {
        Write-Host -ForegroundColor DarkYellow "OU '$($NewOU)' does not exists, creating OU." 
        New-ADOrganizationalUnit -Name $NewOU -Path $OUPath
        Start-Sleep -Seconds 1
    }
    $OU = (Get-ADOrganizationalUnit -Identity "OU=$NewOU,$OUPath")
    return $OU
}

#Get/Set AD OU for Persistent Staff VM based on UnitName, or use OU parameter to overload for SLA OU. 
function Set-OU {
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [Parameter(Mandatory=$False,HelpMessage="Enter OU distinguishedName")][string] $OU,
        [Parameter(Mandatory=$False,HelpMessage="Enter Unit Name between 2 and 4 characters")][ValidateLength(2,4)][string] $UnitName
    )
    if(!($OU)) {
        if(!($UnitName)){Write-Error "Missing Unit Name"; break}
        $OU = (Get-ADOrganizationalUnit -Identity "OU=$UnitName,OU=PersistentDesktops,OU=Workstations,OU=_XEN,DC=ad,DC=DOMAIN,DC=NET")
    }
    return $OU
}

#Creates FSlogix GPO based on Single/Multi Session deployment.
#SourceGPO is a refrencing DOMAIN.net Starter GPO.  
function New-FSLogixGPO {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True,HelpMessage="SingleSession or MultiSession")][ValidateSet("SingleSession","MultiSession")][string] $SearchRoaming,
        [Parameter()][string]$UnitName,$NamingScheme
    )
    if (!($UnitName)){Write-Error "Missing Unit Name"; break}
    if (!($NamingScheme)){Write-Error "Missing Naming Scheme"; break}
    switch ($SearchRoaming) {
        #Enable search roaming
        #https://docs.microsoft.com/en-us/fslogix/configure-search-roaming-ht#configure-multi-user-search
        SingleSession {
            #single session search
            $SourceGPO = "Fslogix_SingleSession_Computer"
            $NewGPOName = "Xen-FSLogix-$UnitName-$NamingScheme-singlesession"
            break
        } 
        MultiSession {
            #multi session search
            $SourceGPO = "Fslogix_MultiSession_Computer"
            $NewGPOName = "Xen-FSLogix-$UnitName-$NamingScheme-multisession"
            break
        }
    }
    if (@(Get-GPO $NewGPOName -ErrorAction SilentlyContinue).Count) {
        Write-Error "GPO '$($NewGPOName)' already exists!"} 
    else {
        Write-Host -ForegroundColor DarkYellow "GPO '$($NewGPOName)' not found in domain, creating New GPO"
        New-GPO -Name $NewGPOName -StarterGpoName $SourceGPO | Out-Null
        Write-Host -ForegroundColor DarkYellow "Waiting for AD replication...";Start-Sleep -Seconds 10
    }
    $GPOName = (Get-GPO -Name $NewGPOName).DisplayName
    return $GPOName
}

#Set GPO Delegated Permissions
function Set-FslogixDelegatedAdmins{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True)][string] $GpoName,
        [Parameter(Mandatory=$True)][string] $Administrators
    )
    Set-GPPermission -Name $GpoName -Replace -PermissionLevel GpoRead -TargetName "XEN-ADMINS" -TargetType Group | Out-Null
    Set-GPPermission -Name $GpoName -Replace -PermissionLevel GpoEditDeleteModifySecurity -TargetName "XEN-OUADMINS" -TargetType Group | Out-Null       
    Set-GPPermission -Name $GpoName -Replace -PermissionLevel GpoEdit -TargetName $Administrators -TargetType Group | Out-Null
}

#Set/Configure GPO based on above vars (GPO Name and FSlogix Folder Path)
function Set-FSLogixFolderPath {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ([Parameter()][string] $GpoName,$FolderPath)
    if (!($FolderPath)){Write-Error "New Folder Path Missing"}
    if (!($GPOName)){Write-Error "GPO Name Missing"}
    else {
        Write-Host -ForegroundColor DarkYellow "Configuring GPO '$($GPOName)' for FSLogix VHD and Redirection Locations."
        Write-Host -ForegroundColor DarkYellow "VHDLocations set to '$($FolderPath)'"
        Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\FSLogix\Profiles" -ValueName "VHDLocations" -Value $($FolderPath) -Type String | Out-Null
        Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\Policies\FSLogix\ODFC" -ValueName "VHDLocations" -Value $($FolderPath) -Type String | Out-Null
        Set-GPRegistryValue -Name $GPOName -Key "HKLM\Software\FSLogix\Profiles" -ValueName "RedirXMLSourceFolder" -Value $("$($UserProfileShare)\Redirections") -Type String | Out-Null
    }
}

#Set GPO Link for above GPO and OU
function Set-GPLink {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ([Parameter()][string] $GpoName,$OU)
    if (!($GPOName)){Write-Error "GPO Name Missing"}
    if (!($OU)){Write-Error "OU Missing"}
    $GPLinks = Get-GPInheritance -Target $OU
    $link = $GPLinks.GpoLinks | Where {$_.DisplayName -like $GPOName}
    if (($link)){Write-Error "'$($GPOName)' is already linked to '$($OU)'!"}
    else {
        Write-Host -ForegroundColor DarkYellow "Link GPO '$($GPOName)' to OU '$($OU)'"
        New-GPLink -Name $GPOName -Target $OU -LinkEnabled Yes | Out-Null
    }
}

#Set ActiveDirectory Computer Object Name
function Set-ComputerName {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ([Parameter()][ValidateLength(4,15)][string]$ComputerName)
    if (!($UnitName)){Write-Error "Missing Unit Name"; break}
    if (!($NamingScheme)){Write-Error "Missing Naming Scheme"; break}
    if (!($ComputerName)) {$ComputerName = "$UnitName-$NamingScheme-IMG"}
    return $ComputerName
}

#Create New AD Computer Object. Overload with ComputerName and OU parameters. Will alert if Computer Object already exists. 
function New-Computer {
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [Parameter(Mandatory=$True)][ValidateLength(4,15)][string] $ComputerName,
        [Parameter(Mandatory=$True)][string] $OU
    )
    if(!($ComputerName)){Write-Error "Missing Computer Name"; break}
    if (!($OU)) {Write-Error "Missing OU";break}
    
    #Verify the computer object does not exist
    try {
        Get-ADComputer $ComputerName -ErrorAction SilentlyContinue | Out-Null
        Write-Host -ForegroundColor Red `n"Warning!!!`nComputer Object '$($ComputerName)' already exists."
        Write-Host -ForegroundColor Red "If you proceed, it will break the existing computer's domain trust."`n
        $userinput = $(Write-Host -ForegroundColor Green "Do you want to override this Computer Name? (y)es/(n)o: " -NoNewline; Read-Host)
        switch ($userinput){
            y { Write-Host -ForegroundColor DarkYellow "'$($ComputerName)' is set."; break} 
            n {
                Write-Host -ForegroundColor DarkYellow "Please select a new computer name."
                [ValidateLength(4,15)][string] $ComputerName = $(Write-Host "Enter the new Computer Name: " -ForegroundColor Green -NoNewline; Read-Host) 
                Write-Host -ForegroundColor DarkYellow "New Computer Name is '$($ComputerName)'"
                break
            }
        }#End Switch
    } catch {
        Write-Host -ForegroundColor DarkYellow "'$($ComputerName)' was not found in the domain."
        Write-Host -ForegroundColor DarkYellow "Creating New Computer Object '$($ComputerName)' in OU '$($OU.Name)'"
        New-ADComputer -Name $ComputerName -SamAccountName $ComputerName -Path $OU
    }
    return $ComputerName
}

#Set Computer Object as Member of AD Group for Filtered GPO policy.
function Set-IMG {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ([Parameter()][ValidateLength(4,15)][string]$ComputerName)
    if (!($ComputerName)){Write-Error "Missing Computer Name"; break}
    try {
        Get-ADComputer $ComputerName | Out-Null
        Write-Host -ForegroundColor DarkYellow "Adding $($ComputerName) to AD Security Group 'AD\Golden-Images'"
        Add-ADGroupMember 'Golden-Images' -Members (Get-AdComputer $ComputerName)
    }
    catch {Write-Error "No Computer Object Found."} 
}

#### Set Credentials ####
#Prompts to enter AD Join Credentials. Stores as secure object. 
function Set-DomainJoinCreds {
    [CmdletBinding(SupportsShouldProcess=$true)]param ()
    Write-Host -ForegroundColor DarkYellow "Enter Domain Join Credentials"  
    $domain_creds = Get-Credential -Message "Domain Join Credentials"
    return $domain_creds
}

#Converts local admin credentials as secure string. Can overload with parameter. 
function Set-LocalAdminCreds {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ([Parameter(Mandatory=$False)][string]$PlainPassword)
    if(!($PlainPassword)){$PlainPassword = ""}
    $SecurePassword = $PlainPassword | ConvertTo-SecureString -AsPlainText -Force
    $local_creds = New-Object System.Management.Automation.PSCredential ("dilbert", $SecurePassword)
    Write-Host -ForegroundColor DarkYellow "Secured Local Credentials"
    return $local_creds
}

#### VMWare Functions ####
#Creates New Vcenter VM Folder based on parameters Type and Name. Errors if folder already exists!
function New-VMFolder{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True,HelpMessage="NonPersistentSingleSession 'Workstation', VirtualDesktopServer 'RDSH', ApplicationServer 'AppSrv'")]
        [ValidateSet("Workstation","RDSH","AppSrv")][string] $VMFolder_Type,
        [Parameter(Mandatory=$False,HelpMessage="VM Folder Name")][string] $VMFolderName
    )
    if (!($UnitName)){Write-Error "Missing Unit Name"; break}
    if (!($NamingScheme)){Write-Error "Missing Naming Scheme"; break}
    if (!($VMFolderName)) {
        $VMFolderName = switch ($VMFolder_Type) {
            Workstation {"$UnitName-$NamingScheme"; break}
            RDSH {"RDSH-$NamingScheme"; break} 
            AppServer {"AppSrv-$NamingScheme"; break}
        }
    }
    #Check if vm folder exists
    if (@(Get-Folder $VMFolderName -ErrorAction SilentlyContinue).Count) {
        Write-Error "VM Folder Already exists!"    
    } 
    else {
        $ParentFolder = (Get-Folder $UnitName)
        Write-Host -ForegroundColor DarkYellow "VM Folder '$VMFolderName' does not exists, creating folder '$VMFolderName' under '$($ParentFolder)'"
        New-Folder -Name $VMFolderName -Location $ParentFolder | Out-Null
    }
    $VMFolder = (Get-Folder $VMFolderName).Name
    return $VMFolder
}

#Set vCenter VM Folder. Auto selects folder based on UnitName, or overload with VMFolder (FolderName).
function Set-VMFolder{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$false,HelpMessage="Enter Unit Name between 2 and 4 characters")][ValidateLength(2,4)][string] $UnitName,
        [Parameter(Mandatory=$false,HelpMessage="Enter vCenter VM Folder Name")][string]$VMFolder
    )
    if(!($VMFolder)){
        if(!($UnitName)){Write-Error "Missing Unit Name";break}
        $VMFolder = "$UnitName-Staff-Desktops"
    }
    $VMFolder = (Get-Folder $VMFolder)
    return $VMfolder
}

#Get vCenter VM Folder based on FolderName. No Longer Used.
function Set-VMFolder-Name{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([Parameter(Mandatory=$True,HelpMessage="Enter vCenter VM Folder Name")][string] $VMFolderName)
    $VMFolder = (Get-Folder $VMFolderName)
    return $VMfolder
}

#Set VM Name. Should match COmputerObject Name. SLA VMs will append .ad subdomain. 
function Set-VMName {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ([Parameter(Mandatory=$True,HelpMessage="VMName should match ComputerName")][string] $VMName)
    if(!($ComputerName)){Write-Error "Missing Computer Name"; break}
    if (!($VMName)){$VMName = $ComputerName}
    if (@(Get-VM $VMName -ErrorAction SilentlyContinue).Count) {
        Write-Error "VM '$($VMName)' already exists.";break
    } 
    else {Write-Host -ForegroundColor DarkYellow "VM will be named '$($VMName)'"}
    return $VMName
} 

#Creates vCenter VM Customization Specification to customize VM's Guest Windows OS
function New-VMcustomization {
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [Parameter(Mandatory=$True)][string] $UnitName,
        [Parameter(Mandatory=$True)][string] $VMName, 
        [Parameter(Mandatory=$True)][string] $ComputerName, 
        [Parameter(Mandatory=$False)][string] $Administrators
    )
    if(!($domain_creds)){Write-Error "Missing Domain Creds"; break}
    if(!($local_creds)){Write-Error "Missing Local Creds"; break}    
    $NewCS = $VMName

    if ((Get-OSCustomizationSpec -Name $NewCS -ErrorAction SilentlyContinue).Count) 
    {Write-Error "Customization '$($NewCS)' already exists!"} #Add Break Here for error
    
    else {   
        Write-Host -ForegroundColor DarkYellow "Customization'$($NewCS)' not found."
        Write-Host -ForegroundColor DarkYellow "Creating Customization Specification for: $($VMName)"

        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($local_creds.Password)
        $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  
        #Clone CustomSpec as NonPersistent. NonPersistent will auto delete
        #Get-OSCustomizationSpec -Name $SourceCS | New-OSCustomizationSpec -Name $NewCS -Type NonPersistent | Out-Null

        #new CustomSpec
        New-OSCustomizationSpec -Name $NewCS `
                                -Type NonPersistent `
                                -FullName "Georgia Institute of Technology" `
                                -OrgName $UnitName `
                                -NamingScheme "fixed" `
                                -NamingPrefix $ComputerName `
                                -Domain "DOMAIN.net" `
                                -DomainCredentials $domain_creds `
                                -AdminPassword $PlainPassword `
                                -TimeZone "035" `
                                -AutoLogonCount "2" `
                                -ChangeSid | Out-Null

        #Configure NIC
        $nic = Get-OSCustomizationSpec $NewCS | Get-OSCustomizationNicMapping
        Set-OSCustomizationNicMapping -OSCustomizationNicMapping $nic -IpMode UseDhcp | Out-Null
        #Set-OSCustomizationNicMapping -OSCustomizationNicMapping $nic -IpAddress "" -SubnetMask "" -DefaultGateway "" -Dns ""

        #CustomSpec properties
        $osspecArgs = @{
            GuiRunOnce = "cmd.exe /C Powershell.exe –ExecutionPolicy Bypass -file C:\installs\Expand-Partition.ps1",
            "cmd.exe /C NET USER $($local_creds.UserName) $PlainPassword /add",
            "cmd.exe /C NET LOCALGROUP Administrators $($local_creds.UserName) /add",
            "cmd.exe /C NET LOCALGROUP Administrators $Administrators /add",
            "net user administrator /active:no"
        }
        #set above values
        Set-OSCustomizationSpec $NewCS @osspecArgs | Out-Null 
    }
    return $NewCS                                      
}

#Created New vCenter VM based on multiple parameters.
function New-VirtualMachine {
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [Parameter(Mandatory=$True)][string] $VMName,
        [Parameter(Mandatory=$True)][string] $VMFolder, 
        [Parameter(Mandatory=$True)][string] $Template, 
        [Parameter(Mandatory=$False)][string] $Datastore,
        [Parameter(Mandatory=$False)][string] $VMHost
    )   
    if (@(Get-Folder $VMFolder -ErrorAction SilentlyContinue).Count) {
        Write-Host -ForegroundColor DarkYellow "VM Folder is '$($VMFolder)'." 
        try {
            Get-VM $VMName -ErrorAction Stop
            Write-Error "VM named '$($VMName)' already exists."; break
        } catch {
            Write-Host -ForegroundColor DarkYellow "VM named '$($VMName)' not found. Creating VM '$($VMName)' in folder '$($VMFolder)'."
            $NewVM = (New-VM -Name $VMName -Template $Template -VMHost $VMhost -Location $VMFolder -Datastore $Datastore)
            while (!(Get-VM $NewVM -ErrorAction SilentlyContinue)) {
                Write-Host -ForegroundColor DarkYellow "Waiting on VM creatation..." ; Start-Sleep -Seconds 45
                }
            Write-Host -ForegroundColor DarkYellow "$($NewVM.name) was successfully created."
            Start-Sleep -Seconds 1
        } 
    }
    $NewVM = (Get-Vm -Name $VMName)
    return $NewVM
}

#Customize VM Hardware and Apply CustomSpecification. No longer used. 
function Customize-VM {
    [CmdletBinding(SupportsShouldProcess=$true)]param($NewVM,$NewCS,$DiskSize,$NumCPU,$Memory,$Network)
    if(!(Get-OSCustomizationSpec $NewCS)){Write-Error "Missing Customization Spec"; break}

    #Customize Hardware
    Write-Host -ForegroundColor DarkYellow "Configure Virtual Hard Disk for '$($NewVM)'"
    Get-HardDisk $NewVM | Set-HardDisk -CapacityGB $DiskSize -Confirm:$false | Out-Null
    Start-Sleep -Seconds 1

    Write-Host -ForegroundColor DarkYellow "Configure Memory & CPU for '$($NewVM)'"
    Get-VM $NewVM | Set-VM -MemoryGB $Memory -NumCpu $NumCPU -Confirm:$false | Out-Null
    Start-Sleep -Seconds 1

    Write-Host -ForegroundColor DarkYellow "Configure Virtual Network Adapter for '$($NewVM)'"
    $vNIC = Get-VM $NewVM | Get-NetworkAdapter
    $VNiC | Set-NetworkAdapter -Portgroup $Network -Confirm:$false | Out-Null
    $vNIC | Set-NetworkAdapter -StartConnected:$True -Confirm:$false | Out-Null
    #Get-VM $NewVM | Get-NetworkAdapter | Set-NetworkAdapter -Portgroup $Network -StartConnected:$true -confirm:$false | Out-Null

    Start-Sleep -Seconds 1

    Write-Host -ForegroundColor DarkYellow "Apply notes to '$($NewVM)'"
    Set-VM -VM $NewVM -Notes "Created: $(get-date -Format yyyyMMdd) `nFrom Template: $($Template.name)" -confirm:$false | Out-Null
    Start-Sleep -Seconds 1

    #Customize OS
    Write-Host -ForegroundColor DarkYellow "Apply OS Customization to '$($NewVM)'"
    Set-VM -VM $NewVM -OSCustomizationSpec $NewCS -confirm:$false | Out-Null
    Start-Sleep -Seconds 1
             
    #Power On VM and Wait for CustomSpec to apply. VM join domain on successful deployment. 
    Write-Host -ForegroundColor DarkYellow "Starting VM '$($NewVM)'"
    Start-VM -VM $NewVM | Out-Null
    Write-Host -ForegroundColor DarkYellow "Waiting on VM to start..."
    Start-Sleep -Seconds 60
    $VM = (Get-VM $NewVM)
    while ($VM.Guest.HostName -notlike "$NewVM.DOMAIN.net") {
        $VM = (Get-VM $NewVM) 
        Write-Host -ForegroundColor DarkYellow "Waiting on VM to join domain..."
        Start-Sleep -Seconds 60 
    }
    Write-Host -ForegroundColor DarkYellow "$($VM.Guest.HostName) is online."
}

#Set VM's Notes based on source template.
function Set-VMNotes {
    [CmdletBinding(SupportsShouldProcess=$true)]param(
        [Parameter(Mandatory=$True)]$NewVM,$Template
    )

    Write-Host -ForegroundColor DarkYellow "Apply notes to '$($NewVM)'"
    Set-VM -VM $NewVM -Notes "Created: $(get-date -Format yyyyMMdd) `nFrom Template: $($Template.name)" -confirm:$false | Out-Null
    Start-Sleep -Seconds 1

}

#Set VM's virtual Hardware based on parameters. 
function Set-VMhardware {
    [CmdletBinding(SupportsShouldProcess=$true)]param(
        [Parameter(Mandatory=$True)]$NewVM,$DiskSize,$NumCPU,$Memory,$Network
    )
    #Customize Hardware
    Write-Host -ForegroundColor DarkYellow "Configure Virtual Hard Disk for '$($NewVM)'"
    $VMDisk = Get-HardDisk -VM $NewVM 
    if ($VMDisk.CapacityGB -ne $DiskSize) {Set-HardDisk -HardDisk $VMDisk -CapacityGB $DiskSize -Confirm:$false | Out-Null}
    Start-Sleep -Seconds 1

    Write-Host -ForegroundColor DarkYellow "Configure Memory & CPU for '$($NewVM)'"
    $VM = Get-VM $NewVM 
    if ($VM.MemoryGB -ne $Memory) {Set-VM -VM $NewVM -MemoryGB $Memory -Confirm:$false | Out-Null}
    if ($VM.NumCpu -ne $NumCPU) {Set-VM -VM $NewVM -NumCpu $NumCPU -Confirm:$false | Out-Null}

    Start-Sleep -Seconds 1

    Write-Host -ForegroundColor DarkYellow "Configure Virtual Network Adapter for '$($NewVM)'"
    $vNIC = Get-VM $NewVM | Get-NetworkAdapter
    if($vNIC.NetworkName -notlike $Network){Set-NetworkAdapter -NetworkAdapter $vNIC -Portgroup $Network -Confirm:$false | Out-Null}
    if ($vNIC.ConnectionState.StartConnected -notmatch "True") {Set-NetworkAdapter -NetworkAdapter $vNIC -StartConnected:$True -Confirm:$false | Out-Null}

    Start-Sleep -Seconds 1

}

#Sets VM Customization Specification to VM. Waits for VM to power up with proper FQDN. 
    #Consider Do/Until
    #https://devblogs.microsoft.com/scripting/powershell-looping-understanding-and-using-dountil/
    #Do {$VM = Get-VM $NewVM; $checks++}
    #until (($VM.Guest.HostName -like $NewVM.DOMAIN.net) -or ($checks -le 6))
function Set-VMCustomization{
    [CmdletBinding(SupportsShouldProcess=$true)]param(
        [Parameter(Mandatory=$True)]$NewVM,$NewCS
    )
    #Customize Windows OS
    Write-Host -ForegroundColor DarkYellow "Apply OS Customization to '$($NewVM)'"
    Set-VM -VM $NewVM -OSCustomizationSpec $NewCS -confirm:$false | Out-Null
    Start-Sleep -Seconds 1
             
    #Power On VM and Wait for CustomSpec to apply. VM join domain on successful deployment. 
    Write-Host -ForegroundColor DarkYellow "Starting VM '$($NewVM)'"
    Start-VM -VM $NewVM | Out-Null
    Write-Host -ForegroundColor DarkYellow "Waiting on VM to start..."
    Start-Sleep -Seconds 60
    $VM = (Get-VM $NewVM)
    while ($VM.Guest.HostName -notlike "$NewVM.DOMAIN.net") {
        $VM = (Get-VM $NewVM) 
        Write-Host -ForegroundColor DarkYellow "Waiting on VM to join domain..."
        Start-Sleep -Seconds 60 
    }
    Write-Host -ForegroundColor DarkYellow "$($VM.Guest.HostName) is online."

}

#Takes New Snapshot of VM. Powers off VM first. 
function New-Snap{
    [CmdletBinding(SupportsShouldProcess=$true)]param ($VM)
    if(!(Get-VM $VM)){Write-Error "Missing VM"}
    #verify VM exists & power off before snapshot
    $VM = (Get-VM $VM)
    if ($VM.ExtensionData.Runtime.PowerState -like "PoweredOff") {
        Write-Host "'$VM' is powered off, taking snapshot."
        New-Snapshot -VM $VM -Name 'Base' -Description "Created from Template: '$($Template)'" | Out-Null
        $Snapshot = Get-VM $VM | Get-Snapshot 
        Write-Host -ForegroundColor DarkYellow "$($NewVM) has a snapshot '$($Snapshot.Name)'"
        Start-Sleep -Seconds 2
    }
    if ($VM.ExtensionData.Runtime.PowerState -like "PoweredOn"){
        Write-Host -ForegroundColor DarkRed  "VM is Powered On, Shutting Down VM"
        Shutdown-VirtualMachine -VM $VM
        New-Snapshot -VM $VM -Name 'Base' -Description "Created from Template: '$($Template)'" | Out-Null
        $Snapshot = Get-VM $VM | Get-Snapshot 
        Write-Host -ForegroundColor DarkYellow "$($NewVM) has a snapshot '$($Snapshot.Name)'"
    }
}

#ShutDown VM Guest OS and reports when VM is off. 
function Shutdown-VirtualMachine {
    [CmdletBinding(SupportsShouldProcess=$true)]param ($VM)
    if(!($VM)){Write-Error "Missing New VM Name"; break}
    $VM = (Get-VM $VM)
    #verify VM exists & power off before snapshot
    if ($VM.ExtensionData.Runtime.PowerState -like "PoweredON") {
        $userinput = $(Write-Host "Do you want shutdown $($VM)? (y)es/(n)o: " -ForegroundColor Green -NoNewline; Read-Host)
        switch ($userinput) {
            y {
                #Shutdown VM and wait
                Write-Host -ForegroundColor DarkYellow "Shutdown VM: $($VM)"
                Shutdown-VMGuest $VM -confirm:$false | Out-Null
                while ($VM.ExtensionData.Runtime.PowerState -like "PoweredOn") {
                    $VM = Get-VM $VM
                    Write-Host -ForegroundColor DarkYellow "Waiting on VM to shutdown..."
                    Start-Sleep -Seconds 30 
                } #end While
            } 
            default {break}
        } #end switch
    } #end if
    if ($VM.ExtensionData.Runtime.PowerState -like "PoweredOff") {
        Write-Host -ForegroundColor DarkYellow "$($VM) is $($VM.ExtensionData.Runtime.PowerState)"
        }
}

#Start VM and report when Online. 
function Start-VirtualMachine {
    [CmdletBinding(SupportsShouldProcess=$true)]param ($VM)
    if(!($VM)){Write-Error "Missing New VM Name"; break}
    $VM = (Get-VM $VM)
    if ($VM.ExtensionData.Runtime.PowerState -like "PoweredOff"){
        Write-Host -ForegroundColor DarkYellow "Starting VM: $($VM)"
        Start-VM -VM $VM | Out-Null
        while ($VM.Guest.State -notlike "Running"){
            $VM = Get-VM $VM
            Write-Host -ForegroundColor DarkYellow "Waiting on VM to start..."
            Start-Sleep -Seconds 30
        }
    } 
    else {Write-Host -ForegroundColor DarkRed "VM already powered on"}
    Write-Host -ForegroundColor DarkYellow "'$VM' is $($VM.Guest.State)."
}

#Get VM Tools Status. Reports if out of date, requests confirmation to update tools.
function Update-VMwareTools {
    [CmdletBinding(SupportsShouldProcess=$true)]param ($VM)
    if(!($VM)){Write-Error "Missing VM Name"; break}
    $VM = (Get-Vm $VM)
    if ($VM.ExtensionData.Guest.ToolsStatus -like "toolsOld") {
        Write-Host -ForegroundColor DarkRed "VMware Tools need updating!"
        $userinput = $(Write-Host "Do you want to Update VMware Tools on $($NewVM) (y)es/(n)o: " -ForegroundColor Green -NoNewline; Read-Host) 
        switch ($userinput) {
            y {
                #Update Vmware Tools and wait
                Write-Host -ForegroundColor DarkYellow "Updating VMware Tools"
                Get-VM $VM | Update-Tools
                while ($VM.ExtensionData.Guest.ToolsStatus -notlike "toolsOk")
                {
                    $VM = Get-VM $VM 
                    Write-Host -ForegroundColor DarkYellow "Waiting on VMware Tools..."
                    Write-Host -ForegroundColor DarkYellow "'$($NewVM)' tools are $($VM.ExtensionData.Guest.ToolsStatus)"
                    Start-Sleep -Seconds 60
                }
                Write-Host -ForegroundColor DarkYellow "'$($NewVM)' tools are $($VM.ExtensionData.Guest.ToolsStatus)"}
            default {Write-Host -ForegroundColor DarkYellow "VMware Tools Not Updated"}
        }#End Swich
    }#End If
    else {Write-Host -ForegroundColor DarkYellow "'$($NewVM)' VMWare Tools are up to date."}
}

#Stop Transcript and notify user that job has completed. 
function Completed {
    Write-Host -ForegroundColor DarkYellow "Program has ended."; Stop-Transcript
}

########--------########--------########--------########--------
#Combine above functions for routine tasks. 
#Create New Citrix Image, Fslogix Folder, GPO, OU, Computer Object, New VM, Join Domain.
function New-VDI_IMG {
[CmdletBinding(SupportsShouldProcess=$True)]
    Param(
        [Parameter(Mandatory=$True)][ValidateSet("VDI_DC1","VDI_DC2")][string] $Datacenter,
        [Parameter(Mandatory=$True,HelpMessage="Enter Unit Name between 2 and 4 characters")][ValidateLength(2,4)][string] $UnitName,
        [Parameter(Mandatory=$True,HelpMessage="Enter Year or Secondary Descriptor between 2 and 7 characters(Example: 2022)")][ValidateLength(2,7)][string] $NamingScheme,
        [Parameter(Mandatory=$True,HelpMessage="Enter Disk Size in GB (Example: 128)")][ValidateRange(30,1024)][int] $DiskSize,
        [Parameter(Mandatory=$True,HelpMessage="Enter Memory Size in GB (Example: 8)")][ValidateRange(1,32)][int] $Memory,
        [Parameter(Mandatory=$True,HelpMessage="Enter CPU count (Example: 2)")][ValidateSet('2','4')][int] $NumCPU,
        [Parameter(Mandatory=$False,HelpMessage="Enter vCenter Template Name")][string] $Template,
        [Parameter(Mandatory=$False,HelpMessage="Enter vCenter Cluster Name")][string] $Cluster,
        [Parameter(Mandatory=$False,HelpMessage="Enter vCenter Network Name")][string] $Network,
        [Parameter(Mandatory=$False,HelpMessage="Enter vCenter Folder Name")][string] $VMFolder,
        [Parameter(Mandatory=$False,HelpMessage="Enter AD Computer Name")][string] $ComputerName,
        [Parameter(Mandatory=$False,HelpMessage="Enter Delegated Admin Name")][string] $Administrators
    )

    Start-Transcript C:\Temp\New-VDI-Resources_$(get-date -format yyyyMMdd-hh:mm).txt

    $DCVars = Set-DCVariables -DataCenter $Datacenter #Defines multiple environmental variables via PS Object $DCVars
    $DataStore = $DCVars.datastore
    $UserProfileShare = $DCVars.NetworkShare 
    $vCenter = $DCVars.vcenter
    Connect-Vcenter -Datacenter $vCenter #validates one of two vcenters to connect to

    #Set VM Hardware Config
    $DiskSize = Set-DiskSize -DiskSize $DiskSize #define disk size. use variable $disksize to pass through out other functions
    $Memory = Set-MemorySize -Memory $Memory #define RAM size. use variable $memory
    $NumCPU = Set-CPU -NumCPU $NumCPU #define processor count. use variable $NumCPU

    #Each function can use a parameter to bypass user prompt to select from available resources. 
    #Example: $Template = Select-Template -Template <TemplateName>
    if(!($Template)) {$Template = Select-Template} #prompts user to select from available templates, stores selection in $template. 
    if(!($Cluster)) {$Cluster = Select-Cluster} #prompts user to select from available compute clusters, stores selection in $cluster
    if(!($Network)) {$Network = Select-Network} #prompts user to select from available networks, stores selection in $network
    $VMHost = Select-VMHost #selects first VM Host in a cluster

    #Each function can use a parameter to overload variables (example: Set-Administrators -Administrators xen-admins)
    if(!($UnitName)) {$UnitName = Set-UnitName} #UnitName for Naming Schemes, Organization, and Delegated Admins
    if(!($NamingScheme)) {$NamingScheme = Set-NamingScheme} #Naming Scheme is often defined as year. 
    if(!($Administrators)) {$Administrators = Set-Administrators} #Dependent on UnitName, validates AD Group selected as delegated administrators.

    $FolderPath = "$UserProfileShare\$UnitName-$NamingScheme"
    if(!(Get-Item $Folderpath)){
        $FolderPath = New-FSlogixFolder -UserProfileShare $UserProfileShare #Sets UNC Path for New FSlogix Folder, Use $DCVars.NetworkPath. Dependent on Naming Scheme
        Set-FolderPermission -FolderPath $FolderPath -Administrators $Administrators #Sets FSLogix Folder ACLs, dependent on $FolderPath and $Administrators
    }

    $OU = New-OU -OU_Type Workstation #Created New OU, Mandatory Parameter Requires Workstation,RDSH,AppV. Dependent on $UnitName & $NamingScheme
    $GPOName = New-FSLogixGPO -SearchRoaming SingleSession -UnitName $UnitName -NamingScheme $NamingScheme #Creates New GPO, Mandatory Parameter Requires Single/Multi Session. Dependent on $UnitName & $NamingScheme
    Set-FslogixDelegatedAdmins -Gpo $GPOName -Administrators $Administrators #Sets Delegated Admins
    Set-FSLogixFolderPath -GpoName $GPOName -FolderPath $FolderPath #Sets GPO Registry Values, Dependent on $GPOName and $FolderPath
    Set-GPLink -GpoName $GPOName -OU $OU #Links above GPO to above OU

    if(!($ComputerName)) {$ComputerName = Set-ComputerName} #sets computer name. Dependent on $UnitName $NamingScheme (overload with -ComputerName *)
    $ComputerName = New-Computer -ComputerName $ComputerName -OU $OU #Creates AD Computer Object
    Set-IMG -ComputerName $ComputerName #Sets $ComputerName as a Golden Image.

    $domain_creds = Set-DomainJoinCreds #Prompts user for creds, can use ServiceAccount here. 
    $local_creds = Set-LocalAdminCreds #Securely stores local password

    $VMName = Set-VMName -VMName $ComputerName #Sets VM Name. Dependent on $ComputerName
    $NewCS = New-VMcustomization -VMName $VMName -UnitName $UnitName -ComputerName $ComputerName -Administrators $Administrators #Creates VM CustomizationSpecification.Dependent on Domain and Local Creds
    if(!($VMFolder)) {$VMFolder = New-VMFolder -VMFolder_Type Workstation} #Creates new VM Folder. Dependent on $UnitName and $NamingScheme
    $NewVM = New-VirtualMachine -VMName $VMName -VMFolder $VMFolder -Template $Template -VMHost $VMHost -Datastore $Datastore #Creates new VM. Dependent on $UnitName and $NamingScheme

    #OLD Function Split into sub-functions
    #Customize-VM -NewVM $NewVM -NewCS $NewCS -DiskSize $DiskSize -NumCPU $NumCPU -Memory $Memory -Network $Network  
    Set-VMNotes -NewVM $NewVM -Template $Template #Create Notes on new VM referencing the Template_Name
    Set-VMhardware -NewVM $NewVM -DiskSize $DiskSize -NumCPU $NumCPU -Memory $Memory -Network $Network #Customize VM's hardware. 
    Set-VMCustomization -NewVM $NewVM -NewCS $NewCS #Apply VM Customization, Power On VM, wait until machine joins domain. 

    New-Snap -VM $NewVM #Creates Snapshot, powers off the VM first.

    Start-VirtualMachine -VM $NewVM
    
    Disconnect-VIServer -Server $vCenter -Confirm:$false 
     
    Completed
}

#Create New Persistent Citrix VM, Computer Object, New VM, Join Domain.
function New-PersistentDesktop {
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [Parameter(Mandatory=$True)][ValidateSet("VDI_DC1","VDI_DC2")][string] $Datacenter,
        [Parameter(Mandatory=$True,HelpMessage="Enter Unit Name")][ValidateLength(2,4)][string] $UnitName,
        [Parameter(Mandatory=$True,HelpMessage="Enter Computer Name between 4 and 15 characters(Example: user_name-win10)")][ValidateLength(4,15)][string] $ComputerName,
        [Parameter(Mandatory=$True,HelpMessage="Enter Disk Size in GB (Example: 128)")][ValidateRange(30,1024)][int] $DiskSize,
        [Parameter(Mandatory=$True,HelpMessage="Enter Memory Size in GB (Example: 8)")][ValidateRange(1,32)][int] $Memory,
        [Parameter(Mandatory=$True,HelpMessage="Enter CPU count (Example: 2)")][ValidateSet('2','4')][int] $NumCPU,
        [Parameter(Mandatory=$False,HelpMessage="Enter vCenter Template Name")][string] $Template,
        [Parameter(Mandatory=$False,HelpMessage="Enter vCenter Cluster Name")][string] $Cluster,
        [Parameter(Mandatory=$False,HelpMessage="Enter vCenter Network Name")][string] $Network,
        [Parameter(Mandatory=$False,HelpMessage="Enter vCenter Folder Name")][string] $VMFolder,
        [Parameter(Mandatory=$False,HelpMessage="Enter Delegated Admin Name")][string] $Administrators
    )

    Start-Transcript C:\Temp\New-VDI-Resources_$(get-date -format yyyyMMdd-hh:mm).txt

    $DCVars = Set-DCVariables -DataCenter $Datacenter #Defines multiple environmental variables via PS Object $DCVars
    $DataStore = $DCVars.datastore
    $vCenter = $DCVars.vcenter
    Connect-Vcenter -Datacenter $vCenter #validates one of two vcenters to connect to
    #Set VM Hardware Config
    $DiskSize = Set-DiskSize -DiskSize $DiskSize #define disk size. use variable $disksize to pass through out other functions
    $Memory = Set-MemorySize -Memory $Memory #define RAM size. use variable $memory
    $NumCPU = Set-CPU -NumCPU $NumCPU #define processor count. use variable $NumCPU

    #Each function can use a parameter to bypass user prompt to select from available resources. 
    #Example: $Template = Select-Template -Template <TemplateName>
    if(!($Template)) {$Template = Select-Template} #prompts user to select from available templates, stores selection in $template. 
    if(!($Cluster)) {$Cluster = Select-Cluster} #prompts user to select from available compute clusters, stores selection in $cluster
    if(!($Network)) {$Network = Select-Network} #prompts user to select from available networks, stores selection in $network
    $VMHost = Select-VMHost #selects first VM Host in a cluster

    #Each function can use a parameter to overload variables (example: Set-Administrators -Administrators xen-admins)
    if(!($UnitName)) {$UnitName = Set-UnitName} #UnitName for Naming Schemes, Organization, and Delegated Admins
    if(!($Administrators)) {$Administrators = Set-Administrators} #Dependent on UnitName, validates AD Group selected as delegated administrators.

    $local_creds = Set-LocalAdminCreds
    $domain_creds = Set-DomainJoinCreds

    $OU = Set-OU -UnitName $UnitName
    if(!($ComputerName)) {$ComputerName = Set-ComputerName} #sets computer name. Dependent on $UnitName $NamingScheme (overload with -ComputerName *)
    $ComputerName = New-Computer -ComputerName $ComputerName -OU $OU #Creates AD Computer Object

    if(!($VMFolder)) {$VMfolder = Set-VMFolder -UnitName $UnitName}
    $VMName = Set-VMName -VMName $ComputerName #Sets VM Name. Dependent on $ComputerName
    $NewCS = New-VMcustomization -VMName $VMName -UnitName $UnitName -ComputerName $ComputerName -Administrators $Administrators #Creates VM CustomizationSpecification.Dependent on Domain and Local Creds
    $NewVM = New-VirtualMachine -VMName $VMName -VMFolder $VMFolder -Template $Template -VMHost $VMHost -Datastore $Datastore #Creates new VM. Dependent on $UnitName and $NamingScheme
    
    Set-VMNotes -NewVM $NewVM -Template $Template
    Set-VMhardware -NewVM $NewVM -DiskSize $DiskSize -NumCPU $NumCPU -Memory $Memory -Network $Network
    Set-VMCustomization -NewVM $NewVM -NewCS $NewCS

    Update-VMwareTools -VM $NewVM

    New-Snap -VM $NewVM #Creates Snapshot, powers off the VM first.

    Start-VirtualMachine -VM $NewVM
    
    Disconnect-VIServer -Server $vCenter -Confirm:$false 
     
    Completed

}

#Create New Citrix RDSH Image, Fslogix Folder, GPO, OU, Computer Object, New VM, Join Domain.
function New-RDSH_IMG {
[CmdletBinding(SupportsShouldProcess=$True)]
    Param(
        [Parameter(Mandatory=$True)][ValidateSet("VDI_DC1","VDI_DC2")][string] $Datacenter,
        [Parameter(Mandatory=$True,HelpMessage="Enter Unit Name between 2 and 4 characters")][ValidateLength(2,4)][string] $UnitName,
        [Parameter(Mandatory=$True,HelpMessage="Enter Year or Secondary Descriptor between 2 and 7 characters(Example: 2022)")][ValidateLength(2,7)][string] $NamingScheme,
        [Parameter(Mandatory=$True,HelpMessage="Enter Disk Size in GB (Example: 128)")][ValidateRange(30,1024)][int] $DiskSize,
        [Parameter(Mandatory=$True,HelpMessage="Enter Memory Size in GB (Example: 8)")][ValidateRange(1,32)][int] $Memory,
        [Parameter(Mandatory=$True,HelpMessage="Enter CPU count (Example: 2)")][ValidateSet('2','4')][int] $NumCPU,
        [Parameter(Mandatory=$False,HelpMessage="Enter vCenter Template Name")][string] $Template,
        [Parameter(Mandatory=$False,HelpMessage="Enter vCenter Cluster Name")][string] $Cluster,
        [Parameter(Mandatory=$False,HelpMessage="Enter vCenter Network Name")][string] $Network,
        [Parameter(Mandatory=$False,HelpMessage="Enter vCenter Folder Name")][string] $VMFolder,
        [Parameter(Mandatory=$False,HelpMessage="Enter AD Computer Name")][string] $ComputerName,
        [Parameter(Mandatory=$False,HelpMessage="Enter Delegated Admin Name")][string] $Administrators
    )

    Start-Transcript C:\Temp\New-RDSH-Resources_$(get-date -format yyyyMMdd-hh:mm).txt

    $DCVars = Set-DCVariables -DataCenter $Datacenter #Defines multiple environmental variables via PS Object $DCVars
    $DataStore = $DCVars.datastore
    $UserProfileShare = $DCVars.NetworkShare 
    $vCenter = $DCVars.vcenter
    Connect-Vcenter -Datacenter $vCenter #validates one of two vcenters to connect to

    #Set VM Hardware Config
    $DiskSize = Set-DiskSize -DiskSize $DiskSize #define disk size. use variable $disksize to pass through out other functions
    $Memory = Set-MemorySize -Memory $Memory #define RAM size. use variable $memory
    $NumCPU = Set-CPU -NumCPU $NumCPU #define processor count. use variable $NumCPU

    #Each function can use a parameter to bypass user prompt to select from available resources. 
    #Example: $Template = Select-Template -Template <TemplateName>
    if(!($Template)) {$Template = Select-Template} #prompts user to select from available templates, stores selection in $template. 
    if(!($Cluster)) {$Cluster = Select-Cluster} #prompts user to select from available compute clusters, stores selection in $cluster
    if(!($Network)) {$Network = Select-Network} #prompts user to select from available networks, stores selection in $network
    $VMHost = Select-VMHost #selects first VM Host in a cluster

    #Each function can use a parameter to overload variables (example: Set-Administrators -Administrators xen-admins)
    if(!($UnitName)) {$UnitName = Set-UnitName} #UnitName for Naming Schemes, Organization, and Delegated Admins
    if(!($NamingScheme)) {$NamingScheme = Set-NamingScheme} #Naming Scheme is often defined as year. 
    if(!($Administrators)) {$Administrators = Set-Administrators} #Dependent on UnitName, validates AD Group selected as delegated administrators.

    if(!(Get-Item "$UserProfileShare\$UnitName-$NamingScheme")){
        $FolderPath = New-FSlogixFolder -UserProfileShare $UserProfileShare #Sets UNC Path for New FSlogix Folder, Use $DCVars.NetworkPath. Dependent on Naming Scheme
        Set-FolderPermission -FolderPath $FolderPath -Administrators $Administrators #Sets FSLogix Folder ACLs, dependent on $FolderPath and $Administrators
    }

    $OU = New-OU -OU_Type RDSH #Created New OU, Mandatory Parameter Requires Workstation,RDSH,AppV. Dependent on $UnitName & $NamingScheme
    $GPOName = New-FSLogixGPO -SearchRoaming MultiSession -UnitName $UnitName -NamingScheme $NamingScheme #Creates New GPO, Mandatory Parameter Requires Single/Multi Session. Dependent on $UnitName & $NamingScheme
    Set-FslogixDelegatedAdmins -Gpo $GPOName -Administrators $Administrators
    Set-FSLogixFolderPath -GpoName $GPOName -FolderPath $FolderPath #Sets GPO Registry Values, Dependent on $GPOName and $FolderPath
    Set-GPLink -GpoName $GPOName -OU $OU #Links above GPO to above OU

    if(!($ComputerName)) {$ComputerName = Set-ComputerName} #sets computer name. Dependent on $UnitName $NamingScheme (overload with -ComputerName *)
    $ComputerName = New-Computer -ComputerName $ComputerName -OU $OU #Creates AD Computer Object
    Set-IMG -ComputerName $ComputerName #Sets $ComputerName as a Golden Image.

    $domain_creds = Set-DomainJoinCreds #Prompts user for creds, can use ServiceAccount here. 
    $local_creds = Set-LocalAdminCreds #Securely stores local password

    $VMName = Set-VMName -VMName $ComputerName #Sets VM Name. Dependent on $ComputerName
    $NewCS = New-VMcustomization -VMName $VMName -UnitName $UnitName -ComputerName $ComputerName -Administrators $Administrators #Creates VM CustomizationSpecification.Dependent on Domain and Local Creds
    $VMFolder = New-VMFolder -VMFolder_Type RDSH #Creates new VM Folder. Dependent on $UnitName and $NamingScheme Overload with param -VMFolderName 
    $NewVM = New-VirtualMachine -VMName $VMName -VMFolder $VMFolder -Template $Template -VMHost $VMHost -Datastore $Datastore #Creates new VM. Dependent on $UnitName and $NamingScheme

    Set-VMNotes -NewVM $NewVM -Template $Template
    Set-VMhardware -NewVM $NewVM -DiskSize $DiskSize -NumCPU $NumCPU -Memory $Memory -Network $Network
    Set-VMCustomization -NewVM $NewVM -NewCS $NewCS #Power on and Join Domain

    New-Snap -VM $NewVM

    Start-VirtualMachine -VM $NewVM
    
    Disconnect-VIServer -Server $vCenter -Confirm:$false 
     
    Completed
}



#Create New SLA VM, Computer Object, New VM, Join Domain.
#Can be used in-lieu of CloudBolt
function New-SLA_VM {
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [Parameter(Mandatory=$True)][ValidateSet("DC2","DC1")][string] $Datacenter,
        [Parameter(Mandatory=$True)][string] $UnitName,
        [Parameter(Mandatory=$True,HelpMessage="Enter Computer Name between 4 and 15 characters(Example: user_name-win10)")][ValidateLength(4,15)][string] $ComputerName,
        [Parameter(Mandatory=$True,HelpMessage="Enter Disk Size in GB (Example: 128)")][ValidateRange(30,1024)][int] $DiskSize,
        [Parameter(Mandatory=$True,HelpMessage="Enter Memory Size in GB (Example: 8)")][ValidateRange(1,32)][int] $Memory,
        [Parameter(Mandatory=$True,HelpMessage="Enter CPU count (Example: 2)")][ValidateSet('2','4')][int] $NumCPU,
        [Parameter(Mandatory=$False,HelpMessage="Enter vCenter Template Name")][string] $Template,
        [Parameter(Mandatory=$False,HelpMessage="Enter vCenter Cluster Name")][string] $Cluster,
        [Parameter(Mandatory=$False,HelpMessage="Enter vCenter Network Name")][string] $Network,
        [Parameter(Mandatory=$False,HelpMessage="Enter vCenter Folder Name")][string] $VMFolder,
        [Parameter(Mandatory=$False,HelpMessage="Enter Delegated Admin Name")][string] $Administrators
    )

    Start-Transcript C:\Temp\New-SLA-Resources_$(get-date -format yyyyMMdd-hh:mm).txt

    $DCVars = Set-DCVariables -DataCenter $Datacenter #Defines multiple environmental variables via PS Object $DCVars
    $DataStore = $DCVars.datastore
    $vCenter = $DCVars.vcenter
    Connect-Vcenter -Datacenter $vCenter #validates one of two vcenters to connect to

    #Set VM Hardware Config
    $DiskSize = Set-DiskSize -DiskSize $DiskSize #define disk size. use variable $disksize to pass through out other functions
    $Memory = Set-MemorySize -Memory $Memory #define RAM size. use variable $memory
    $NumCPU = Set-CPU -NumCPU $NumCPU #define processor count. use variable $NumCPU

    #Each function can use a parameter to bypass user prompt to select from available resources. 
    #Example: $Template = Select-Template -Template <TemplateName>
    if(!($Template)) {$Template = Select-Template} #prompts user to select from available templates, stores selection in $template. 
    if(!($Cluster)) {$Cluster = Select-Cluster} #prompts user to select from available compute clusters, stores selection in $cluster
    if(!($Network)) {$Network = Select-Network} #prompts user to select from available networks, stores selection in $network
    $VMHost = Select-VMHost #selects first VM Host in a cluster

    $local_creds = Set-LocalAdminCreds
    $domain_creds = Set-DomainJoinCreds
    if(!($Administrators)) {$Administrators = Set-Administrators -Administrators "$UnitName-OUAdmins" } #Dependent on UnitName, validates AD Group selected as delegated administrators.
    
    $OU = (Get-ADOrganizationalUnit -Identity "OU=Servers,DC=DOMAIN,DC=NET")
    New-Computer -ComputerName $ComputerName -OU $OU #Creates AD Computer Object

    if(!($VMFolder)) {$VMfolder = Set-VMFolder -VMFolder $UnitName} #Hardcoded to AI VM Folder
    $VMName = Set-VMName -VMName "$($ComputerName).ad" #Sets VM Name. Dependent on $ComputerName
    $NewCS = New-VMcustomization -VMName $VMName -UnitName $UnitName -ComputerName $ComputerName -Administrators $Administrators #Creates VM CustomizationSpecification.Dependent on Domain and Local Creds
    $NewVM = New-VirtualMachine -VMName $VMName -VMFolder $VMFolder -Template $Template -VMHost $VMHost -Datastore $Datastore #Creates new VM. Dependent on $UnitName and $NamingScheme
    
    Set-VMNotes -NewVM $NewVM -Template $Template
    Set-VMhardware -NewVM $NewVM -DiskSize $DiskSize -NumCPU $NumCPU -Memory $Memory -Network $Network
    Set-VMCustomization -NewVM $NewVM -NewCS $NewCS

    Start-VirtualMachine -VM $NewVM

    Update-VMwareTools -VM $NewVM
    
    Disconnect-VIServer -Server $vCenter -Confirm:$false 
     
    Completed

}

########END########
