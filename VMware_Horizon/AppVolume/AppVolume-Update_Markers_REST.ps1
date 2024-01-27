<#
.DESCRIPTION
Manage App Volume via API. Update App Package's properties like Lifycycle and Marker (CURRENT). Can also support deleting AppPackage. 

.NOTES
LifeCycles:
1=New
2=Tested
3=Published
4=Retired
#>

param(
    [Parameter(Mandatory=$true)][String]$AppProductID,
    [Parameter(Mandatory=$false)][String]$avServer="AppVolume.Domain.net"
)

#Import Creds
$cred = Import-Clixml ".\creds.xml"
$credentials = @{
    username = $cred.UserName
    password = $cred.GetNetworkCredential().Password
}

#Auth to AppVol and status returned
$Session = Invoke-RestMethod -UseBasicParsing -SessionVariable avSession -Method Post -Uri "https://$avServer/app_volumes/sessions" -Body $credentials

#Get App Packages for AppProductID
$Response = Invoke-RestMethod -UseBasicParsing -WebSession $avSession -Method Get -Uri "https://$avServer/app_volumes/app_products/$($AppProductID)/app_packages?include=app_markers"

#Review Response for AppPackages associated with the AppProductID
foreach($obj in $($response.data)){
    Write-Host "$($obj.name) is assigned AppPackage ID $($obj.id)"
    if($obj.app_markers){Write-Host "$($obj.name) is $($obj.app_markers.name)"}
}

#Set the AppPackageID LifeCycle to Published
$AppPackageID     = Read-Host "Enter the App Package ID to Publish"
$LifeCycleStage   = 3
Invoke-RestMethod -UseBasicParsing -WebSession $avSession -Method Put -Uri "https://$avServer/app_volumes/app_packages/$($AppPackageID)?data%5Blifecycle_stage_id%5D=$($LifeCycleStage)"

#Set Current Marker for above AppPackageID
Invoke-RestMethod -UseBasicParsing -WebSession $avSession -Method Put -Uri "https://$avServer/app_volumes/app_products/$($AppProductID)/app_markers/CURRENT?data%5Bapp_package_id%5D=$($AppPackageID)"

#Set the AppPackageID LifeCycle to Retired
$AppPackageID     = Read-Host "Enter the App Package ID to Retire"
$LifeCycleStage   = 4
Invoke-RestMethod -UseBasicParsing -WebSession $avSession -Method Put -Uri "https://$avServer/app_volumes/app_packages/$($AppPackageID)?data%5Blifecycle_stage_id%5D=$($LifeCycleStage)"

#!!!!Delete AppPackageID!!!!
#$AppPackageID     = Read-Host "!!!WARNING!!! - Enter the App Package ID to DELETE"
#Invoke-RestMethod -UseBasicParsing -WebSession $avSession -Method Delete -Uri "https://$avServer/app_volumes/app_packages/$($AppPackageID)"

#Disconnect
$Disconnect = Invoke-RestMethod -UseBasicParsing -WebSession $avSession -Method Delete -Uri "https://$avServer/app_volumes/sessions"
