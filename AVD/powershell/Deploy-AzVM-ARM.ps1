Param(
    [Parameter(Mandatory=$false,HelpMessage="Path to ARM Template")][string]
        $Template =".\ARM-Templates\AzVM-ARM.json", 
    [Parameter(Mandatory=$false,HelpMessage="Prod or NonProd")][ValidateSet("prod","nonprod")][String]
        $Environment= "prod",
    [Parameter(Mandatory=$false,HelpMessage="Azure Region")][String]
        $LocationName="westus2",
    [Parameter(Mandatory=$false,HelpMessage="VM Name Prefix")][ValidateLength(4,12)][string] 
        $ComputerPrefix = "AVD-MGMT-VM",
    [Parameter(Mandatory=$false,HelpMessage="Active Directory OU DN")][string]
        $OUPath= "OU=Workstations,DC=DOMAIN,DC=net",
    [Parameter(Mandatory=$false)][String]
        $ResourceGroupName = "rg-avd-$Environment-mgmt-$LocationName",
    [Parameter(Mandatory=$false,HelpMessage="Azure Subnet Name")][string]
        $SubnetName = "internal-desktops-02",
    [Parameter(Mandatory=$false,HelpMessage="Azure Storage Account Name")][string]
        $Storageaccountname,
    [Parameter(Mandatory=$false,HelpMessage="User eMail Address")][string]
        $UserUPN = "matthew.franklin@DOMAIN.com",
    [Parameter(Mandatory=$false,HelpMessage="AD Domain Name")][String]
        $DomainName="DOMAIN.com",
    [Parameter(Mandatory=$false,HelpMessage="Local Admin Account Name")][String]
        $LocalAdmin,
    [Parameter(Mandatory=$false,HelpMessage="Local Admin Password")][SecureString]
        $LocalAdminPassword = $(Read-Host "Enter Local Password" -AsSecureString),
    [Parameter(Mandatory=$false,HelpMessage="AD Domain User")][SecureString]
        $domainJoinUser,
    [Parameter(Mandatory=$false,HelpMessage="AD Domain Password")][SecureString]
        $domainJoinPassword,
    [Parameter(Mandatory=$false,HelpMessage="Number of VMs")][int]
        $VMcount=1,
    [Parameter(Mandatory=$false,HelpMessage="VM Profile Size")][string]
      $VMsize = "Standard_D8s_v5"        
)
##Set Azure VM Source Image. If no gallery image is selected, new VM will deploy from marketplace
# dot source functions when possible
function Set-AZImage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)][string] $Environment=$Environment ,
        [Parameter(Mandatory=$false)][string] $LocationName=$LocationName,
        [Parameter(Mandatory=$false)][string] $Image_ResourceGroup_Name,
        [Parameter(Mandatory=$false)][string] $GalleryName,
        [Parameter(Mandatory=$false)][string] $ImageName,
        [Parameter(Mandatory=$false)][string] $Image_LocationName=$LocationName
    )
    #[ValidateSet("rg-avd-$Environment-images-$LocationName")]
    #[ValidateSet("img-avd-$Environment-evd-$LocationName")]
    #[ValidateSet("sig_avd_$($Environment)_$($LocationName)")]
    if(!($GalleryName)){
        Write-Output "No Image Gallery defined"
        $Publisher = (Get-AzVMImagePublisher -Location $LocationName | Where-Object {$_.PublisherName -like "MicrosoftWindowsDesktop"})
        $Offer = (Get-AzVMImageOffer -Location $LocationName -PublisherName $Publisher.PublisherName | Where-Object {$_.Offer -like "windows-10"})
        $SKU = (Get-AzVMImageSku -Location $LocationName -PublisherName $Publisher.PublisherName -Offer $offer.Offer | Where-Object {$_.skus -like "21h1-evd"})
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

Write-Output 'Set Azure Subscription ID'
$SubscriptionID = (Get-AzSubscription -SubscriptionName "$($Environment)-CorporateServices-VDI" | Select-Object Id)
Select-AZSubscription -SubscriptionID $SubscriptionID.Id | out-null

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
        -Image_ResourceGroup_Name "rg-avd-$($Environment)-images-$LocationName" `
        -GalleryName "sig_avd_$($Environment)_$LocationName" `
        -ImageName "img-avd-$($Environment)-evd-$LocationName" ##Deploys EVD Image


#Domain Join Creds
if(!($domainJoinUser -or $domainjoinpassword)){
    $creds = . .\Cred-File.ps1
    $domainjoinpassword = ConvertTo-SecureString $($Creds.GetNetworkCredential().Password) -AsPlainText -Force
    $domainJoinUser = ConvertTo-SecureString  $($Creds.UserName)  -AsPlainText -Force 
}else {Write-Output "Domain Join Creds provided"}


$Storage = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $Storageaccountname
$Keys = Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $Storageaccountname 
$StorageAccountKey = ConvertTo-SecureString $Keys.Value[0] -AsPlainText -Force 

#full path to script
$blobURL = "https://$Storageaccountname.blob.core.windows.net/deployment-scripts/cmbootstrap.ps1"

Write-Output "`nDeploy ARM Template $(Get-Date)`n"
New-AzResourceGroupDeployment `
        -ResourceGroupName $RG.ResourceGroupName `
        -TemplateFile $Template `
        -vmNamePrefix $ComputerPrefix `
        -NumberOfvms $VMcount `
        -vmSize $VMsize `
        -subnetID $Subnet.Id `
        -imageID $Image.Id `
        -OUpath $OU.DistinguishedName `
        -localPassword (ConvertTo-SecureString $LocalAdminPassword -AsPlainText -Force) `
        -domainJoinUser $domainJoinUser `
        -domainJoinPassword $domainJoinPassword `
        -userEmail $UserUPN `
        -storageAccountName $Storage.StorageAccountName `
        -storageAccountKey $StorageAccountKey `
        -vmScriptBlobURL $blobURL
Write-Output "`nARM Deployment completed $(Get-Date)"