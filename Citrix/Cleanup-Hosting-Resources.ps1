Add-PsSnapin Citrix.Host.Admin.V2

Add-PsSnapin Citrix.MachineCreation.Admin.V2

cd xdhyp:
cd .\HostingUnits\

#List All hosting Units.
Get-ChildItem | select PSChildName, HostingUnitUid

#Locate the HostingUnitID that needs to be deleted and store it in a variable.
$HostingUnitID='9b0e9e38-8144-41a4-a3ca-10f4c658e8c9'

#List all ProvTasks on the HostingUnit
Get-ProvTask | Where-Object { $_.ImagesToDelete | Where-Object { $_.HostingUnit -eq $HostingUnitID } }

#Select the TaskID for ProvTasks
Get-ProvTask | Where-Object { $_.ImagesToDelete | Where-Object { $_.HostingUnit -eq $HostingUnitID } } | select TaskId

#Remove ALL ProvTasks for the HostingUnitID
Get-ProvTask | Where-Object { $_.ImagesToDelete | Where-Object { $_.HostingUnit -eq $HostingUnitID } } | Remove-ProvTask

#Remove Specific TaskId. 
$taskID ='26cdd1e9-fc36-4232-ad70-81f62e77f8d6'
Remove-ProvTask -TaskID $taskID

#Delete/Remove Hosting Resource by Name
Remove-Item -path XDHyp:\HostingUnits\NonGPU-VLAN1272-Old

#Storage : 
#Remove-HypHostingUnitStorage -LiteralPath XDHyp:\HostingUnits\MyHostingUnit -StoragePath 'XDHyp:\HostingUnits\MyHostingUnits\newStorage.storage'

#PersonalvDiskStorage:
#Get-ChildItem XDHyp:\HostingUnits\MyHostingUnit\*.storage | Remove-HypHostingUnitStorage -LiteralPath XDHyp:\HostingUnits\MyHostingUnit -StorageType PersonalvDiskStorage

#TemporaryStorage:
#Get-ChildItem XDHyp:\HostingUnits\MyHostingUnit\*.storage | Remove-HypHostingUnitStorage -LiteralPath XDHyp:\HostingUnits\MyHostingUnit -StorageType TemporaryStorage

