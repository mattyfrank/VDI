param(
    [Parameter(Mandatory=$false)][String]$avServer="appvolume.domain.net",    
    [Parameter(Mandatory=$false)][String]$cred_path = ".\creds.xml",
    $AppVol_Datastore    = 'DS_001',
    $AppVol_Path         = 'AppVolumes/apps',
    $AppVol_Datadelay    = 'true'
)
#Connect to vCenter"
if(!(Test-Path $cred_path)){
    $creds=Get-Credential -Message "Enter Creds in the format Domain\UserName"
}else{$creds = Import-Clixml -Path $cred_path}
$credentials = @{
    username = $creds.UserName
    password = $creds.GetNetworkCredential().Password
}

#Auth to AppVol and status returned
$Session = Invoke-RestMethod -UseBasicParsing -SessionVariable avSession -Method Post -Uri "https://$avServer/app_volumes/sessions" -Body $credentials

$AVDatacenter  = 'data[datacenter]'
$AVDatastore   = 'data[datastore]'
$Path          = 'data[path]' 
$Delay         = 'data[delay]'

$Body = @{
        $AVDatacenter = ''
        $AVDatastore  = $AppVol_Datastore
        $Path         = $AppVol_Path
        $Delay        = $AppVol_Datadelay
}
$Import = Invoke-WebRequest -WebSession $avSession -Method Post -Uri https://$avServer/app_volumes/app_products/import -Body $Body
Write-Host $Import.Content

Write-Output "Import Completed"