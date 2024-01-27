#######################
###Cleanup
########################

param ([string]$VMName= "TEST-AVD-VM",$ResourceGroupName= "rg-avd-nonprod",[int]$VMcount=9)
$RG = (Get-AzResourceGroup -Name $ResourceGroupName -Location $LocationName)
[int]$count = 0
do{
    $VM = $VMName+$count
    
    $CleanUpVM = Get-AzVM -ResourceGroupName $RG.ResourceGroupName -Name $VM
    Remove-AzVM -ResourceGroupName $RG.ResourceGroupName -Name $CleanUpVM.Name -Force
    
    #Delete Azure resources
    if($CleanupDisk = Get-AZDisk -ResourceGroupName $RG.ResourceGroupName | where {$_.ManagedBy -like $CleanUpVM.ID}){
        Write-Output "AZ Disk still intact, deleting disk"
        Remove-AzDisk -ResourceGroupName $RG.ResourceGroupName -DiskName $CleanupDisk.Name -Force
    }
    if($CleanupNIC = Get-AzNetworkInterface -ResourceGroupName $RG.ResourceGroupName | where {$_.VirtualMachine.Id -like $CleanUpVM.ID}){
        Write-Output "AZ vNIC still intact, deleting NIC"
        Remove-AzNetworkInterface -ResourceGroupName $RG.ResourceGroupName -Name $CleanupNIC.Name -Force
    }
    
    Write-Output "Delete AD Object"
    if (!($creds)){$creds = $(Get-Credential -Message "User Name format is DOMAIN\LanID")}
    $Obj = Get-ADComputer -Identity $VM
    Remove-ADObject $($Obj.DistinguishedName) -Recursive -Credential $Creds -Confirm:$false

    $count = $count+=1
}
until($count -gt $VMcount)


#Delete AZ VM
$CleanUpVM = Get-AzVM -ResourceGroupName $RG.ResourceGroupName -Name $VMName
Remove-AzVM -ResourceGroupName $RG.ResourceGroupName -Name $CleanUpVM.Name -Force

#Delete Azure resources
if($CleanupDisk = Get-AZDisk -ResourceGroupName $RG.ResourceGroupName | where {$_.ManagedBy -like $CleanUpVM.ID}){
    Write-Output "AZ Disk still intact, deleting disk"
    #Remove-AzDisk -ResourceGroupName $RG.ResourceGroupName -DiskName $CleanupDisk.Name -Force
   
}
if($CleanupNIC = Get-AzNetworkInterface -ResourceGroupName $RG.ResourceGroupName | where {$_.VirtualMachine.Id -like $CleanUpVM.ID}){
    Write-Output "AZ vNIC still intact, deleting NIC"
    Remove-AzNetworkInterface -ResourceGroupName $RG.ResourceGroupName -Name $CleanupNIC.Name -Force
}

Write-Output "Delete AD Object"
if (!($creds)){$creds = $(Get-Credential -Message "User Name format is DOMAIN\LanID")}
$Obj = Get-ADComputer -Identity $VMName
Remove-ADObject $($Obj.DistinguishedName) -Recursive -Credential $Creds -Confirm:$false

<#
#Deallocate VM
Stop-AzVM -ResourceGroupName $RG.ResourceGroupName -Name $CleanUpVM.Name -Force

#Delete VM OS Disk
$CleanupDisk = Get-AZDisk -ResourceGroupName $RG.ResourceGroupName | where {$_.ManagedBy -like $CleanUpVM.ID}
Remove-AzDisk -ResourceGroupName $RG.ResourceGroupName -DiskName $CleanupDisk.Name -Force

#Delete Network Interface
$CleanupNIC = Get-AzNetworkInterface -ResourceGroupName $RG.ResourceGroupName | where {$_.VirtualMachine.Id -like $CleanUpVM.ID}
Remove-AzNetworkInterface -ResourceGroupName $RG.ResourceGroupName -Name $CleanupNIC.Name -Force

#Delete Network Security Group that Matches $VM.Name
$CleanupNSG = Get-AzNetworkSecurityGroup -ResourceGroupName $RG.ResourceGroupName -Name "$($CleanUpVM.Name)*"

#Delete Azure VM
Remove-AzVM -ResourceGroupName $RG.ResourceGroupName -Name $CleanUpVM.Name -Force

#Delete Managed Image
$CleanupImage = Get-AzImage -ImageName $($Image.Name) -ResourceGroupName $($Image.ResourceGroupName)
Remove-AzImage -ImageName $($CleanupImage.Name) -ResourceGroupName $($CleanupImage.ResourceGroupName) -Force

#>