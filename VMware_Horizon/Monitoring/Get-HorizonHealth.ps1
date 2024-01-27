#requires -Module VMware.VimAutomation.Core
#requires -Module VMware.VimAutomation.HorizonView

$ComputerName = [Net.Dns]::GetHostName()
$ComputerName = $ComputerName.ToUpper()

$HVSERVER="Horizon.Domain.net"

$output = "C:\Temp\NRI_VDI_HorizonHealth.json"
if(!(Test-Path $output)){New-Item $output}

if(!(Get-Module Vmware.Hv.Helper)){Import-Module -Name Vmware.Hv.Helper -DisableNameChecking}
Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP $false -Confirm:$false | Out-Null

function Get-Uptime {
    $os = Get-WmiObject win32_operatingsystem
    $uptime = (Get-Date) - ($os.ConvertToDateTime($os.lastbootuptime))
    Write-Output "$($Uptime.Days) Days, $($Uptime.Hours) Hours, $($Uptime.Minutes) Minutes" 
}

#Get credentials
$Credentials = Import-Clixml "C:\Program Files\New Relic\newrelic-infra\custom-assets\$($ComputerName).cred"

# Connect to the Horizon View Connection Server
[VMware.VimAutomation.HorizonView.Impl.V1.ViewObjectImpl]$Session = Connect-HVServer $HVserver -Credential $Credentials

#Get Health of Horizon Connection Servers
$health = Get-HVHealth
$healthList =@()
foreach ($item in $health){
    $healthList +=New-Object PSObject -Property @{
        "CertificateValid" = $item.CertificateHealth.Valid;
        "Name"             = $item.Name;
        "Status"           = $item.Status;
        "Version"          = $item.Version
        "Uptime"           = $(Get-Uptime)
    }
}

Set-Content $output ($healthList | ConvertTo-Json)
return ($healthList | ConvertTo-Json)