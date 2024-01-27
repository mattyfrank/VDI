<#
.SYNOPSIS
This was designed to provision new VirtualMachines within Azure Virtual Desktop. 
Custom functions can be combined to fully provision resources. 

.DESCRIPTION
REQUIRES Modules: AZ, Az.DesktopVirtualization, AzureAD, & ActiveDirectory.

Call functions as needed. Use tab complete on each function to see available parameters.
Functions were designed to be modular and used in combination to simplify routine tasks. 
Some functions will stop on error, while others will alert and continue.
Parameters could be optional or mandatory. If a parameter is not provided, some functions will auto-generate results. 
Assign a output variable to a function, and use the variable in other functions as an input parameter.

.NOTES
Remove $MultiComputers switch. 

.EXAMPLE
New-AVDSessionHost.ps1 -Template ".\ARM-Templates\AVD-SessionHost.json" `
                        -Environment "NonProd" `
                        -ComputerPrefix "PrefixName" `
                        -OUPath "OU=Workstations,DC=DOMAIN,DC=com" `
                        -ResourceGroupName "rg-nonprod" `
                        -SubnetName "internal-desktops-02" `
                        -AVDHostPool "pool-nonprod" `
                        -UserUPN "matthew.franklkin@DOMAIN.com" `
                        -VMcount 5                      

.Notes

#>
[CmdletBinding(SupportsShouldProcess=$True)]
Param(
    [Parameter(Mandatory=$false,HelpMessage="Path to ARM Template")][string]$Template =".\ARM-Templates\AVD-SessionHost.json",
    [Parameter(Mandatory=$true,HelpMessage="Prod or NonProd")][ValidateSet("prod","nonprod")][String]$Environment,
    [Parameter(Mandatory=$false,HelpMessage="Azure Region")][String]$LocationName="westus2",
    [Parameter(Mandatory=$false)][String]$ResourceGroupName = "rg-avd-$Environment-pool-$LocationName",
    [Parameter(Mandatory=$false,HelpMessage="Azure Storage Account Name")][string]$StorageAccountName = "storavd$($Environment)x$($LocationName)",
    [Parameter(Mandatory=$false,HelpMessage="Azure Virtual Desktop Host Pool Name")][string]$AVDHostPool = "pool-$Environment-personal-$LocationName",
    [Parameter(Mandatory=$false,HelpMessage="Active Directory OU DN")][string]$OUPath= "OU=AVD,OU=Workstations,DC=DOMAIN,DC=COM",
    [Parameter(Mandatory=$false,HelpMessage="Azure Subnet Name")][string]$SubnetName = "internal-desktops-02",
    [Parameter(Mandatory=$false,HelpMessage="VM Name Prefix")][ValidateLength(4,12)][string] $ComputerPrefix = "avpe-prd-vm",
    [Parameter(Mandatory=$false,HelpMessage="AD Domain Name")][String]$DomainName="DOMAIN.COM",
    [Parameter(Mandatory=$false,HelpMessage="Local Admin Account Name")][String]$LocalAdmin,
    [Parameter(Mandatory=$false,HelpMessage="Local Admin Password")][SecureString]$LocalAdminPassword = $(Read-Host "Enter Local Password" -AsSecureString),
    [Parameter(Mandatory=$false,HelpMessage="AD Domain User")][SecureString]$domainJoinUser,
    [Parameter(Mandatory=$false,HelpMessage="AD Domain Password")][SecureString]$domainJoinPassword,
    [Parameter(Mandatory=$false,HelpMessage="Number of VMs")][int]$VMcount=1,
    [Parameter(Mandatory=$true,HelpMessage="User eMail Address")][string]$UserUPN
)

#Install Modules if needed. 
# if (!(Get-Module AZ -ListAvailable)) {
#     #Install-Module -Name Az -AllowClobber -Force -Confirm:$false | Out-Null
#     import-Module -Name Az
# }
# if (!(Get-Module Az.DesktopVirtualization)) {
#     #Install-Module -Name Az.DesktopVirtualization -Force -Confirm:$false | Out-Null
#     import-Module -Name Az.DesktopVirtualization
# }
# if (!(Get-Module AzureAD)) {
#     #Install-Module -Name AzureAD -Force -Confirm:$false | Out-Null
#     import-Module -Name AzureAD
# }

#Connect to Azure and AzureAD
#OKTA Web prompt
$User = "matthew.franklin@DOMAIN.com"
Connect-AzAccount -AccountId $User
Connect-AzureAD -AccountId $User

# $tenantID = "########"

# ##Connect with RunAs for AZ Automation
# $connectionName = "AzureRunAsConnection"
# try
# {
#     # Get the connection "AzureRunAsConnection"
#     $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

#     "Logging in to Azure..."
#     Connect-AzAccount `
#         -ServicePrincipal `
#         -TenantId $servicePrincipalConnection.TenantId `
#         -ApplicationId $servicePrincipalConnection.ApplicationId `
#         -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
# }
# catch {
#     if (!$servicePrincipalConnection)
#     {
#         $ErrorMessage = "Connection $connectionName not found."
#         throw $ErrorMessage
#     } else{
#         Write-Error -Message $_.Exception
#         throw $_.Exception
#     }
# }

#Region Functions
function Write-Log {
    param($msg)
    Write-Output $msg
    Write-Error $msg -ErrorAction Stop
}
##Set Azure VM Source Image. If no gallery image is selected, new VM will deploy from marketplace
function Set-AZImage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)][ValidateSet("rg-avd-nonprod-images","rg-avd-prod-images")]
            [string] $Image_ResourceGroup_Name,
        [Parameter(Mandatory=$false)][ValidateSet("sig_avd_nonprod","sig_avd_prod")]
            [string] $GalleryName,
        [Parameter(Mandatory=$false)][ValidateSet("img-avd-nonprod-dev-v2","img-avd-prod-dev-v2")]
            [string] $ImageName,
        [Parameter(Mandatory=$false)][string] $Image_LocationName=$LocationName
    )
    #If no gallery image, select from marketplace
    if(!($GalleryName)){
        Write-Output "No Image Gallery defined"
        $Publisher = (Get-AzVMImagePublisher -Location $LocationName | Where-Object {$_.PublisherName -like "MicrosoftWindowsDesktop"})
        $Offer = (Get-AzVMImageOffer -Location $LocationName -PublisherName $Publisher.PublisherName | Where-Object {$_.Offer -like "windows-10"})
        $SKU = (Get-AzVMImageSku -Location $LocationName -PublisherName $Publisher.PublisherName -Offer $offer.Offer | Where-Object {$_.skus -like "win10-21h2-ent-g2"})
        $Versions = (Get-AzVMImage -Location $LocationName -PublisherName $Publisher.PublisherName -Offer $offer.Offer -Sku $SKU.skus)
        $Latest = $Versions[-1]
        $ImageDefinition = $Latest
    }
    else{
        $ImageRG = (Get-AzResourceGroup -Location $Image_LocationName -Name $Image_ResourceGroup_Name)
        #$ImageGallery = (Get-AzGallery -ResourceGroupName $ImageRG.ResourceGroupName -Name $GalleryName)
        $ImageDefinition = (Get-AzGalleryImageDefinition -ResourceGroupName $ImageRG.ResourceGroupName -GalleryName $GalleryName -Name $ImageName)
    }
    return $ImageDefinition
}

function Test-ComputerName {
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param([Parameter(Mandatory=$True)][string] $ComputerName)
    Write-Output 'Check for Existing AD Computer'
    try {
        $ComputerObj = (Get-ADComputer $ComputerName -ErrorAction SilentlyContinue)
        Write-Error "Computer Object already exists in $DomainName";break
    }
    catch {Write-Output "No Computer Object found in domain '$($DomainName)'"}
    #Write-Output 'Set VM Name based on Computer Name'
    $VirtualMachineName = $ComputerName
    Write-Output 'Check for Existing AZ VM'
    if(@(Get-AzVM -Name $VirtualMachineName -ErrorAction SilentlyContinue)){
        Write-Error "AZ VM already exists in $VirtualMachineName";break
    }
    Write-Output "VM Name is '$($VirtualMachineName)'"
}

function Set-RegKey {
    <#
    .SYNOPSIS
    Create new host pool Registration Token.
        
    .DESCRIPTION
    Takes in mandatory parameter HostPoolName, looks for existing HostPool with that Name, updates HostPool
    Takes in optional parameter Expiration as number of days before the token expires. 
    Returns HostPool Token 

    .EXAMPLE
    $Token = (Set-RegKey -HostPoolName $HostPool -ResourceGroupName $ResourceGroupName)    
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True)][string] $HostPoolName,
        [Parameter(Mandatory=$True)][string] $ResourceGroupName,
        [Parameter(Mandatory=$False,HelpMessage="Number of Days before Registration Token Expires")]
            [ValidateRange("1","27")][int]$Expiration ='2'
    )
    $HostPool = (Get-AzWVDHostPool -Name $HostPoolName -ResourceGroupName $ResourceGroupName -ErrorVariable NotPresent -ErrorAction SilentlyContinue)
    if (!($HostPool)){Write-Error "No Host Pool found.";break}
    $GetToken = (New-AzWvdRegistrationInfo `
                    -ResourceGroupName $ResourceGroupName `
                    -HostPoolName $HostPoolName `
                    -ExpirationTime (Get-Date).AddDays($Expiration) `
                    -ErrorAction SilentlyContinue
                )
    #$SecureToken = ConvertTo-SecureString $GetToken.Token -AsPlainText -Force
    return $GetToken
}

#EndRegion Functions

####--------####
#Region Main

Write-Output 'Set Azure Subscription ID'
$SubscriptionID = (Get-AzSubscription -SubscriptionName "$($Environment)-CorporateServices-VDI" | Select-Object Id)
Select-AzSubscription -SubscriptionID $SubscriptionID.Id | Out-Null

Write-Output "Verify ARM Template"
if(!($(Test-Path $Template))){Write-Error "Missing ARM Template";break}
Write-Output "ARM Template is set"

Write-Output 'Verify Azure Region or Location'
$Location = $(Get-AZLocation | Where-Object {$_.Location -eq $LocationName})
if(!($location)){Write-Error "No Azure Location found.";break}
Write-Output "Azure Region is $($Location.DisplayName)"

Write-Output 'Verify Resource Group'
$RG = (Get-AzResourceGroup -Name $ResourceGroupName -Location $LocationName)
if(!($RG)){Write-Error "No Resource Group found.";break}
Write-Output "Resource Group is '$($RG.ResourceGroupName)'"

Write-Output 'Verify ActiveDirectory Organizational Unit'
$OU = (Get-ADOrganizationalUnit -Identity $OUPath)
if(!($OU)){Write-Error "No AD OU found.";break}
Write-Output "AD OU is '$($OU.DistinguishedName)'"

Write-Output 'Set vNetwork and Subnet'
$vNetName = "internal-network"
#$vNetRG = "Subscription_Network_RG"
$vNet = (Get-AzVirtualNetwork -Name $vNetName)
$Subnet = (Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vNet -Name $SubnetName)
if(!($Subnet)){Write-Error "No subnet found"; break}
Write-Output "AZ Subnet is '$($subnet.Name)'"  

Write-Output 'Set VM Source Image' 
$Image = Set-AZImage `
        -Image_ResourceGroup_Name "rg-avd-$($Environment)-images" `
        -GalleryName "sig_avd_$($Environment)" `
        -ImageName "img-avd-$($Environment)-evd"

Write-Output 'Define AVD Agent Location'
$AVDAgentURL = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_06-15-2022.zip" 
#  <#  $StartDate=(Get-Date 08-10-2021);$EndDate=(Get-Date) 10-16-21, 2-23-22, 4-26 , 5-11, 6-15, 07-25, 08-10,    #>
$StartDate=(Get-Date 10-27-2022);$EndDate=(Get-Date)
While($StartDate -le $EndDate){
    ($StartDate=$StartDate.AddDays(1))
    $Date=(Get-Date $StartDate -f MM-d-yyyy)
    $AVDAgentURL="https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_$($Date).zip"
    try {Invoke-WebRequest -Uri $AVDAgentURL}
    catch{Write-Output "$Date"}
}

#Set AVD HostPool Registration Token
Write-Output "AVD Host Pool '$($AVDHostPool)'"
$AVDHostPoolRegKey = $(Set-RegKey -HostPoolName $AVDHostPool -ResourceGroupName $RG.ResourceGroupName).Token
if(!($AVDHostPoolRegKey)){Write-Error "No Host Pool Registration Key found"; break}
$token = (ConvertTo-SecureString $AVDHostPoolRegKey -AsPlainText -Force)

#Domain Join Creds; if creds are not passed inline, try to get creds from file. 
if(!($domainJoinUser -or $domainjoinpassword)){
    $creds = . .\Cred-File.ps1
    $domainjoinpassword = (ConvertTo-SecureString $($Creds.GetNetworkCredential().Password) -AsPlainText -Force)
    $domainJoinUser = (ConvertTo-SecureString  $($Creds.UserName) -AsPlainText -Force)
}
else {Write-Output "Domain Join Creds provided"}

#MGMT RG var 
$mgmtRG = "rg-avd-$Environment-mgmt-$LocationName"
$Storage = Get-AzStorageAccount -ResourceGroupName $mgmtRG -Name $StorageAccountName    
$Keys = Get-AzStorageAccountKey -ResourceGroupName $mgmtRG -Name $StorageAccountName 
$StorageAccountKey = (ConvertTo-SecureString $Keys.Value[0] -AsPlainText -Force)

$blobURL = "https://$StorageAccountName.blob.core.windows.net/deployment-scripts/cmbootstrap.ps1" #must be full path

#LogAnalytic Workspace ID and Key
$workspace = (Get-AzOperationalInsightsWorkspace -ResourceGroupName $mgmtRG -Name "la-avd-$Environment-$LocationName")
$workspaceKeys = ($workspace | Get-AzOperationalInsightsWorkspaceSharedKey)
$workspaceID = ($workspace.CustomerId.Guid)
$workspaceKey = (ConvertTo-SecureString $workspaceKeys.PrimarySharedKey -AsPlainText -Force)

# $VMNamePrefix = "TEST-AVD-AVMS-"
# [int]$VMcount=11
# $x=0
# do{Test-ComputerName "$VMNamePrefix$x"; $x=$X+1}
# until($x -gt $VMcount) #or when Test-Computer returns true...

Write-Output "Deploy ARM Template $(Get-Date)"
try { New-AzResourceGroupDeployment `
        -ResourceGroupName $RG.ResourceGroupName `
        -TemplateFile $Template `
        -vmNamePrefix $ComputerPrefix `
        -NumberOfvms $VMcount `
        -subnetID $Subnet.Id `
        -imageID $Image.Id `
        -OUpath $OU.DistinguishedName `
        -localPassword $LocalAdminPassword `
        -domainJoinUser $domainJoinUser `
        -domainJoinPassword $domainJoinPassword `
        -HostPoolToken $token `
        -HostPoolName $AVDHostPool `
        -AVDAgentURL $AVDAgentURL `
        -workspaceId $workspaceID `
        -workspaceKey $workspaceKey `
        -storageAccountName $Storage.StorageAccountName `
        -storageAccountKey $StorageAccountKey `
        -vmScriptBlobURL $blobURL `
        -userEmail $UserUPN
    Write-Output "ARM Deployment completed $(Get-Date)"
}
catch {Write-Output "ARM Deployment Failed $(Get-Date)"}

# }

#EndRegion Main

####--------####
#Region Scratch
<#
Write-Output 'Check for Existing AD Computer'
try {
    $ComputerObj = (Get-ADComputer $ComputerName -ErrorAction SilentlyContinue)
    Write-Error "Computer Object already exists in $DomainName";break
}
catch {
    Write-Output "No Computer Object found in $DomainName"
}

Write-Output 'Set VM Name based on Computer Name'
$VirtualMachineName = $Computername
Write-Output "VM Name is '$($VirtualMachineName)'"
if(@(Get-AzVM -Name $VirtualMachineName -ErrorAction SilentlyContinue)){
    Write-Error "AZ VM already exists in $VirtualMachineName";break
}

Write-Output "Delete AD Object"
$Obj = Get-ADComputer -Identity $VirtualMachineName
Remove-ADObject $($Obj.DistinguishedName) -Recursive -Credential $Cred -Confirm:$false
#>

#EndRegion