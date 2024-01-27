<#
    .DESCRIPTION
    This script uses the Horizon rest api's to push a new golden image to a VMware Horizon Desktop Pool

    .EXAMPLE
    #Get Credentials
    $creds = Import-CliXML .\$($ENV:USERNAME)_creds.xml #Get-Credential
    #Define Horizon and vCenter Servers
    $hvServer    = "Horizon.Domain.Net"
    $hvServerURL = "https://$hvServer"
    $vCenter     = "vCenter.Domain.Net"
    #Connect to Horizon
    Connect-HVServer -Server $hvServer -Credential $creds | Out-Null
    #Get Pools with Floating Assignments and Filter based on Pool Name
    $Pools     = Get-HVPool -UserAssignment FLOATING 
    $TestPools = $Pools | where {$_.base.name -like "test-*"} | % {$_.base.name}
    $ProdPools = $Pools | where {($_.base.name -notlike "test-*") -and ($_.base.name -notlike "*PCI_VDA*")} | % {$_.base.name}
    #Disconnect from Horizon
    Disconnect-HVServer * -Confirm:$false
    #Connect to vCenter
    Connect-VIServer $vCenter -Credential $creds | Out-Null
    #Get DataCenter Name, and Base VM, and Snapshot Names
    $dcName   = (Get-Datacenter).Name  
    $baseVM   = (Get-VM "Win10-$(Get-Date -f yy.MM)A").Name
    $snapName = (Get-Snapshot -VM $baseVM -Name "Ready").Name
    #Disconnect from vCenter
    Disconnect-VIServer * -Confirm:$false
    #Define time for scheduled update to apply new image. 
    $time = Get-Date -Hour 22
    #----
    #for each of the pools apply the Desktop Pool Image Update based on the above vars. 

    ##TEST
    foreach ($PoolName in $TestPools){
        .\Horizon-Push-DesktopPool-Image.ps1 -ConnectionServerURL $hvServerURL -Credentials $creds -vCenter $vCenter -DataCenterName $dcName -baseVMName $baseVM -BaseSnapShotName $snapName -DesktopPoolName $PoolName -Scheduledtime $time
    }

    ##PROD
    foreach ($PoolName in $ProdPools){
        .\Horizon-Push-DesktopPool-Image.ps1 -ConnectionServerURL $hvServerURL -Credentials $creds -vCenter $vCenter -DataCenterName $dcName -baseVMName $baseVM -BaseSnapShotName $snapName -DesktopPoolName $PoolName -Scheduledtime $time
    }

    .PARAMETER Credential
    Mandatory: No
    Type: PSCredential
    Object with credentials for the connection server with domain\username and password. If not supplied the script will ask for user and password.

    .PARAMETER StoponError
    Mandatory: No
    Boolean to stop on error or not

    .PARAMETER logoff_policy
    Mandatory: No
    String FORCE_LOGOFF or WAIT_FOR_LOGOFF to set the logoff policy. WAIT_FOR_LOGOFF by default.

    .PARAMETER Scheduledtime
    Mandatory: No
    Time to schedule the image push in [DateTime] format.

    .NOTES
    Minimum required version: VMware Horizon 8
#>
param (
    [Parameter(Mandatory=$false,
        HelpMessage='Credential object as domain\username with password')]
        [PSCredential] $Credentials,
    [Parameter(Mandatory=$true,  
        HelpMessage='URL of the ConnectionServer i.e. https://horizon.domain.net')]
        [ValidateNotNullOrEmpty()]
        [string] $ConnectionServerURL,
    [parameter(Mandatory = $true,
        HelpMessage = "Name of vCenter.")]
        [ValidateNotNullOrEmpty()]
        [string]$vCenter,
    [parameter(Mandatory = $true,
        HelpMessage = "Name of the Datacenter.")]
        [ValidateNotNullOrEmpty()]
        [string]$DataCenterName,
    [parameter(Mandatory = $true,
        HelpMessage = "Name of the Golden Image VM.")]
        [ValidateNotNullOrEmpty()]
        [string]$BaseVMname,
    [parameter(Mandatory = $true,
        HelpMessage = "Name of the Snapshot to use for the Golden Image.")]
        [ValidateNotNullOrEmpty()]
        [string]$BaseSnapShotName,
    [parameter(Mandatory = $true,
        HelpMessage = "Name of the Desktop Pool.")]
        [ValidateNotNullOrEmpty()]
        [string]$DesktopPoolName,
    [parameter(Mandatory = $false,
        HelpMessage = "Name of the Desktop Pool.")]
        [ValidateNotNullOrEmpty()]
        [bool]$StoponError = $true,
    [parameter(Mandatory = $false,
        HelpMessage = "Name of the Desktop Pool.")]
        [ValidateSet('WAIT_FOR_LOGOFF','FORCE_LOGOFF', IgnoreCase = $false)]
        [string]$logoff_policy = "WAIT_FOR_LOGOFF",
    [parameter(Mandatory = $false,
        HelpMessage = "DateTime object for the moment of scheduling the image push.Defaults to immediately")]
        [datetime]$Scheduledtime
)
if($Credentials){
    $username=($credentials.username).split("\")[1]
    $domain=($credentials.username).split("\")[0]
    $password=$credentials.password
}else{
    $credentials = Get-Credential
    $username=($credentials.username).split("\")[1]
    $domain=($credentials.username).split("\")[0]
    $password=$credentials.password
}

$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password) 
$UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

function Get-HRHeader(){
    param($accessToken)
    return @{
        'Authorization' = 'Bearer ' + $($accessToken.access_token)
        'Content-Type' = "application/json"
    }
}
function Open-HRConnection(){
    param(
        [string] $username,
        [string] $password,
        [string] $domain,
        [string] $url
    )
    $Credentials = New-Object psobject -Property @{
        username = $username
        password = $UnSecurePassword
        domain   = $domain
    }
    return Invoke-RestMethod -Method Post -uri "$ConnectionServerURL/rest/login" -ContentType "application/json" -Body ($Credentials | ConvertTo-Json)
}
function Close-HRConnection(){
    param(
        $accessToken,
        $ConnectionServerURL
    )
    return Invoke-RestMethod -Method post -uri "$ConnectionServerURL/rest/logout" -ContentType "application/json" -Body ($accessToken | ConvertTo-Json)
}

try{
    $accessToken = Open-HRConnection -username $username -password $UnsecurePassword -domain $domain -url $ConnectionServerURL
}catch{throw "Error Connecting: $_"}

$vCenters = Invoke-RestMethod -Method Get -uri "$ConnectionServerURL/rest/monitor/v3/virtual-centers" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
$vCenterID = ($vCenters | where-object {$_.name -like "*$vCenter*"}).id
$DataCenters = Invoke-RestMethod -Method Get -uri "$ConnectionServerURL/rest/external/v1/datacenters?vcenter_id=$vCenterID" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
$DataCenterID = ($datacenters | where-object {$_.name -eq $DataCenterName}).id
$BaseVMs = Invoke-RestMethod -Method Get -uri "$ConnectionServerURL/rest/external/v2/base-vms?datacenter_id=$DataCenterID&filter_incompatible_vms=false&vcenter_id=$vCenterID" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
$BaseVMid = ($basevms | where-object {$_.name -eq $BaseVMname}).id
$BaseSnapshots = Invoke-RestMethod -Method Get -uri "$ConnectionServerURL/rest/external/v2/base-snapshots?base_vm_id=$BaseVMid&vcenter_id=$vCenterID" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
$BaseSnapshotID = ($basesnapshots | where-object {$_.name -eq $BaseSnapShotName}).id
$DesktopPools = Invoke-RestMethod -Method Get -uri "$ConnectionServerURL/rest/inventory/v7/desktop-pools" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
$DesktopPoolID = ($desktoppools | where-object {$_.name -eq $DesktopPoolName}).id
$StartDate = (Get-Date -UFormat %s)
$DataHashtable = [ordered]@{}
$DataHashtable.add('logoff_policy',$logoff_policy)
$DataHashtable.add('parent_vm_id',$BaseVMid)
$DataHashtable.add('snapshot_id',$BaseSnapshotID)
if($Scheduledtime){
    $StartTime = Get-Date $ScheduledTime
    $epoch = ([DateTimeOffset]$StartTime).ToUnixTimeMilliseconds()
    $DataHashtable.add('start_time',$epoch)
}

$DataHashtable.add('stop_on_first_error',$StoponError)
$json = $DataHashtable | convertto-json

Write-Host "Update Desktop Pool '$($DesktopPoolName)' with Image '$($BaseSnapShotName)'"
Invoke-RestMethod -Method Post -uri "$ConnectionServerURL/rest/inventory/v2/desktop-pools/$DesktopPoolID/action/schedule-push-image" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken) -body $json