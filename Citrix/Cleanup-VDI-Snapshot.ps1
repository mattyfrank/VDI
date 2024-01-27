##Cleanup VDI Snapshots
##Prompts User to confirm snapshot removal.

connect-viserver vdi_vCenter.DOMAIN.net 

$age="365"
$snapshots = get-vm "*" | Get-Snapshot | Where-Object {$_.Created -lt (Get-Date).AddDays(-$age)}

foreach ($vm in $snapshots) {
    If (!($Test)) {
        
        if ($vm.vm.name -notin $tags.name) {
            $diskspace += $vm.SizeGB
            Write-Output `n
            Write-Output "VM Name: $($vm.vm.name)"
            Write-Output "Snapshot Name: $($vm.name)"
            Write-Output "Snapshot Created: $($vm.created)"
            Write-Output "Snapshot Size: $($vm.SizeGB)"
            
            ##Prompt to delete snapshot
            Write-Host `n
            $userInput = read-host “Press y to Delete Snapshot...”
            If ($userInput -eq 'y') {
            Remove-Snapshot -Snapshot $vm -Confirm:$false
            Write-Output "Snapshot $($vm.name) has been removed."
            }
        
        } else {
            Write-Output `n
            Write-Output "VM excluded: $($vm.vm.name)"
            Write-Output "Snapshot excluded: $($vm.name)"
        }
    
    } else {Write-host "testing, did not delete snapshot."}
} 


#List all recovered/recoverable space
If((get-snapshot -vm *) -ne $null){
    Write-Output "-----------------"
    Write-Output "Recoverable space in gb: $($diskspace | % {$_.ToString("#.##")})"
    Write-Output ""
    Write-Output "-----------------"
}
Else{Write-Output "No Snapshots to clean up."}


$FolderSnapshots = Get-folder coe-staff | get-vm * | get-snapshot 

$LargeSnapshots = get-vm "*" | Get-Snapshot | Where-Object {$_.SizeGB -ge "64"}

