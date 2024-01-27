<#
##How To Setup AZ Files Hybrid to Manage Azure Storage Accounts. 
##Must be connected to VPN or on network to run this script
##Download AZFilesHybrid, and Expand zip.
$WorkingDir = "C:\Temp"
cd $WorkingDir
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$Output = "$WorkingDir\AZfiles.zip"
Invoke-WebRequest -Uri "https://github.com/Azure-Samples/azure-files-samples/archive/refs/heads/master.zip" -OutFile $Output
Expand-Archive $Output
cd "$WorkingDir\AZfiles\azure-files-samples-master"
##Copy AZ FileHybrid module to powershell path.
##$Env:PSModulePath
Copy-Item -Path ".\AzFilesHybrid" -Destination "C:\Program Files\WindowsPowerShell\Modules" -Recurse -Force

##Install PreRequirements. The following Powershell Modules are used in the AZFileHybrid module.
Install-Module AZ -Force -confirm:$false 
Install-Module AZ.Storage -Force -confirm:$false
Install-Module AzureAD -AllowClobber -Force -Confirm:$false  
Import-Module AzFilesHybrid -Force
$AD = Get-WindowsCapability -Name "Rsat.ActiveDirectory.DS-LDS.Tools*" -Online 
Add-WindowsCapability -Online -Name $AD.Name
##If fails with Error code 0x800f0954 (missing sources)
##workaround to bypass WSUS. 
#Regedit HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU UseWUServer = 0
Import-Module ActiveDirectory -confirm:$false
#>
    
connect-azaccount -AccountId UPN@DOMAIN.COM
connect-azuread -AccountId UPN@DOMAIN.COM

##List Azure Subscriptions
#Get-AzSubscription

##NonProd
$subscription = Select-AzSubscription -SubscriptionName "NonProd_Subscription_Name"
[ValidateLength (3,15)][string]$account= "NonProd_Storage_Name"
$ResourceGroupName= "rg-avd-nonprod-mgmt"
$OUPath= "OU=Management,OU=NonProdProd,OU=AVD,OU=Workstations,DC=DOMAIN,DC=COM"

##Prod
$subscription = Select-AzSubscription -SubscriptionName "Prod_Subscription_Name"
[ValidateLength (3,15)][string]$account= "Prod_Storage_Name"
$ResourceGroupName= "rg-avd-prod-mgmt"
$OUPath= "OU=Management,OU=Prod,OU=AVD,OU=Workstations,DC=DOMAIN,DC=COM"

##Deploy AZ Storage in ARM Template
<#
$Template= ".\ARM-Templates\AzureFiles-ARMtemplate.json"
Write-Output "Deploy ARM Template $(Get-Date)"
New-AzResourceGroupDeployment `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile $Template `
    -storageAccountName $account `
    -userEmail "User.Name@domain.com"
Write-Output "ARM Deployment completed $(Get-Date)"
#>

#!!DELETE Storage Account!!
#Remove-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $account -Force

#Configure Share Level Permissions
$StorageAccount = (Get-AzStorageAccount  -ResourceGroupName $ResourceGroupName -AccountName $account)
$StorageAccountScope = $($storageaccount.Id)
#USERS Contributors = Modify
$Contributors = (Get-AzADGroup -DisplayName "VDI_AVD_Users")
$ContributorRole = (Get-AzRoleDefinition "Storage File Data SMB Share Contributor")
New-AzRoleAssignment -ObjectId $($Contributors.Id) -RoleDefinitionName $($ContributorRole.Name) -Scope $StorageAccountScope
#ADMINS Elevated = Owner/Full Control
$Elevated = (Get-AzADGroup -DisplayName "VDI_AVD_Admins")
$ElevatedRole = (Get-AzRoleDefinition "Storage File Data SMB Share Elevated Contributor")
New-AzRoleAssignment -ObjectId $($Elevated.Id) -RoleDefinitionName $($ElevatedRole.Name) -Scope $StorageAccountScope

#Join-AzStorageAccount -ResourceGroupName $ResourceGroupName -StorageAccountName $account -OrganizationalUnitDistinguishedName $OUPath 
Join-AzStorageaccountForAuth -ResourceGroupName $ResourceGroupName -Name $account -DomainAccountType "ComputerAccount" -OrganizationalUnitDistinguishedName $OUPath  -OverwriteExistingADObject

#Upgrade Kerberos to AES256
Update-AzStorageAccountAuthForAES256 -ResourceGroupName $ResourceGroupName -StorageAccountName $Account -Confirm:$false

<# Advanced Troubleshooting
# Get the target storage account
$storageaccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $account
# List the directory service of the selected service account
$storageAccount.AzureFilesIdentityBasedAuth.DirectoryServiceOptions
# List the directory domain information if the storage account has enabled AD DS authentication for file shares
$storageAccount.AzureFilesIdentityBasedAuth.ActiveDirectoryProperties
#Configure Share Level Permissions for all accounts under tenant.
#Set the default permission of your choice. "None|StorageFileDataSmbShareContributor|StorageFileDataSmbShareReader|StorageFileDataSmbShareElevatedContributor"
$defaultPermission = "None"
$Storageaccount = Set-AzStorageAccount -ResourceGroupName $ResourceGroupName -AccountName $account -DefaultSharePermission $defaultPermission
$Storageaccount.AzureFilesIdentityBasedAuth
#Get StorageAccount Context
$context = New-AzStorageContext -StorageAccountName $account -StorageAccountKey $($keys[0].Value)
#Search for FileShares on StorageContext
$fileshare = (Get-AZStorageShare -Context $context)
#define the scope of the fileshare
$FileShareScope = "$($storageaccount.Id)/fileServices/default/fileshares/$($fileshare.Name)"
#>

#IF AD Authentication is broken, run this. 
#Update Kerberos Password Kerb1 & kerb2. There is a two stage update of the kerb tokens.
Update-AzStorageAccountADObjectPassword -ResourceGroupName $ResourceGroupName -StorageAccountName $account -Confirm:$false -RotateToKerbKey kerb2 #kerb2 

##Verify ad is connected, via az Portal, and/or the AD Object.
#AzPortal, go to Storage Account, and then Locate FileShares in the Left Pane. The AD status should be listed in this screen. 
$keys = Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -AccountName $account
$context = New-AzStorageContext -StorageAccountName $account -StorageAccountKey $($keys[0].Value)
$fileshare = (Get-AZStorageShare -Context $context).Name
Debug-AzStorageAccountAuth -StorageAccountName $account -ResourceGroupName $ResourceGroupName -Verbose -UserName $($env:USERNAME) -Domain $($env:USERDOMAIN) -FilePath "\\$($account).file.core.windows.net\$($fileshare)"

#Mount Network Drive to Set File/Folder Level ACLs
$user = "Azure\$account"
$keys = Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -AccountName $account
$pwd = ConvertTo-SecureString -String $($keys[0].Value) -AsPlainText -Force
$creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $pwd
# Mount the drive with StorageAccount
New-PSDrive -Name M -PSProvider FileSystem -Root "\\$($account).file.core.windows.net\$($fileshare)" -Persist -Credential $creds

# Mount the drive with SessionAccount
New-PSDrive -Name P -PSProvider FileSystem -Root "\\$($account).file.core.windows.net\$($fileshare)" -Persist

<#
  Set FSlogix Folder Permission
  Security permissions: 
 -Admins - Full 
 -SYSTEM - Full 
 -CREATOR OWNER - Full - Subdirs/files only 
 -Domain Users - Modify - This folder only 
#>

#Set Delegated Administrators
#$Administrators = "VDI_AVD_Admins"
#$Administrators = "DOMAIN\Admin_Group_Name"
#$Users = "DOMAIN\User_Group_Name"

#Creates New Directory
function New-FSlogixFolder {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True,HelpMessage="UNC Path to Network Share for User Profiles")]
        [string] $ProfileShareName = "M:",
        [Parameter(Mandatory=$True,HelpMessage="New Folder Name")]
        [string] $FolderName = "trest"
    )
    if (!(Test-Path $ProfileShareName)){Write-Error "Missing User Profile Share";break}
    if (@(Test-Path $ProfileShareName\$FolderName)){Write-Information "Folder already exists!";return}
    if (!(Test-Path $ProfileShareName\$FolderName)) {    
        Write-Output "Folder '$($FolderName)' was not found."
        Write-Output "Creating folder' $($FolderName)'."
        New-Item -Path $ProfileShareName\$FolderName -ItemType Directory | Out-Null   
    } 
    return "$ProfileShareName\$FolderName"
}

#Sets ACLs on FSlogix Directory
function Set-FolderPermission {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter()][string] $FolderPath,
        [Parameter()][string] $Administrators = $Administrators,
        [Parameter()][string] $Users = $Users
    )
    #$FolderPath = $Folder
    if(!($Administrators)){Write-Error "Missing Administrators";break}
    if(!($FolderPath)){Write-Error "Missing Folder Path";break}
    
    #Disable Folder Inheritance
    Write-Output "Remove Inheritance on '$($FolderPath)"
    icacls $FolderPath /inheritance:d

    #Remove Permission for Everyone
    Write-Output "Remove 'NT Authority\Everyone' from '$($FolderPath)'"
    icacls $FolderPath /remove 'NT Authority\Everyone' /t /c

    #Remove Permission for AuthenticatedUsers
    Write-Output "Remove 'Authenticated Users' from '$($FolderPath)'"
    icacls $FolderPath /remove 'Authenticated Users' /t /c

    #Remove Permission for Users
    Write-Output "Remove 'BuiltIn\Users' from '$($FolderPath)'"
    icacls $FolderPath /remove 'Builtin\Users' /t /c

    #Set ACLs
    #https://docs.microsoft.com/en-us/fslogix/fslogix-storage-config-ht
    $objACL = Get-ACL -Path $FolderPath
    $objACL.SetAccessRuleProtection($True, $False)

    $FullRights = [System.Security.AccessControl.FileSystemRights]::FullControl
    $ModifyRights = [System.Security.AccessControl.FileSystemRights]::Modify
    $InheritanceYes = [System.Security.AccessControl.InheritanceFlags]::"ContainerInherit","ObjectInherit"
    $InheritanceNo = [System.Security.AccessControl.InheritanceFlags]::None
    $PropagateInheritOnly = [System.Security.AccessControl.PropagationFlags]::InheritOnly
    $PropagateNone = [System.Security.AccessControl.PropagationFlags]::None
    $objType =[System.Security.AccessControl.AccessControlType]::Allow 

    $objUser = New-Object System.Security.Principal.NTAccount("NT AUTHORITY\SYSTEM") 
    $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule($objUser, $FullRights, $InheritanceYes, $PropagateNone, $objType) 
    $objACL.SetAccessRule($objACE) 
    Write-Output "'$($objUser)' permissions are $($FullRights), $($InheritanceYes), $($PropagateNone), $($objType)"

    $objUser = New-Object System.Security.Principal.NTAccount("$Administrators") 
    $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule($objUser, $FullRights, $InheritanceYes, $PropagateNone, $objType) 
    $objACL.AddAccessRule($objACE)
    Write-Output "'$($objUser)' permissions are $($FullRights), $($InheritanceYes), $($PropagateNone), $($objType)"

    $objUser = New-Object System.Security.Principal.NTAccount("CREATOR OWNER") 
    $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule($objUser, $ModifyRights, $InheritanceYes, $PropagateInheritOnly, $objType) 
    $objACL.AddAccessRule($objACE)
    Write-Output "'$($objUser)' permissions are $($ModifyRights), $($InheritanceYes), $($PropagateInheritOnly), $($objType)"

    $objUser = New-Object System.Security.Principal.NTAccount("$Users") 
    $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule($objUser, $ModifyRights, $InheritanceNo, $PropagateNone, $objType) 
    $objACL.AddAccessRule($objACE)
    Write-Output "'$($objUser)' permissions are $($ModifyRights), $($InheritanceNo), $($PropagateNone), $($objType)"

    (Get-Item $FolderPath).SetAccessControl($objACL)
    Write-Output "Security settings have been set."
}

#Create Redirections Directory and Set ACLs
$RedirectFolder = New-FSlogixFolder -ProfileShareName P: -FolderName Redirections
Set-FolderPermission -FolderPath P:\Redirections #-Administrators $Administrators -Users $users
Copy-Item -Path ".\FSlogix\Redirections.xml" -Destination P:\Redirections

#Create Root Directory for profiles and Set ACLs
$RootFolder = New-FSlogixFolder -ProfileShareName P: -FolderName Profiles
Set-FolderPermission -FolderPath P:\Profiles

#Create Win10Desktop Profile Directory and Set ACLs
$NewFolder = New-FSlogixFolder -ProfileShareName P:\Profiles -FolderName GEN10
Set-FolderPermission -FolderPath P:\Profiles\GEN10

#Create RemoteApp Profile Directory and Set ACLs
$NewFolder = New-FSlogixFolder -ProfileShareName P:\Profiles -FolderName RAGEN
Set-FolderPermission -FolderPath P:\Profiles\RAGEN
