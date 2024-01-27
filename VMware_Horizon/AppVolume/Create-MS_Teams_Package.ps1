# set VHD name
$WorkingDir = "C:\Temp"
$ver = (get-date -format yy.MM.dd)
$msVHD = "MS_Teams_2-" + $ver
$dVHD = 'C:\VHD'

$AVTools = "App_Volumes_Tools.msi"
$msixmgrURI = 'https://aka.ms/msixmgr'
$msTeamsURI = 'https://go.microsoft.com/fwlink/?linkid=2196106'
$msTeams = "MSTeams-x64.msix"

Write-Host "Change Directory"
cd $WorkingDir

#Download MS Teams MSIC Installer
$webObj = New-Object System.Net.WebClient
Write-Host "Downloading MSIXMGR"
$fDownload = $webObj.DownloadFile($msixmgrURI,"$WorkingDir\msixmgr.zip")
Write-Host  "Downloaded MSIXMGR - $($fDownload.ExitCode)"
Start-Sleep -seconds 2
Write-Host "Downloading MS Teams"
$fDownload = $webObj.DownloadFile($msTeamsURI,"$WorkingDir\$msTeams")
Write-Host  "Downloaded MS Teams - $($fDownload.ExitCode)"
Start-Sleep -seconds 2

# Extract zip
Write-Host "Extracting MSIXMGR"
Expand-Archive "$WorkingDir\msixmgr.zip" "$WorkingDir\msixmgr" -Force

#Create VHD with HyperV
Write-Host "Creating VHD"
$VHDpath = $dVHD + '\' + $msVHD + '.vhd'
New-VHD -sizeBytes 1024MB -path "$VHDpath" -Confirm:$false -Dynamic
Write-Host "Mounting $VHDpath"
$VHDobject = Mount-VHD "$VHDpath" -PassThru -Verbose
Write-Host "Mounted $VHDobject"
Write-Host "Initializing Disk"
$Disk = Initialize-disk -number $VHDobject.number -PassThru -Verbose
Write-Host "Intitialized Disk - $(($Disk).FriendlyName)"
Write-Host "Setting Partition and assigning drive letter"
$Partition = new-Partition -disknumber $Disk.number -assignDriveLetter -useMaximumSize -Verbose
Write-Host "Formatting VHD"
Format-Volume -filesystem NTFS -confirm:$false -DriveLetter $Partition.Driveletter -Force -Verbose
$PartitionPath = $Partition.DriveLetter + ':\'

#Copy MSIX files to VHD
$msixmgrDest = $PartitionPath + 'WindowsApps'
Write-Host "Unpacking MSIX to $msixmgrDest"
& "$WorkingDir\msixmgr\x64\msixmgr.exe" -Unpack -packagePath "$WorkingDir\$MSTeams" -destination "$msixmgrDest" -applyACLs
$packageName = get-childitem -Path "$msixmgrDest" -name
Write-Host "Unpacked $packageName at $msixmgrDest"
Write-Host "Unmounting $VHDpath"
Dismount-VHD "$VHDpath" -Verbose

#create JSON meta file
Write-Host "Creating META and JSON"
& "C:\Program Files (x86)\VMware\AppCapture\appcapture.exe" /addmeta "$VHDpath" /msix "WindowsApps\$packageName"
    
# Convert VHD to VMDK
Write-Host "Converting VHD to VMDK"
& "C:\Program Files (x86)\VMware\AppCapture\appcapture.exe" /msixvmdk "$VHDpath"

$Server = "Server001.Domain.net"
Write-Host "Copy Files to $($Server)"
$VMDKpath = $VHDpath.Replace('vhd','vmdk')
$JSONpath = $VHDpath.Replace('vhd','json')
New-PSDrive -PSProvider FileSystem -Root "\\$($Server)\D$\Temp\MSIX" -Name T -Credential $(Get-Credential)
Copy-Item $VMDKpath T:\
Copy-Item $JSONpath T:\
Remove-PSDrive -Name T

Write-Host "Log into $($Server) to complete the conversion and import"
Write-Host "First run 'AppVolume-Convert_VMDK.ps1' and then 'AppVolume-Import_Packages_REST.ps1'"