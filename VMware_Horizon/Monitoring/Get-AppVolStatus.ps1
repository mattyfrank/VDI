$ComputerName = [Net.Dns]::GetHostName()
$ComputerName = $ComputerName.ToUpper()
$AppVolServer = "AppVolumes.Domain.net"

$cred = Import-Clixml "C:\Program Files\New Relic\newrelic-infra\custom-assets\$($ComputerName).cred"
$credentials = @{
    username = $cred.UserName
    password = $cred.GetNetworkCredential().Password
}

#Auth not needed to return appvol version
$Version = Invoke-WebRequest -UseBasicParsing -Method Get -Uri "https://$AppVolServer/app_volumes/version"
$Version = ($Version.Content | ConvertFrom-Json)
#Auth to AppVol and status returned
$Session = Invoke-WebRequest -UseBasicParsing -Method Post -Uri "https://$AppVolServer/app_volumes/sessions" -Body $credentials -SessionVariable avSession
$Session = ($Session.content | ConvertFrom-Json)
$Disconnect = Invoke-RestMethod -UseBasicParsing -WebSession $avSession -Method Delete -Uri "https://$AppVolServer/app_volumes/sessions"
#Format Output
$AppVolData = New-Object psobject -Property @{
    "Name"    = $ComputerName
    "Status"  = $Session.success
    "Version" = $Version.version
    "Uptime"  = $Version.uptime
}
$output = ($AppVolData | ConvertTo-Json)

Set-Content "C:\Temp\NRI_AppVol_Health.json" $output
return $output
