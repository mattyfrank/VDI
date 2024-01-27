param(
    $msix = "MS_Teams_v2-$(Get-Date -f yy.MM.dd)",
    $vCenter = "vcenter001.domain.net",
    $DataStore = "DS_001",
    $msix_vmdk = "$($msix).vmdk",
    $msix_json = "$($msix).json",
    $cred_path = ".\creds.xml",
    $local_path = "D:\Temp\MSIX",
    $log_path = "D:\Logs\Convert_VMDK_$(Get-Date -f yyyy-MM-dd_HH.mm.ss).txt"
)
# Function to log messages
function Log-Message {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $log_path -Value "$timestamp - $message"
}
# Error handling
trap {
    Log-Message "Error: $_"
    exit 1
}

#Connect to vCenter"
if(!(Test-Path $cred_path)){
    $creds=Get-Credential -Message "Enter Creds in the format Domain\UserName"
}else{ $creds = Import-Clixml -Path $cred_path}
Connect-VIServer -Server $vCenter -Credential $creds

#Validate Local Files
if(!(Test-Path "$local_path\$msix_vmdk")){Log-Message -message "Missing VMDK"}
if(!(Test-Path "$local_path\$msix_json")){Log-Message -message "Missing JSON"}

#Get DataStore and Map Drive
$DS = Get-Datastore $DataStore
New-PSDrive -Location $DS -Name ds -PSProvider VimDatastore -Root "\"

# Upload VMDK to Temp folder
Copy-DatastoreItem -Item "$local_path\$msix_vmdk" -Destination "ds:\AppVolumes4\temp\" -Force
$VMDK = Get-HardDisk -Datastore $DataStore -DatastorePath "[$DataStore] AppVolumes4/temp/$msix_vmdk"
if(!($VMDK)){Log-Message -message "Failed to Copy VMDK to DataStore."}

#Copy and Convert VMDK to Flat format
$Flat_VMDK = Copy-HardDisk -HardDisk $VMDK -DestinationPath "[$DataStore] AppVolumes4/apps/$msix" 

#Upload JSON to AppFolder
Copy-DatastoreItem -Item "$local_path\$msix_json" -Destination "ds:\AppVolumes4\apps\" -Force

# Delete VMDK file from Temp folder
$OldVMDK = Get-Item "ds:\AppVolumes4\temp\$msix_vmdk"
Remove-Item $oldVMDK -Force

#Remove Mapped Drive
Remove-PSDrive -Name ds

Log-Message "Script executed successfully" 