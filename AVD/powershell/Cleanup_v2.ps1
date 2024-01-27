param(
    [Parameter(Mandatory=$true)][string]$ResourceGroupName,
    [Parameter(Mandatory=$true)][string]$HostPool,
    [Parameter(Mandatory=$true)][string]$VMName
)
#Remove from HostPool
$SessionHost = Get-AzWvdSessionHost -HostPoolName $HostPool -Name $VMName -ResourceGroupName $ResourceGroupName
if(!($SessionHost)){Write-Information"No SessionHost found"}
Remove-AzWvdSessionHost -HostPoolName $HostPool -Name $VMName -ResourceGroupName $ResourceGroupName
#Delete Azure resources
$vmName = ($VMName.split('.')[0])
$VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName
Remove-AzVM -ResourceGroupName $ResourceGroupName -Name $VM.Name -Force
if($vDisk = Get-AZDisk -ResourceGroupName $ResourceGroupName | where {$_.ManagedBy -like $VM.ID}){
    Write-Output "AZ Disk still intact, deleting disk"
    Remove-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $vDisk.Name -Force
}
if($vNIC = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName | where {$_.VirtualMachine.Id -like $VM.ID}){
    Write-Output "AZ vNIC still intact, deleting NIC"
    Remove-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Name $vNIC.Name -Force
}
#Delete AD Computer Object
#IMPORT CREDS.XML here
if (!($creds)){$creds = $(Get-Credential -Message "User Name format is DOMAIN\LanID")}
$Obj = Get-ADComputer -Identity $VMName
Remove-ADObject $($Obj.DistinguishedName) -Recursive -Credential $Creds -Confirm:$false
