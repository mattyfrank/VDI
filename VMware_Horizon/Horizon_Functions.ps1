<#
.SYNOPSIS
Horizon Functions

.DESCRIPTION
Functions for repeat Horizon tasks. Log Off Sessions, Reclaim Dedicated VMs, Enter MaintenanceMode, ..

.COMPONENT
#Install PowerCLI "Install-Module -Name Vmware.PowerCLI"
#Offline Installation files are here - https://developer.vmware.com/web/tool/vmware-powercli

#Install Horizon Vew 
Get-Module VMware.VimAutomation.HorizonView -ListAvailable | Import-Module -Verbose

#Install Horizon Helper Scripts
#Click Code and Download ZIP "https://github.com/vmware/PowerCLI-Example-Scripts"
#Extract ZIP, and locate "PowerCLI-Example-Scripts-master\Modules\VMware.Hv.Helper"
#Copy entire folder to PS Module Path. If necessary unblock the downloaded files.
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$WorkingDir = "C:\Temp"
cd $WorkingDir
$Output = "PowerCLI-Scripts"
Invoke-WebRequest -Uri "https://github.com/vmware/PowerCLI-Example-Scripts/archive/refs/heads/master.zip" -OutFile "$Output.zip"
Expand-Archive "$Output.zip"
cd "$WorkingDir\$Output\PowerCLI-Example-Scripts-master\Modules"
##Get-ChildItem * -Recurse | Unblock-File
##$Env:PSModulePath
Copy-Item -Path ".\VMware.Hv.Helper" -Destination "C:\Program Files\WindowsPowerShell\Modules" -Recurse -Force
Get-Module -ListAvailable 'Vmware.Hv.Helper' | Import-Module 

Disable Customer Feedback "Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP $false -Confirm:$false"

.EXAMPLE
.\HorizonFunctions.ps1 -Clear-OldSessions -Session-Age 12 
. .\HorizonFunctions.ps1 Reset-OldVMs

.\Horizon_Functions.ps1 -HVserver Horizon.Domain.net -RemoveVMs

.NOTES
Exception List has been provided too allow for future exceptions.
    Version: 0.1
    Company: DOMAIN.com
    Author: Matthew.Franklin
    Date: 06/01/2022
Functions Renamed to support approved verbs.
Add functions to handle 'Deleting VMs'&'Old VMs'.
Add function for Errored VMs
    Version: 0.2
    Company: DOMAIN.com
    Author: Matthew.Franklin
    Date: 02/16/2023
Update functions to use Write-Host and instead of Write-Output
Refactored connections to vCenter and Horizon
Move extra scripts to #Region Scratch#
    Version: 0.4
    Date: 09/01/2023
#>

param (
    [string][ValidateSet("MyHorizon1.DOMAIN.net","MyHorizon2.DOMAIN.net")]$HVserver, 
    [switch]$ClearSessions, 
    [int]$SessionAge='12',
    [switch]$ClearDeletingVMs,
    [switch]$ClearOldVMs,
    [switch]$ClearErrorVMs,
    [switch]$RemoveVMs, 
    [string]$LogPath= ".\Logs", 
    [string]$CredPath= ".\creds.xml",
    [string][ValidateSet("vCenter1.DOMAIN.net","vCenter2.DOMAIN.net","vCenter3.DOMAIN.net")]$vCenter,
    [switch]$Test
)

#Region Variables
if ($HVserver -eq "MyHorizon1.DOMAIN.net"){$Vcenter= "vCenter1.DOMAIN.net"}
if ($HVserver -eq "MyHorizon2.DOMAIN.net"){$Vcenter= "vCenter2.DOMAIN.net"}
#EndRegion

#Install Modules if needed. 
if (!(Get-Module VMware.PowerCLI -ListAvailable)) {
    Install-Module -Name VMware.PowerCLI -AllowClobber -Force -Confirm:$false | Out-Null
    Import-Module -Name VMware.PowerCLI
    Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP $false -Confirm:$false
}
if (!(Get-Module VMware.VimAutomation.HorizonView  -ListAvailable)) {
    Install-Module -Name VMware.VimAutomation.HorizonView -Force  | Out-Null
    Import-Module -Name VMware.VimAutomation.HorizonView
}
if (!(Get-Module Vmware.Hv.Helper)) {
    Import-Module -Name Vmware.Hv.Helper
}
#InstallRSAT Tools
$Win_OS_Type = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").InstallationType
if ($Win_OS_Type -eq "Server"){
    #Write-Host "Windows Server detected"
    if ((Get-WindowsFeature RSAT-AD-PowerShell).InstallState -ne "Installed"){
        Write-Host "Try to install RSAT"
        #Import-Module ServerManager 
        Add-WindowsFeature -Name "RSAT-AD-PowerShell" –IncludeAllSubFeature
    }
}
if ($Win_OS_Type -eq "Client"){
    #Write-Host "Windows client detected"
    if ((Get-WindowsCapability -Name "Rsat.ActiveDirectory.DS-LDS.Tools*" -Online).State -ne "Installed"){
        Write-Host "Try to install RSAT"
        $AD = Get-WindowsCapability -Name "Rsat.ActiveDirectory.DS-LDS.Tools*" -Online 
        Add-WindowsCapability -Online -Name $AD.Name
    }
}

#Region Functions

function Test-CredFile {
    param([string]$CredPath = $CredPath)
    if (!(Test-Path $CredPath)) {
         Write-Host "Cred file is missing"
         $Creds = (Get-Credential -Message "Domain\ServiceAccount")
         $Creds | Export-Clixml -Path $CredPath
    } 
    else {$Creds = Import-Clixml -Path $CredPath}
    try {
        $Username = $Creds.username
        $Password = $Creds.GetNetworkCredential().password
        $Root = "LDAP://" + ([ADSI]'').distinguishedName
        $Domain = New-Object System.DirectoryServices.DirectoryEntry($Root,$UserName,$Password)
        if(!($Domain)) {Write-Error "Something went wrong"}
        else {
            if (@($Domain.name)){Write-Host "Creds are Valid"}
            else{
                Write-Host "$($CredPath) is no longer valid! Deleting old cred file..."
                Remove-Item $CredPath -Force -Confirm:$false
                Write-Host "Creating cred file..."
                $Credentials = (Get-Credential -Message "DOMAIN\ServiceAccount")
                $Credentials | Export-Clixml -Path $CredPath
            }
        }
    }catch {Write-Error $_}
}

#Import Creds and Connect to Horizon Server. Also connects to vCenter if called...
function Connect-Admin {
    param($CredPath,$HVServer,$vCenter)
    Write-Host "Import Credentials"
    If(!(Test-Path $CredPath)){Write-Host "Missing Cred File";break
    }else{
        Try{$Credentials = Import-Clixml -Path $CredPath}
        Catch{Write-Host "Failed to import cred file $($CredPath)"; exit}
    }
    Write-Host "Connect to Horizon"
    Try{$AdminSession = Connect-HVServer $HVserver -Credential $Credentials}
    Catch{Write-Host "Could not connect To Horizon Server: $HVserver, Exiting"; exit}

    if(@($vCenter)){
        #ignore security certificates are invalid
        Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
        Write-Host "Connect to vCenter"
        Try{Connect-VIServer $vCenter -Credential $Credentials | Out-Null}
        Catch{Write-Host "Could not connect To vCenter: $($vCenter), Exiting"; exit} 
    }
    return $AdminSession
}

#Sessions over an age will be forced to log off and delete the vm 
function Clear-OldSessions {
    param([int]$MaxSessionAge)
    if(!($MaxSessionAge)){$MaxSessionAge = 12}
    $failedSessions = @()
    Write-Host "LogOff Sessions initiated over '$($MaxSessionAge)' hours ago."
    Write-Host "Get all sessions..."
    $sessions  = (Get-HVLocalSession)
    Write-Host "Get all pools with FLOATING assignments..."
    $pools     = (Get-HVPool -UserAssignment FLOATING -Verbose)
    #$poolNames = $pools.base.displayname
    if ($sessions -eq 0){Write-Error "No Sessions Found";break}
    foreach ($session in $sessions) {
        #only take action on UserSessions that are Floating assignments. 
        if ($session.NamesData.DesktopName -in $pools.base.Name){
            [int]$sessionAge = (New-TimeSpan -Start $session.SessionData.StartTime).TotalHours
            if ($sessionAge -gt $MaxSessionAge){
                #create vars for the session data
                $sessionId   = $session.Id
                $userName    = $session.NamesData.UserName
                $machineName = $session.NamesData.MachineOrRDSServerName
                $machineId   = $((Get-HVMachine -MachineName $machineName).Id)
                Write-Host `n"'$($userName)' has been connected to '$($machineName)' for '$($sessionAge)' hours."
                Write-Host "Session Start Time: $($session.SessionData.StartTime)"
                try{
                    Write-Host "Try to log off session. Current Time: $(get-date -Format MM/dd/yy_HH:mm:ss)"
                    if(!($test)){$AdminSession.ExtensionData.Session.Session_Logoff($sessionId)}
                    else{Write-Host "Testing:Session_LogOff"}
                }
                    #LogOff         $AdminSession.ExtensionData.Session.Session_Logoff($sessionId)
                    #ForcedLogOff   $AdminSession.ExtensionData.Session.Session_LogoffForced($sessionId)
                    #RecoverVM      $AdminSession.ExtensionData.Machine.Machine_Recover($machineId)
                catch{
                    Write-Host "Failed to logoff. Force logoff and Delete VM."
                    if (!($test)){
                        $deletespec = (New-Object VMware.Hv.machineDeleteSpec)
                        $deletespec.DeleteFromDisk=$true ; $deletespec.ForceLogoffSession=$true
                        $AdminSession.ExtensionData.Machine.Machine_Delete($machineId,$deletespec)
                    }
                    else{Write-Host "Testing:ForceLogOffSession & Machine_Delete"}
                }
            }
            #create list of VMs with failed sessions over 24 hours
            if ($sessionAge -ge 24){$failedSessions += $machineName}
        }
    }
    #Power Off Failed Sessions
    if ($failedSessions -gt 0) {
        Write-Host `n "Power Off VMs with Sessions older than 24 hours..."
                foreach ($x in $failedSessions) {
            try {
                Write-Host `n "Get VM named '$($x)'"
                $VM = (Get-VM -Name $x)
                if(!($VM)){Write-Host "VM '$($x)' not found!"}
                else{
                    Write-Host "PowerOff $($VM.Name). CurrentTime:$(get-date -Format dd-MM-yy.hh:mm:ss)"`n
                    if(!($test)){Stop-VM -VM $VM -Confirm:$false | Out-Null}
                    else{Write-Host "Testing:Stop-VM"}
                }
            }
            catch{Write-Error "$($VM) failed to power off!" $_}
        }
   }
}
     
#Gracefully Shutdown VMs stuck in a Deleting state.
function ShutDown-DeletingVMs {
    $DeletingVMs = (Get-HVMachine -State DELETING)
    if ($DeletingVMs -eq 0){Write-Host "No VMs in Deleting state.";break}
    else {
        foreach ($x in $DeletingVMs){
            $VMName = $($x.Base.Name)
            $VM = (Get-HVMachine -MachineName $VMName)
            if (!($VM)){Write-Information "Cannot find $($VMName)" -InformationAction Continue}
            else {
                #gracefully shutdown vm
                try {
                    Write-Host "Attempting to ShutDown $($VMName)"
                    if(!($test)){
                        Shutdown-VMGuest -VM $VMName -Confirm:$false | Out-Null
                        Start-Sleep -Seconds 10
                    }
                    else{Write-Host "Testing:ShutdownVMGuest"}
                }
                catch {Write-Host "ShutDown Failed."}
            }
        }
    }
}

#Reset Available VMS that are members of FLOATING Pools that were created over 1 day ago. 
function Reset-OldVMs {
    Write-Host "Get Desktop Pools with Floating Assignmnents."
    $pools   = (Get-HVPool -UserAssignment FLOATING -Verbose)
    #$time    = $((Get-Date).AddMinutes(-30))
    #$time    = $((Get-Date).AddHours(-1))
    $time    = $((Get-Date).AddDays(-1))
    Write-Host "Get VMs that were created before '$time'."
    $oldVMs  =  Get-HVMachine -State Available | Where-Object {$_.ManagedMachineData.CreateTime -lt $time}
    if($oldVMs -eq 0){Write-Host "No old machines";exit}
    foreach ($vm in $oldVMs){
        if($vm.Base.DesktopName -in $pools.base.Name){
            Write-Host "Remove HV Machine $($vm.base.name)"
            if(!($test)){
                Remove-HVMachine $vm.base.name -DeleteFromDisk -Confirm:$false
            }
            else{Write-Host "Testing:Remove-HVMachine"}
        }
    }
}

#Delete VMs that are in an Error State. 
function Reset-ErrorVMs {
    $basicStates = @(
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
    $ErrorVMs=@()
    Write-Host "Search floating pools for VMs in the following states:"; $basicStates
    Write-Host `n
    $floatingPools = (Get-HVPool -UserAssignment FLOATING -Verbose).base.name
    foreach ($pool in $floatingPools){
        #Write-Host "Search for Problem VMs in '$($pool)' Pool"
        foreach ($state in $basicStates) {
            #Write-Host "Search for VMs in '$($state)' State"
            $ProblemVMs = Get-HVMachineSummary -State $state -PoolName $pool -SuppressInfo:$true
            if($ProblemVMs.Count -gt 0){
                #for each vm in $problemVMs, add the name to the $ErrorVM list
                $ProblemVMs | % {$ErrorVMs += "$($_.Base.Name)"}
            }
        }
    }
    Write-Host `n"Problem VMs: $($ErrorVMs.Count)"
    foreach ($VM in $ErrorVMs) {
        Write-Host "Reboot VM '$($VM)'"
        Remove-HVMachine -MachineNames $($VM) -DeleteFromDisk:$true -Confirm:$false 
        #Restart-VMGuest -VM $VM
    }
}

#Get VMs whose assigned userName is Missing or Disabled in the Domain
#RSAT Required
function Get-MachinesToRemove {
    [System.Collections.ArrayList]$results = @()
    #Report for Missing/Disabled Users of DEDICATED Pools
    $reportPath = "D:\Horizon\Reports\$(Get-Date -f yyyy.MM.dd)_MachinesToDelete.csv"
    if(!(Test-Path $reportPath)){Add-Content -Value "UserName,MachineName,PoolName" -Path $reportPath}
    #Write-Host "Get Pools with Dedicated User Assignments"
    $DedicatedPools = (Get-HVPool -UserAssignment DEDICATED -Verbose)
    #select Unique IDs
    $DedicatedPools = $DedicatedPools | Sort-Object {$($_.Id).Id} -Unique
    Foreach ($Pool in $DedicatedPools){
    #Write-Host "$($Pool.base.DisplayName)"
    $MachineData = Get-HVMachineSummary -poolname $($Pool.base.Name) | Select-Object -Property `
                                    @{Name = 'MachineName'; Expression = {$_.base.name}},
                                    @{Name = 'User'; Expression = {$_.namesdata.username}},
                                    @{Name = 'Pool'; Expression = {$_.namesdata.desktopname}}

    #Write-Host "$($Pool.base.Name) has $($MachineData.count) VMs."
    #Write-Host "Remove Null Values (Machines without Users Assigned)"
    $MachineData = $MachineData | Where-Object user -ne $null
    #Write-Host "$($Pool.base.Name) has $($MachineData.count) VMs already assigned to users."
    foreach ($machine in $MachineData){
        #format the names
        [string]$userName = $($machine.user).split("\")[1]
        [string]$machineName = $machine.MachineName
        [string]$poolName = $machine.Pool
        #Search AD for UserName
        try {
            $obj = (Get-ADUser $userName -Properties Enabled)
        }catch {
            #Write-Host "$($userName) not found in domain"
            Add-Content -Value "$userName,$machineName,$poolName" -Path $reportPath
            $value=[pscustomobject]@{'userName'= $userName;'machineName'= $machineName; 'state'="missing"}
            $results.Add($value) | Out-Null
            $value=$null
        }
            if ($obj.Enabled -eq $false){
                #Write-Host "$($userName) is disabled"
                #Store UserName and machineName in array
                $value=[pscustomobject]@{'userName'= $userName;'machineName'= $machineName; 'state'="disabled"}
                $results.Add($value) | Out-Null
                $value=$null
                #export results to report
                Add-Content -Value "$userName,$machineName,$poolName" -Path $reportPath
            }
        }
    #Filter based on values created above.
    #$MachinesToRemove = $MachineData | Where-Object {($_.user_exists -eq "No") -or ($_.user_disabled -eq "Yes")}
    #[int]$count = $($MachinesToRemove.Count)
    #Write-Host "$($Pool.base.Name) has '$($count)' machines to delete."`n
    }  
    return $results
}

#EndRegion Functions

#Region Main 

$AdminSession = Connect-Admin -CredPath $CredPath -HVServer $HVServer -vCenter $vCenter

#Run Daily
if($ClearSessions){
    if(!($Test)){Start-Transcript -Path "$LogPath\$(Get-Date -f yyyy-MM-dd.hh.mm)_$($HVServer)_ClearOldSessions.txt"}
    else{Start-Transcript -Path "$LogPath\$(Get-Date -f yyyy-MM-dd.hh.mm)_$($HVServer)_ClearOldSessions-TEST.txt"}
        #call function to log off old sessions
    Clear-OldSessions -MaxSessionAge $SessionAge
        Stop-Transcript
}

#Run Daily
if($ClearDeletingVMs){
    if(!($Test)){Start-Transcript -Path "$LogPath\$(Get-Date -f yyyy-MM-dd.hh.mm)_$($HVServer)_ClearDeletingVMs.txt"}
    else{Start-Transcript -Path "$LogPath\$(Get-Date -f yyyy-MM-dd.hh.mm)_$($HVServer)_ClearDeletingVMs-TEST.txt"}
    #Gracefully Shutdown VMs in a Deleting State
    ShutDown-DeletingVMs
        Stop-Transcript
}

#Run Daily
if($ClearOldVMs){
    if(!($Test)){Start-Transcript -Path "$LogPath\$(Get-Date -f yyyy-MM-dd.hh.mm)_$($HVServer)_ClearOldVMs.txt"}
    else{Start-Transcript -Path "$LogPath\$(Get-Date -f yyyy-MM-dd.hh.mm)_$($HVServer)_ClearOldVMs-TEST.txt"}
        #call function to reset old vms
    Reset-OldVMs
        Stop-Transcript
}

#Run Daily
if($ClearErrorVMs){
    if(!($Test)){Start-Transcript -Path "$LogPath\$(Get-Date -f yyyy-MM-dd.hh.mm)_$($HVServer)_ClearErroredVMs.txt"}
    else{Start-Transcript -Path "$LogPath\$(Get-Date -f yyyy-MM-dd.hh.mm)_$($HVServer)_ClearErroredVMs-TEST.txt"}
        #call function to reset errored vms
    Reset-ErrorVMs
        Stop-Transcript
}

#Run Twice a Month 
if($RemoveVMs){
    if(!($Test)){Start-Transcript -Path "$LogPath\$(Get-Date -f yyyy-MM-dd.hh.mm)_$($HVServer)_RemoveVMs.txt"}
    else{Start-Transcript -Path "$LogPath\$(Get-Date -f yyyy-MM-dd.hh.mm)_$($HVServer)_RemoveVMs-TEST.txt"}
    Write-Host "Get list of Dedicated VMs where the user account is missing from the domain."
    $VMs = Get-MachinesToRemove
    foreach ($x in $VMs){
        Write-Host `n"The user account '$($x.UserName)' that is assigned to VM '$($x.machineName)' is $($X.state) in the domain."
        $vm = (Get-HVMachine -MachineName $x.MachineName)
        if(!($vm)){Write-Information "Missing VM...";break}
        #Delete any VMs that are already Powered_Off and in MaintMode
        if ($($VM.ManagedMachineData.VirtualCenterData.VirtualMachinePowerState) -eq "POWERED_OFF"){
            Write-Host "$($vm.base.Name) is $($VM.ManagedMachineData.VirtualCenterData.VirtualMachinePowerState)"
            if($($VM.ManagedMachineData.InMaintenanceMode) -eq $true){
                Write-Host "$($vm.base.Name) is already in Maintenance Mode."
                if(!($test)){
                    Write-Host "Deleting VM: $($vm.base.Name)"
                    try{Remove-HVMachine -MachineNames $($vm.base.Name) -DeleteFromDisk:$true -Confirm:$false}
                    catch{Write-Information "$($vm.base.Name) failed to delete!"}
                }else{Write-Host "Testing:Remove-HVMachine_DeleteFromDisk"}
            }
        }
        #Enter Maintenance Mode
        if($($VM.ManagedMachineData.InMaintenanceMode) -eq $false){
            if(!($test)){
                Write-Host "Set $($vm.base.Name) to Maintenance Mode"
                try{Set-HVMachine -MachineName $($vm.base.Name) -Maintenance ENTER_MAINTENANCE_MODE}
                catch{Write-Host "$($vm.base.Name) failed to enter MaintMode!"}
            }else{Write-Host "Testing: EnterMaintenanceMode"}
        }
        #Power off any running VM
        if ($($VM.ManagedMachineData.VirtualCenterData.VirtualMachinePowerState) -eq "POWERED_ON"){
            Write-Host "$($vm.base.Name) is $($VM.ManagedMachineData.VirtualCenterData.VirtualMachinePowerState)"
            if (!($test)){
               try {
                Write-Host "Shutting VM '$($x.MachineName)' down."
                Shutdown-VMGuest -VM $($vm.base.Name) -Confirm:$false | Out-Null
               }catch{
                    Write-Host "VM Failed to Shutdown Gracefully, Hard Power Off"
                    Stop-VM -VM $($vm.base.Name) -Confirm:$false | Out-Null
               }
            }else{Write-Host "Testing:ShutDown-VMGuest"}
        } 
    }
        Stop-Transcript
}

Write-Host "Disconnect $($HVServer) & $($vCenter)"
Disconnect-HVServer $HVserver -Confirm:$false -Force
Disconnect-VIServer $vCenter -Confirm:$false

#Cleanup Snapshot Logs Older Than 60 Days
$OldLogFiles = Get-ChildItem -path $LogPath -Recurse -Force | Where-Object {!$_.PSIsContainer -and $_.LastWriteTime -lt (Get-Date).AddDays(-60)}
$OldLogFiles | Remove-Item -Force

#EndRegion Main




#Region SCRATCH
<#
#Recover the VM.
$AdminSession.ExtensionData.Machine.Machine_Recover($VM.Id)

#Create PS Object and store values for deletion
$deletespec= (New-Object VMware.Hv.machineDeleteSpec)
$deletespec.DeleteFromDisk=$true
$deletespec.ForceLogoffSession=$true
$AdminSession.ExtensionData.Machine.Machine_Delete($VM.Id,$deletespec)

#List all Horizon Pools in the site
$pools = Get-HVPool; $pools = $pools | sort -Property $($_.BASE.NAME)
Write-Output "Horizon has '$($pools.Count)' pools. `nList of Horizon Pools:`n";foreach ($pool in $pools){Write-Output $Pool.base.Name}

#Get Horizon VMs that are in MaintMode
$mmvms = Get-HVMachine -State MAINTENANCE
foreach ($X in $mmvms){Write-Output $($x.base.name)}

#>
#EndRegion SCRATCH