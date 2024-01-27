<#
.SYNOPSIS
This was designed to provision new VirtualMachines within Azure Virtual Desktop. 

.DESCRIPTION
REQUIRES Modules: AZ, Az.DesktopVirtualization, AzureAD, & ActiveDirectory.

.NOTES

.EXAMPLE

.Notes

#>
[CmdletBinding(SupportsShouldProcess=$True)]
Param(
    [Parameter(Mandatory=$true)][string]$UserUPN,
    [Parameter(Mandatory=$false)][string]$Domain,
    [Parameter(Mandatory=$true)][ValidateSet("prod","nonprod")][String]$Environment,
    [Parameter(Mandatory=$false)][ValidateLength(4,12)][string]$ComputerPrefix = "avpe-$($Environment.Substring(0,1))-dev",
    [Parameter(Mandatory=$false)][String]$LocationName="eastus2",
    [Parameter(Mandatory=$false)][String]$ResourceGroupName= "rg-avd-$Environment-pool-dev-$LocationName",
    [Parameter(Mandatory=$false)][string]$StorageAccountName= "storavd$($Environment)x$($LocationName)",
    [Parameter(Mandatory=$false)][string]$HostPoolName= "vdpool-$Environment-personal-dev-$LocationName",
    [Parameter(Mandatory=$false)][string]$SubnetName= "internal-desktops-02",
	[Parameter(Mandatory=$false)][string]$TimeZone,
	[Parameter(Mandatory=$false)][ValidateSet("Standard_B2s","Standard_D2s_v5","Standard_D2as_v5")][String]$vmSize="Standard_B2s"
)

<##!!Install Modules if needed!!# >
if (!(Get-Module AZ -ListAvailable)) {
    Install-Module -Name Az -AllowClobber -Force -Confirm:$false | Out-Null
    Import-Module -Name Az
}
if (!(Get-Module Az.DesktopVirtualization)) {
    Install-Module -Name Az.DesktopVirtualization -Force -Confirm:$false | Out-Null
    Import-Module -Name Az.DesktopVirtualization
}
if (!(Get-Module AzureAD)) {
    Install-Module -Name AzureAD -Force -Confirm:$false | Out-Null
    Import-Module -Name AzureAD
}
#>

#Region Functions
function Set-AZImage {
    <#
    .SYNOPSIS
    Get and Set ImageID from Azure Compute Gallery (formerly: SharedImageGallery)
        
    .DESCRIPTION
    Optional parameters are validated for the Developer Image Definition and Version

    .EXAMPLE
    $Image = Set-AZImage -Image_ResourceGroup_Name $ResourceGroup -GalleryName $GalleryName -ImageName $ImageName  -Image_LocationName $LocationName
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)][ValidateSet("rg-avd-nonprod-images-westus2","rg-avd-prod-images-westus2")]
            [string] $Image_ResourceGroup_Name,
        [Parameter(Mandatory=$false)][ValidateSet("gal_avd_nonprod_westus2","gal_avd_prod_westus2")]
            [string] $GalleryName,
        [Parameter(Mandatory=$false)][ValidateSet("img-avd-nonprod-dev-westus2","img-avd-prod-dev-westus2")]
            [string] $ImageName,
        [Parameter(Mandatory=$false)][string] $Image_LocationName=$LocationName
    )
    #If no galleryname
    if(!($GalleryName)){
        $msg= "No Image Gallery defined"
        Write-Output $msg 
        Write-Error $msg -ErrorAction Stop
    }
    else{
        $ImageRG = (Get-AzResourceGroup -Location $Image_LocationName -Name $Image_ResourceGroup_Name)
        #$ImageGallery = (Get-AzGallery -ResourceGroupName $ImageRG.ResourceGroupName -Name $GalleryName)
        $ImageDefinition = (Get-AzGalleryImageDefinition -ResourceGroupName $ImageRG.ResourceGroupName -GalleryName $GalleryName -Name $ImageName)
    }
    return $ImageDefinition
}
function Remove-FailedHost {
    param([string]$ComputerName)
    $azVM = (Get-AzResource -Name $ComputerName -ErrorAction SilentlyContinue) 
    if(!($azVM)){
        Write-Output "'$ComputerName' Not Found"
    } else{Remove-AzResource -ResourceId $($azVM.ResourceId) -Force | Out-Null}
    $avdHostName = "$ComputerName.$($domain).net"
    $avdHost = (Get-AZWVDSessionHost -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -Name $avdHostName -ErrorAction SilentlyContinue)
    if(!($avdHost)){
        Write-Output "'$($ComputerName)' not joined to Host Pool."
    } else{Remove-AzWvdSessionHost -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -Name $avdHostName | Out-Null}
}
#EndRegion Functions

<# Azure Automation RunAs Connection #>
$connectionName = "AzureRunAsConnection"
try {
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName
    #Write-Output "Logging in to Azure..."
    Connect-AzAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint | Out-Null
}
catch {
    if (!$servicePrincipalConnection){
        $msg= "Connection $connectionName not found."
        Write-Output $msg 
        Write-Error $msg -ErrorAction Stop
    } else{Write-Error $_}
}
#>

#Region Variables
$ComputerPrefix = $ComputerPrefix.ToUpper()
$ouPath= "OU=Personal,OU=$($Environment),OU=AVD,OU=Workstations,DC=$($domain),DC=net"
$AVDAgentURL = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_07-25-2022.zip" 
$blobURL = "https://$StorageAccountName.blob.core.windows.net/deployment-scripts/BootStrap.ps1"
#CM Task Sequence Provision ID
if($Environment -eq "nonprod"){$TaskSequenceID= "P0123ABD"}else{$TaskSequenceID= "P0456CDE"}
#switch works by pulling in friendly name from MS form and converts to Azure time zone. dafaults to Pacific Time. 
switch ($TimeZone) {
	"Hawaii -10:00"             {$TimeZone = "Hawaiian Standard Time"}
	"Alaska -9:00"              {$TimeZone = "Alaskan Standard Time"}
	"Pacific Time -8:00"        {$TimeZone = "Pacific Standard Time"}
	"Arizona -7:00"             {$TimeZone = "US Mountain Standard Time"}
	"Mountain Time -7:00"       {$TimeZone = "Mountain Standard Time"}
	"Central Time -6:00"        {$TimeZone = "Central Standard Time"}
	"Eastern Time -5:00"        {$TimeZone = "Eastern Standard Time"}
	"Indiana -5:00"             {$TimeZone = "US Eastern Standard Time"}
	"Atlantic Time -4:00"       {$TimeZone = "Atlantic Standard Time"}
	"East Europe +2:00"         {$TimeZone = "E. Europe"}
	"India Standard Time +5:30" {$TimeZone = "India Standard Time"}
	default {$TimeZone = "Pacific Standard Time"}
}
#WebHook for AutoShutdown Notification
$WebHookURL = ""
$StorageAccountName = Get-AutomationVariable -Name var_storage_account_name
$StorageAccountKey = Get-AutomationVariable -Name var_storage_account_key
$LocalAdminPassword = Get-AutomationVariable -Name var_local_admin_pw
$DomainJoinPassword = Get-AutomationVariable -Name var_domain_join_pw

#EndRegion Variables

#Region Main
Write-Output "Download AVD Agents from $($AVDAgentURL)"
Write-Output "Connect to AZ Blob $($blobURL)"
Write-Output "Task Sequence ID $($TaskSequenceID)"

#AZ Resource Group
Write-Output 'Verify Resource Group'
$RG = (Get-AzResourceGroup -Name $ResourceGroupName -Location $LocationName)
if(!($RG)){
    $msg= "No Resource Group found."
    Write-Output $msg; 
    Write-Error $msg -ErrorAction Stop
}
#Write-Output "Resource Group is '$($ResourceGroupName)'"

#Verify AVD HostPool
Write-Output "Verify AVD Host Pool"
$HostPool = (Get-AzWvdHostPool -Name $HostPoolName -ResourceGroupName $ResourceGroupName)
if (!($HostPool)){
    $msg= "No Host Pool found"
    Write-Output $msg
    Write-Error $msg -ErrorAction Stop
}
#Write-Output "AVD Host Pool is '$($HostPoolName)'"

#Verify User is not already assigned a desktop in the hostpool
Write-Output "Verify '$($UserUPN)' is not assigned a VM"
$CurrentAssignedUsers = (Get-AzWvdSessionHost -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName | Select-Object -ExpandProperty AssignedUser)
if ($CurrentAssignedUsers -contains $UserUPN) {
	$msg = "'$($UserUPN)' already has an assigned desktop in $HostPoolName. Terminating Runbook"
    Write-Output $msg
    Write-Error $msg -ErrorAction Stop
}

<# Search for Available SessionHost # >
$AvailHosts1 = (Get-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName | ? {$_.AssignedUser -eq $null -and $_.AllowNewSession -eq $true}) # -and $_.Status -eq "Available"
if (@($AvailHosts1)){ 
    Write-Output "Available Session Host found."
    Write-Output "Wait for 12 minutes to allow pending tasks to complete..."; start-sleep -s 60
    $AvailHosts2 = (Get-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName | ? {$_.AssignedUser -eq $null -and $_.AllowNewSession -eq $true -and $_.Status -ne "Upgrading"})
    #compare first and second list
    $AvailHosts = $AvailHosts2 |? {$AvailHosts1 -match $_ }
    if(@($AvailHosts)){
        #Select first host in list
        $SessionHostName = ($AvailHosts[0].Name).replace("$HostPoolName/","")
        #try to update assignment
        $updateUser = (Update-AzWvdSessionHost -Name $SessionHostName -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -AssignedUser $UserUPN -ErrorAction SilentlyContinue)
        #if update worked, verify and then update vm tags
        if (@($updateUser.AssignedUser -eq $UserUPN)){
            Write-Output "$($UserUPN) was assigned VM $($SessionHostName)"
            #Replace existing user tag with $userUPN
            $UpdateVM = (Get-AzVM -Name $($SessionHostName.replace(".$($domain).net",'')) -ResourceGroupName $ResourceGroupName)
            $UpdateVM.Tags.user = ($UpdateVM.Tags.user -replace "$(($UpdateVM.Tags).user)","$UserUPN")
            Write-Output "Update AZ VM user tag..."
            $UpdateTag = Update-AzVM -VM $UpdateVM -ResourceGroupName $ResourceGroupName -Tag $($UpdateVM.Tags) 
            if(!($UpdateTag)){Write-Output "VM Tag Not Updated"}
            Write-Output "Runbook Finished $(Get-Date)"; exit
        }else {
            $msg= "Update User Assignment Failed."
            Write-Output $msg
            Write-Error $msg -ErrorAction Stop
        }
    }else {Write-Output "No Available Session Host, proceed to New-VM"}   
}else {Write-Output "Session Host no longer available, proceed to New-VM"}
#>

#Set AVD HostPool Registration Token
$RegInfo = (Get-AzWvdRegistrationInfo -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName)
$now = $((get-date).ToUniversalTime())
# Validate Token
if ((($RegInfo.ExpirationTime) -lt $now) -or ($null -eq $RegInfo)){
    Write-Output "Token is expired/missing, generating new registration token for pool: $($HostPoolName)"
    New-AzWvdRegistrationInfo -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -ExpirationTime $($now.AddDays(21).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')) | Out-Null
    $AVDHostPoolRegKey = ((Get-AzWvdRegistrationInfo -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName).Token)
} else {$AVDHostPoolRegKey = ($RegInfo.Token)}
if(!($AVDHostPoolRegKey)){
    $msg= "No Registration Key Found."
    Write-Output $msg 
    Write-Error $msg -ErrorAction Stop
}
$token = (ConvertTo-SecureString $AVDHostPoolRegKey -AsPlainText -Force)

#Get next available VM name in pool
#Write-Output "Get next available name in pool"
$Range = 01..1000
$SessionHosts = (Get-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName | ForEach-Object {($_.Name -split '/')[1] -replace ".$($domain).net",''})
$CurrentHostNumbers = $SessionHosts -replace "$ComputerPrefix-",''
$Count = 0
$NextHostNumber = $Range | Where-Object {$CurrentHostNumbers -notcontains $_} | Select-Object -First 1 -Skip $Count
$ComputerName = "$ComputerPrefix-$NextHostNumber"
while (Get-AzResource -Name $ComputerName) {
    #Write-Output "$ComputerName already exists in Azure, moving on to next..."
    $Count++
    $NextHostNumber = $Range | Where-Object {$CurrentHostNumbers -notcontains $_} | Select-Object -First 1 -Skip $Count
    $ComputerName = "$ComputerPrefix-$NextHostNumber"
}
Write-Output "VM will be named '$($ComputerName)'"

<# Local Template File # >
$Template ="New-AVDComputer\TemplateSpec.jsonc"
Write-Output "Verify ARM Template"
if(!($(Test-Path $Template))){
    $msg ="Missing ARM Template"
    Write-Output $msg
    Write-Error $msg -ErrorAction Stop
}
Write-Output "ARM Template is set"
#>

<# Azure Template Spec #>
$TemplateSpecResource = (Get-AzResource -ResourceType Microsoft.Resources/templateSpecs | Where-Object Name -Like "ts-avd-$Environment-personalhost-$LocationName")
$TemplateSpec = Get-AzTemplateSpec -ResourceGroupName $TemplateSpecResource.ResourceGroupName -Name $TemplateSpecResource.Name
if ($TemplateSpec.Versions.Count -gt 1) {$TemplateSpecId = $TemplateSpec.Versions.Id[-1]}
if ($TemplateSpec.Versions.Count -eq 1) {$TemplateSpecId=$TemplateSpec.Versions.Id}
Write-Output "Template spec ID $($TemplateSpecId)"

#VM Networking
Write-Output 'Set vNetwork and Subnet'
$vNetName = "internal-network"
$vNet = (Get-AzVirtualNetwork -Name $vNetName)
$Subnet = (Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vNet -Name $SubnetName)
if(!($Subnet)){
    $msg= "No subnet found"
    Write-Output $msg
    Write-Error $msg -Error Action Stop
}
#Write-Output "AZ Subnet is '$($subnet.Name)'"  

#VM Source Image
Write-Output 'Set VM Source Image' 
$Image = Set-AZImage `
    -Image_ResourceGroup_Name "rg-avd-$($Environment)-images-$LocationName" `
    -GalleryName "gal_avd_$($Environment)_$LocationName" `
    -ImageName "img-avd-$($Environment)-dev-$LocationName"
#Write-Output "VM Source Image is '$($Image.Name)'"

#AD OrgUnit
Write-Output 'Verify ActiveDirectory Organizational Unit'
$OU = (Get-ADOrganizationalUnit -Identity $ouPath)
if(!($OU)){
    $msg= "No AD OU found."
    Write-Output $msg
    Write-Error $msg -ErrorAction Stop
}
#Write-Output "AD OU is '$($ouPath)'"

#LogAnalytic Workspace ID and Key
$workspace = (Get-AzOperationalInsightsWorkspace -ResourceGroupName "rg-avd-$($Environment)-mgmt-$LocationName"  -Name "la-avd-$Environment-$LocationName")
$workspaceKeys = ($workspace | Get-AzOperationalInsightsWorkspaceSharedKey)
$workspaceID = ($workspace.CustomerId.Guid)
$workspaceKey = (ConvertTo-SecureString $workspaceKeys.PrimarySharedKey -AsPlainText -Force)

Write-Output "Deploy ARM Template $(Get-Date)"
$Deployment = (New-AzResourceGroupDeployment `
    -resourceGroupName $ResourceGroupName `
    -TemplateSpecId $TemplateSpecId `
    -userEmail $UserUPN `
    -vmName $ComputerName `
    -subnetId $($Subnet.Id) `
    -imageID $($Image.Id) `
    -ouPath $ouPath `
    -localPassword (ConvertTo-SecureString $LocalAdminPassword -AsPlainText -Force) `
    -domainJoinPassword (ConvertTo-SecureString $domainJoinPassword -AsPlainText -Force) `
    -hostPoolName $HostPoolName `
    -hostPoolToken $token `
    -avdAgentURL $AVDAgentURL `
    -storageAccountName $StorageAccountName `
    -storageAccountKey (ConvertTo-SecureString $StorageAccountKey -AsPlainText -Force) `
    -vmScriptBlobURL $blobURL `
    -deploymentID $TaskSequenceID `
    -vmSize $VMSize `
    -autoShutdownTimeZone $TimeZone `
    -autoShutdownNotificationWebhookUrl $WebHookURL `
    -workspaceId $workspaceID `
    -workspaceKey $workspaceKey `
    -autoShutdownStatus 'Disabled'
)

Write-Output "Delete Azure Deployment Script"
Remove-AzDeploymentScript -Name "$ComputerName-WaitSection" -ResourceGroupName $ResourceGroupName 

if($Deployment.ProvisioningState -eq "Succeeded"){Write-Output "ARM Deployment completed $(Get-Date)"}
if($Deployment.ProvisioningState -eq "Failed"){
    Write-Output "wait for 5 mins and begin cleanup..."
    start-sleep -s 300
    Remove-FailedHost -ComputerName $ComputerName
    $msg= "ERROR - Deployment Failed. Terminating" 
    Write-Output $msg 
    Write-Error $msg -ErrorAction Stop
}

Write-Output "Verify AVD Session Host is Ready`nThis could take 15 minutes..."
$avdHostName = "$ComputerName.$($domain).net"
[int]$check=1;$max=15
do{
    #Write-Output "Check Host Status Attempt $($check) of $($max)"
    $HostStatus = (Get-AzWvdSessionHost -HostPoolName $HostPoolName -Name $avdHostName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue).Status
    if($HostStatus -ne "Available"){
        #Write-Output "Session Host is Not Ready..."
        $check++; start-sleep -s 60
    }
    if($HostStatus -eq "Available"){Write-Output "Session Host is Ready.";break}
}until($check -gt $max)
if ($check -gt $max){
    Write-Output "Session Host did not join in expected time, initiate cleanup..."
    Remove-FailedHost -ComputerName $ComputerName
    $msg= "ERROR - Deployment Failed. Terminating"
    Write-Output $msg
    Write-Error $msg -ErrorAction Stop
}

#Assign new desktop to user
Write-Output "Assigning $ComputerName.$($domain).net to $UserUPN in $HostPoolName"
Update-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -Name "$ComputerName.$($domain).net" -AssignedUser "$UserUPN"

Write-Output "Runbook Finished $(Get-Date)"

#EndRegion Main