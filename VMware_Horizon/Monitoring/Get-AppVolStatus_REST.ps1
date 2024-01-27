#Local Vars from .NET
#Get local host name
$ComputerName = [Net.Dns]::GetHostName()
$ComputerName = $ComputerName.ToUpper()
#Create site based on name
$Site         = ($ComputerName.Split('P')[0])
#Get Local FQDN
$FQDN         = [System.Net.Dns]::GetHostEntry([string]$ComputerName).HostName
$DomainName   = ([System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()).DomainName

$OutFile      = "C:\Temp\NRI_AppVol_Health.json"

#Import Creds
$cred = Import-Clixml "C:\Program Files\New Relic\newrelic-infra\custom-assets\$($ComputerName).cred"
$credentials = @{
    username = $cred.UserName
    password = $cred.GetNetworkCredential().Password
}

#Bypass Certificate misMatch
$code= @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate, WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@
Add-Type -TypeDefinition $code -Language CSharp
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

#Auth not needed to return appvol version
#$Version    = Invoke-WebRequest -UseBasicParsing -Method Get -Uri "https://$AppVolServer/app_volumes/version"
#$Version    = ($Version.Content | ConvertFrom-Json)
$Version    = Invoke-RestMethod -UseBasicParsing -Method Get -Uri "https://$FQDN/app_volumes/version"

#Auth to AppVol and status returned
$Session    = Invoke-RestMethod -UseBasicParsing -SessionVariable avSession -Method Post -Uri "https://$FQDN/app_volumes/sessions" -Body $credentials
$Disconnect = Invoke-RestMethod -UseBasicParsing -WebSession $avSession -Method Delete -Uri "https://$FQDN/app_volumes/sessions"

#Format Output
$AppVolData = New-Object psobject -Property @{
    "Site"    = $Site;
    "Name"    = $ComputerName
    "Status"  = $Session.success
    "Version" = $Version.version
    "Uptime"  = $Version.uptime
}
$output = ($AppVolData | ConvertTo-Json)

Set-Content $OutFile $output
return $output

#Get App Volume Activity
#$results = (Invoke-WebRequest -WebSession $avSession -Method Get -Uri "https://$AppVolServer/app_volumes/activity_logs" -ContentType 'application/json').Content | ConvertFrom-Json
#$logs = ($results.actlogs.logs)

# #Get All App Volumes
# $results = (Invoke-WebRequest -WebSession $avSession -Method Get -Uri "https://$AppVolServer/app_volumes/app_products/" -ContentType 'application/json').Content| ConvertFrom-Json

# $Apps = $results.data | % {Write-Output $_.name} | ConvertTo-Json
# $App_Packages = $results.data | % {Write-Output $_.app_packages} | % {Write-Output $_.name} | ConvertTo-Json
