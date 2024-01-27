$SnapshotName = "XYZ"
$DC1 = "vCenter1.DOMAIN.net"
$DC2 = "vCenter2.DOMAIN.net"

function New-Snap {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True)][string] $VM,
        [Parameter(Mandatory=$True)][string] $SnapshotName
    )
    $VMobj = (Get-VM $VM)
    if ($VMobj.ExtensionData.Runtime.PowerState -like "PoweredON"){Shutdown-VMGuest $VMobj -Confirm:$false | Out-Null}
    Write-Host "Waiting on $($VMobj.Name) to PowerOff";Start-Sleep -Seconds 20
    while ($VMobj.ExtensionData.Runtime.PowerState -like "PoweredON"){Write-Host "$VM is PoweredON"; start-sleep -Seconds 10; $VMobj=(Get-VM $VM)}
    start-sleep -Seconds 5
    if ($VMobj.ExtensionData.Runtime.PowerState -like "poweredOff"){New-Snapshot $VMobj -Name $SnapshotName | out-null}
    $Snapshot = (Get-VM $VMobj | Get-Snapshot)
    Write-Host "$VM has $Snapshot"
}

function Remove-Snap {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ([Parameter(Mandatory=$True)][string] $VM)
    $VMobj = (Get-VM $VM)
    $snapshot = ($VMobj | Get-Snapshot)
    if(($snapshot.count) -gt '0'){
        Write-Host "Removing snapshot '$($snapshot.Name)' from $VM."
        Remove-Snapshot -Snapshot $snapshot -Confirm:$false  
    }
    $snapshot = ($VMobj | Get-Snapshot)
    if(($snapshot.count) -gt '0'){Write-Host "$VM has snapshot '$($Snapshot.Name)'"}
    else{Write-Host "No Snapshots Found on $VM"}
}

function Start-VirtualMachine {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ([Parameter(Mandatory=$True)][string] $VM)
    $VMobj = (Get-VM $VM)
    if ($VMobj.ExtensionData.Runtime.PowerState -like "PoweredOff"){
        Write-Host -ForegroundColor DarkYellow "Starting VM: $($VM)"
        $VMobj | Start-VM  | Out-Null
        while ($VMobj.Guest.State -notlike "Running"){
            $VMobj = (Get-VM $VM)
            Write-Host -ForegroundColor DarkYellow "Waiting on $VM to start..."
            Start-Sleep -Seconds 30
        }
    } 
    else {Write-Host -ForegroundColor DarkRed "VM already powered on"}
    Write-Host -ForegroundColor DarkYellow "'$VM' is $($VMobj.Guest.State)."
}

Connect-VIServer -Server DC1
$DC1VMs = Get-Folder Citrix | Get-VM | where {($_.Name -like "DC1-xd7-*") -or  ($_.Name -like "mycloud-store*") -or ($_.Name -like "DC1-xd7-lic*")}

####CREATE SnapShot####
foreach ($VM in $DC1VMs) {
    $VM = $VM.Name
    New-Snap -VM $VM -SnapshotName $SnapshotName
    Start-VirtualMachine -VM $VM
}
Disconnect-VIServer -Server DC1 -Confirm:$false

####################

####REMOVE SnapShot####
foreach ($VM in $DC1VMs) {
    $VM = $VM.Name
    Remove-Snap -VM $VM
}
Disconnect-VIServer -Server DC1 -Confirm:$false

#####CREATE SnapShot####
Connect-VIServer -Server $DC2
$DC2VMs = Get-Folder Citrix | Get-VM | where {($_.Name -like "DC2-xd7-*") -or  ($_.Name -like "DC2-store*")}
foreach ($VM in $DC2VMs) {
    $VM = $VM.Name
    New-Snap -VM $VM -SnapshotName $SnapshotName
    Start-VirtualMachine -VM $VM
}
Disconnect-VIServer -Server $DC2 -Confirm:$false

####################

#####REMOVE SnapShot####
foreach ($VM in $DC2VMs) {
    $VM = $VM.Name
    Remove-Snap -VM $VM
}
Disconnect-VIServer -Server $DC2 -Confirm:$false


<# SCRATCH
$DDC = (Get-Folder Controllers | Get-VM * | where {$_.Name -like ""})
$StoreFront = (Get-Folder StoreFront | Get-VM * | where {$_.name -like "mycloud-store*"} )
DC1VMs = (Get-Folder LicenseServers | Get-VM * | where {$_.Name -like "VDI_DC1-xd7-lic*"})
#>
