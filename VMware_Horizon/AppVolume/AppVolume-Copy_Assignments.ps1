param(
    [Parameter(Mandatory=$false)][String]$avServer="appvolume.domain.net",    
    [Parameter(Mandatory=$false)][String]$cred_path = ".\_creds.xml",
    [Parameter(Mandatory=$true)][String]$CurrentAppProductID=1,
    [Parameter(Mandatory=$true)][String]$NewAppProductID=1
)

#Load Creds"
if(!(Test-Path $cred_path)){
    $creds=Get-Credential -Message "Enter Creds in the format Domain\UserName"
}else{$creds = Import-Clixml -Path $cred_path}
$credentials = @{
    username = $creds.UserName
    password = $creds.GetNetworkCredential().Password
}

#Auth to AppVol and status returned
$Session = Invoke-RestMethod -UseBasicParsing -SessionVariable avSession -Method Post -Uri "https://$avServer/app_volumes/sessions" -Body $credentials

#Get Current Package by ID
# $Response = Invoke-RestMethod -UseBasicParsing -WebSession $avSession -Method Get -Uri "https://$avServer/app_volumes/app_products/$($CurrentAppProductID)/app_packages"
# $CurrentAppPackageID= $($Response.data.id)

#Get New Package by ID
$Response = Invoke-RestMethod -UseBasicParsing -WebSession $avSession -Method Get -Uri "https://$avServer/app_volumes/app_products/$($NewAppProductID)/app_packages"
$NewAppPackageID= $($Response.data.id)

#Get App Assignment for Current App Product ID
$Response = Invoke-RestMethod -UseBasicParsing -WebSession $avSession -Method Get -Uri "https://$avServer/app_volumes/app_products/$($CurrentAppProductID)/assignments?include=entities,filters"
# $Entities = $($Response.data.entities)
# $Filters  = $($Response.data.filters)

<#
#Create JSON Body
$AssignmentJsonBody = "{""data"":[{""app_product_id"":$($NewAppProductID),""entities"":[{""path"":""$($Entities.distinguished_name)"",""entity_type"":""$($Entities.entity_type)""}],""app_package_id"":$($NewAppPackageID),""app_marker_id"":null,""filters"":[{""type"":""$($Filters.type)"",""value"":""$($Filters.value)""}]}]}"

#POST JSON
Invoke-RestMethod  -WebSession $avSession -Method Post -Uri "https://$avServer/app_volumes/app_assignments" -Body $AssignmentJsonBody -ContentType 'application/json'
#>

Write-Output "Add Assignments to the New Package ID"
#ForEach Response |  Set Assignment 
$Response.data | % {
    $Entities = $_.entities
    $Filters  = $_.filters
    $AssignmentJsonBody = "{""data"":[{""app_product_id"":$($NewAppProductID),""entities"":[{""path"":""$($Entities.distinguished_name)"",""entity_type"":""$($Entities.entity_type)""}],""app_package_id"":$($NewAppPackageID),""app_marker_id"":null,""filters"":[{""type"":""$($Filters.type)"",""value"":""$($Filters.value)""}]}]}"
    Write-Output $AssignmentJsonBody
    Invoke-RestMethod  -WebSession $avSession -Method Post -Uri "https://$avServer/app_volumes/app_assignments" -Body $AssignmentJsonBody -ContentType 'application/json'
}

Write-Output "Remove Assignments from the Current Package ID"
#ForEach Response |  Remove Assignment 
$Response.data | % {
    $AssignmentId = $_.id
    Invoke-RestMethod  -WebSession $avSession -Method Post -Uri "https://$avServer/app_volumes/app_assignments/delete_batch?ids%5B%5D=$($AssignmentId)"
}

Write-Output "Assignments Completed"