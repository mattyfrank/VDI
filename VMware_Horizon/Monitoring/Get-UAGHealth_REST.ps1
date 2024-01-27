#Local Vars from .NET
#Get local host name
$ComputerName = [Net.Dns]::GetHostName()
$ComputerName = $ComputerName.ToUpper()
#Create site based on name
$Site         = ($ComputerName.Split('P')[0])
#Get Local FQDN
$FQDN         = [System.Net.Dns]::GetHostEntry([string]$ComputerName).HostName

$OutFile      = "C:\Temp\NRI_VDI_uagHealth.json"

#format access token
function Get-HRHeader(){
    param($accessToken)
    return @{
        'Authorization' = 'Bearer ' + $($accessToken.access_token)
        'Content-Type' = "application/json"
    }
}

function Get-uagGatewayZone {
    param ([parameter(Mandatory=$true,HelpMessage="bool for GatewayZone")][bool]$GatewayZoneInternal)
    try {
        if($GatewayZoneInternal -eq $False){$GatewayZoneType="External"}
        elseif($GatewayZoneInternal -eq $True){$GatewayZoneType="Internal"}
        return $GatewayZoneType
    }catch {Write-Output 'There was a problem determining the gateway zone type.' $_}   
}

#get creds
$Cred = Import-Clixml "C:\Program Files\New Relic\newrelic-infra\custom-assets\$($ComputerName).cred"
$credentials = @{
    domain   = $($cred.UserName).Split("\")[0] 
    username = $($cred.UserName).Split("\")[1]
    password = $($cred.GetNetworkCredential()).Password
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

#login
$Session = Invoke-RestMethod -UseBasicParsing -Method Post -Uri "https://$FQDN/rest/login" -ContentType "application/json" -Body ($credentials|ConvertTo-Json)

$uagHealth=@()
$Health  = Invoke-RestMethod -UseBasicParsing -Method Get -Uri "https://$FQDN/rest/monitor/v3/gateways" -Headers (Get-HRHeader -accessToken $Session) 
$Health   | % { 
    $uagHealth+=New-Object PSObject -Property @{
        "Site"               = $Site
        "Name"               = $_.name;
        "Address"            = $_.details.address;
        "GatewayZone"        = (Get-uagGatewayZone ($_.details.internal));
        "Version"            = $_.details.version;
        "Status"             = $_.status;
        "Active_Connections" = $_.active_connection_count
    }
}
$output = ($uagHealth | ConvertTo-Json)

#logout
Invoke-RestMethod -UseBasicParsing -Method Post -Uri "https://$FQDN/rest/logout" -ContentType "application/json" -Body ($Session|ConvertTo-Json)

Set-Content $OutFile $output 
return $output
