#requires -Module VMware.VimAutomation.Core
#requires -Module VMware.VimAutomation.HorizonView

$ComputerName = [Net.Dns]::GetHostName()
$ComputerName = $ComputerName.ToUpper()
$Site = ($ComputerName.Split('P')[0])
$HVSERVER="Horizon.Domain.net"

$output = "C:\Temp\NRI_VDI_uagHealth.json"
if(!(Test-Path $output)){New-Item $output}

Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP $false -Confirm:$false | Out-Null

function Get-HVUAGGatewayZone {
    param (
        [parameter(Mandatory = $true,
            HelpMessage = "Boolean for the GatewayZoneInternal property of the GatewayHealth.")]
        [bool]$GatewayZoneInternal
    )
    try {
        if ($GatewayZoneInternal -eq $False) {
            $GatewayZoneType="External"
        }
        elseif ($GatewayZoneInternal -eq $True) { 
            $GatewayZoneType="Internal"
        }
        # Return the results
        return $GatewayZoneType
    }
    catch {
        Write-Output 'There was a problem determining the gateway zone type.' $_
    }
}

#Get credentials
$Credentials = Import-Clixml "C:\Program Files\New Relic\newrelic-infra\custom-assets\$($ComputerName).cred"

# Connect to the Horizon View Connection Server
[VMware.VimAutomation.HorizonView.Impl.V1.ViewObjectImpl]$AdminSession = Connect-HVServer $HVserver -Credential $Credentials

#Get UAG Health
$uaghealthstatus=@()
[array]$uaglist=$AdminSession.extensiondata.Gateway.Gateway_List()
foreach ($uag in $uaglist){
    [VMware.Hv.GatewayHealthInfo]$uaghealth=$AdminSession.extensiondata.GatewayHealth.GatewayHealth_Get($uag.id)
    $uaghealthstatus+=New-Object PSObject -Property @{
        "Site"               = $Site
        "Name"               = $uaghealth.name;
        "Address"            = $uaghealth.address;
        "GatewayZone"        = (Get-HVUAGGatewayZone -GatewayZoneInternal ($uaghealth.GatewayZoneInternal));
        "Version"            = $uaghealth.Version;
        "Active"             = $uaghealth.GatewayStatusActive;
        "Stale"              = $uaghealth.GatewayStatusStale;
        "Contacted"          = $uaghealth.GatewayContacted;
        "Active_Connections" = $uaghealth.ConnectionData.NumActiveConnections;
        "Blast_Connections"  = $uaghealth.ConnectionData.NumBlastConnections;
        "PCOIP_Connections"  = $uaghealth.ConnectionData.NumPcoipConnections;
    }
}
$uaghealthstatus= $uaghealthstatus | select Site, Name, Address, Active_Connections, Blast_Connections, PCOIP_Connections, Active, Version, GatewayZone

#Output Data
Set-Content $output ($uaghealthstatus | ConvertTo-Json)
return ($uaghealthstatus | ConvertTo-Json)