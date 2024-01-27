#requires -Module VMware.VimAutomation.Core
#requires -Module VMware.VimAutomation.HorizonView

$viewaddress = "LocalHost"
$ComputerName = [Net.Dns]::GetHostName()
$ComputerName = $ComputerName.ToUpper()
$HVSERVER="Horizon.Domain.net"

$output = "C:\Temp\NRI_VDI_PoolData.json"
if(!(Test-Path $output)){New-Item $output}

Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP $false -Confirm:$false | Out-Null

# Get credentials
$Credential = Import-Clixml "C:\Program Files\New Relic\newrelic-infra\custom-assets\$($ComputerName).cred"
if(!($Credential)){Write-Error "No Creds"}

$poolsAddr = "LDAP://$viewAddress/OU=Server Groups,DC=vdi,DC=vmware,DC=int"
$VMSAddress = "LDAP://$ViewAddress/OU=Servers,DC=vdi,DC=vmware,DC=int"
$poolContainer = [adsi] $poolsAddr
$VMContainer = [adsi] $VMSAddress
$poolRegistry = @{}
$poolContainer.Children | ? {$_.distinguishedName.count -gt 0} | % {$poolRegistry[$_.distinguishedName[0]] = $_}

$pools = $poolContainer.Children |
	% {New-Object PSObject -Property @{
		MaxDesktop = $_.'pae-VmMaximumCount'[0];
        Name = $_.'CN'[0];
        Enabled = $_.'pae-disabled'[0]}
      }
$poolContainer.Dispose();
$pools = $Pools | Where-Object {$_.Enabled -eq 0}

#Connect To Horizon View Server
Try {
    $Session = Connect-HVServer $HVSERVER -credential $Credential
}
Catch {
    $ErrorActionPreference = 'Stop'
    Write-Host "Could not Connect To Horizon Server: $HVSERVER, Exiting"
}

#Get All Available Machines
$AllMachines = Get-HVMachineSummary

#Get All Error State VMs
$basicErrorStates = @(
    'PROVISIONING_ERROR',
    'ERROR',
    'AGENT_UNREACHABLE',
    'AGENT_ERR_STARTUP_IN_PROGRESS',
    'AGENT_ERR_DISABLED',
    'AGENT_ERR_INVALID_IP',
    'AGENT_ERR_NEED_REBOOT',
    'AGENT_ERR_PROTOCOL_FAILURE',
    'AGENT_ERR_DOMAIN_FAILURE',
    'AGENT_CONFIG_ERROR',
    'ALREADY_USED',
    'UNKNOWN'
)
$TotalVMs=@()
foreach ($state in $basicErrorStates) {
    $ErrorVMs = Get-HVMachineSummary -State $state -SuppressInfo:$true
    $ErrorVMs | % {$TotalVMs += "$($_.Base.BasicState)"}
}
$PRV = $TotalVMs | ? {$_ -eq "PROVISIONING_ERROR"}
$AUR = $TotalVMs | ? {$_ -eq "AGENT_UNREACHABLE"}
$USD = $TotalVMs | ? {$_ -eq "ALREADY_USED"}
$UKN = $TotalVMs | ? {($_ -ne "PROVISIONING_ERROR") -and ($_ -ne "AGENT_UNREACHABLE") -and ($_ -eq "ALREADY_USED")}

#Now Break it Down
$AllAvailable = ($Allmachines | where {$_.base.basicstate -eq "AVAILABLE"})
$AllConnected = ($AllMachines | Where {$_.base.basicstate -eq "CONNECTED"})
$AllDisconnected = ($AllMachines | Where {$_.base.basicstate -eq "DISCONNECTED"})

$CorpAvailable = ($AllAvailable | Where-Object {$_.namesdata.DesktopName -like "N10_CORP*"}).count
$CorpConnected = ($AllConnected | Where-Object {$_.namesdata.DesktopName -like "N10_CORP*"}).count
$CorpDisconnected = ($AllDisconnected | Where-Object {$_.namesdata.DesktopName -like "N10_CORP*"}).count
[int]$CORPMax=0
($Pools | Where-Object {$_.Name -like "N10_CORP*"}| % {$CORPMax+= ($_.maxdesktop)})

$INCAvailable = ($AllAvailable | Where-Object {$_.namesdata.DesktopName -like "N10_INC_PCI*"}).Count
$INCConnected = ($AllConnected | Where-Object {$_.namesdata.DesktopName -like "N10_INC_PCI*"}).Count
$INCDisconnected = ($AllDisconnected | Where-Object {$_.namesdata.DesktopName -like "N10_INC_PCI*"}).Count
[int]$INCmax=0
($Pools | Where-Object {$_.Name -like "N10_INC_PCI*"}| % {$INCMax+= ($_.maxdesktop)})

$CreditAvailable = ($AllAvailable | Where-Object {$_.namesdata.DesktopName -like "N10_CR_PCI*"}).Count
$CreditConnected = ($AllConnected | Where-Object {$_.namesdata.DesktopName -like "N10_CR_PCI*"}).Count
$CreditDisconnected = ($AllDisconnected | Where-Object {$_.namesdata.DesktopName -like "N10_CR_PCI*"}).Count
[int]$Creditmax=0
($Pools | Where-Object {$_.Name -like "N10_CR_PCI*"}| % {$CreditMax+= ($_.maxdesktop)})

Disconnect-HVServer $HVSERVER -confirm:$false| out-null

$Out = New-Object System.Collections.ArrayList

[void]$Out.Add(@{
    PoolName = 'CORP';
    Site = $Site;
    Available = $CorpAvailable;
    Connected = $CorpConnected;
    Disconnected = $CorpDisconnected;
    SessionMax = $Corpmax;   
})

[void]$Out.Add(@{
    PoolName = 'INC';
    Available = $INCAvailable;
    Connected = $INCConnected;
    Disconnected = $INCDisconnected;
    SessionMax = $IncMax;   
})

[void]$Out.Add(@{
    PoolName = 'CREDIT';
    Available = $CreditAvailable;
    Connected = $CreditConnected;
    Disconnected = $CreditDisconnected;
    SessionMax = $CreditMax;
})

[void]$Out.Add(@{
    ErrorVMs           = ($TotalVMs.count);
	PROVISIONING_ERROR = ($PRV.count);
	AGENT_UNREACHABLE  = ($AUR.count);
	ALREADY_USED       = ($USD.count);
	OTHER              = ($UKN.count);
})

Set-Content $output ($Out | ConvertTo-Json)
return ($Out | ConvertTo-Json)