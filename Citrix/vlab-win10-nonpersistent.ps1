## Powershell Script for Win10 Desktop IMG
## Matthew.Franklin
## updated September 2021

#command to call script: Set-ExecutionPolicy Bypass -Scope Process -Force; & '\\SERVER\configs$\vlab-win10-nonpersistent.ps1'

##Enable RSAT Capability
#DISM.exe /Online /add-capability /CapabilityName:Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0 /CapabilityName:Rsat.BitLocker.Recovery.Tools~~~~0.0.1.0 /CapabilityName:Rsat.CertificateServices.Tools~~~~0.0.1.0 /CapabilityName:Rsat.DHCP.Tools~~~~0.0.1.0 /CapabilityName:Rsat.Dns.Tools~~~~0.0.1.0 /CapabilityName:Rsat.FailoverCluster.Management.Tools~~~~0.0.1.0 /CapabilityName:Rsat.FileServices.Tools~~~~0.0.1.0 /CapabilityName:Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0 /CapabilityName:Rsat.IPAM.Client.Tools~~~~0.0.1.0 /CapabilityName:Rsat.LLDP.Tools~~~~0.0.1.0 /CapabilityName:Rsat.NetworkController.Tools~~~~0.0.1.0 /CapabilityName:Rsat.NetworkLoadBalancing.Tools~~~~0.0.1.0 /CapabilityName:Rsat.RemoteAccess.Management.Tools~~~~0.0.1.0 /CapabilityName:Rsat.RemoteDesktop.Services.Tools~~~~0.0.1.0 /CapabilityName:Rsat.ServerManager.Tools~~~~0.0.1.0 /CapabilityName:Rsat.Shielded.VM.Tools~~~~0.0.1.0 /CapabilityName:Rsat.StorageReplica.Tools~~~~0.0.1.0 /CapabilityName:Rsat.VolumeActivation.Tools~~~~0.0.1.0 /CapabilityName:Rsat.WSUS.Tools~~~~0.0.1.0 /CapabilityName:Rsat.StorageMigrationService.Management.Tools~~~~0.0.1.0 /CapabilityName:Rsat.SystemInsights.Management.Tools~~~~0.0.1.0

##Install chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://DEPO.DOMAIN.NET/choco_bootstrap'))
choco upgrade chocolatey -y
choco upgrade chocolatey-core.extension -y

##Install Free Apps
#choco upgrade firefoxesr -packageParameters "MaintenanceService=false" -y
choco upgrade firefoxesr-vlab -y
choco upgrade googlechrome -y
choco upgrade microsoft-edge-vlab -y
choco upgrade notepadplusplus -y 
choco upgrade 7zip -y
#choco upgrade imageglass -y

##Install CSR Tools
choco upgrade winscp.install -y
choco upgrade securecrt -y
choco upgrade vscode.install -y
choco upgrade powershell-core -y
choco upgrade python -y
choco upgrade PowerBi -y

##Install Adobe Suite
choco upgrade adobe-acrobat adobe-photoshop adobe-illustrator adobe-indesign --yes --source='https://nexus.DOMAIN.NET/repository/chocolatey-dev/'

##Install FSLogix
choco upgrade fslogix -y

##Install Office365 Enterprise Apps Semi-Annual Channel Release
#$o365ConfigPath = "\\SERVER\configs$\VLAB-O365-Configuration.xml" 
choco upgrade office365proplus --params "/ConfigPath:HTTP://UNIQUE_PATH" -y
#choco upgrade office365proplus --params $o365ConfigPath -y

##Install OneDrive
choco upgrade onedrive -y

##Install Teams WebSocket
#$websocket = "\\SERVER\configs$\wvd-source-files\MsRdcWebRTCSvc_HostSetup_1.0.2006.11001_x64.msi"
#msiexec /passive /i $websocket
choco install microsoft-teams-websocket-plugin -y

##Install Teams
choco install microsoft-teams.install --install-arguments="'ALLUSERS=1'" -y

##Install Citrix
#choco upgrade vcredist140 --yes --ignoredependencies
#reboot
#choco upgrade citrix-vda-server1912 --yes --ignoredependencies

##Install Nvidia
#choco install nvidia-grid-8 -y
#choco install nvidia-grid-11 -y

##Get all choco apps installed
choco list --l

##Delete Desktop Icons
Remove-Item "c:\Users\*\Desktop\Firefox.lnk" -force
Remove-Item "c:\Users\*\Desktop\Google Chrome.lnk" -force
Remove-Item "c:\Users\*\Desktop\Microsoft Edge.lnk" -force
Remove-Item "c:\Users\*\Desktop\Adobe Acrobat DC.lnk" -force
Remove-Item "c:\Users\*\Desktop\ImageGlass.lnk" -force
Remove-Item "c:\Users\*\Desktop\Visual Studio Code.lnk" -force
Remove-Item "c:\Users\*\Desktop\Power BI Desktop.lnk" -force
Remove-Item "c:\Users\*\Desktop\WinSCP.lnk" -force
Remove-Item "c:\Users\*\Desktop\SecureCRT 8.7.lnk" -force

##Optimize Image

#Set Time to Eastern Time Zone
tzutil /s "Eastern Standard Time"
 
#Disable Auto-Updates
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f

##Disable Storage Sense
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 01 /t REG_DWORD /d 0 /f

##Regedit to optimize Teams for VDI
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Teams" /v IsWVDEnvironment /t REG_DWORD /d 1 /f

##Regedit to add in Web Socket Redirector
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\AddIns\WebRTC Redirector" /v "WebRTC Redirector Enabled" /t REG_DWORD /d 1 /f

#Create directories
$localpath = "C:\Installs"
$remotepath = "\\SERVER\configs$\vlab source files"
if (!(Test-Path $localpath)){New-Item -ItemType Directory $localpath}
else {Write-Host "$localpath already exists"}

#Copy Expand Partition Script to C:\installs
Write-Output "Copy Master-Image Script to $localpath "
Get-Item "$remotepath\Expand-Partition.ps1" | Copy-Item -Destination $localpath

#Copy Citrix Optimizer to C:\Installs
$CitrixOptimizer = "Citrix Optimizer - v2.8.0.143"
Write-Output "Copying $CitrixOptimizer to $localpath"
Get-Item "$remotepath\$CitrixOptimizer.zip" | Copy-Item -Destination $localpath
#Expand the zip
Write-Output "Expanding Citrix Optimizer Files"
Expand-Archive "$LocalPath\$CitrixOptimizer.zip" -DestinationPath "$localpath\$CitrixOptimizer"

#Delete the zip
Write-Output "Deleting '$CitrixOptimizer.zip' from $localpath"
Start-Sleep -Seconds 1
Get-Item "$LocalPath\$CitrixOptimizer.zip" | Remove-Item -Force -Confirm:$false

#Citrix Optimizer
#Analyze Windows for Optimizations
#Set-ExecutionPolicy Bypass -Scope Process -Force; & 'C:\installs\Citrix Optimizer\CtxOptimizerEngine.ps1' -Analyze
#Execute Optimization for Windows 10, create rollback file.
#Set-ExecutionPolicy Bypass -Scope Process -Force; & 'C:\installs\Citrix Optimizer\CtxOptimizerEngine.ps1'-Mode Execute -OutputXml C:\installs\Rollback.xml


##Copy ADM to C:\Installs
#Write-Output "Copy ADML & ADMX Files to " $localpath
#Get-Item "$remotepath\ADM Files.zip" | Copy-Item -Destination $localpath

##Copy ADML/ADMX files
#Write-Output "Copy ADML and ADMX files"
#Get-ChildItem "$localpath\ADM Files\*.admx" | Copy-Item -Destination "C:\Windows\PolicyDefinitions"
#Get-ChildItem "$localpath\ADM Files\en-US" | Copy-Item -Destination "C:\Windows\PolicyDefinitions\en-US"

##Cleanup
#Start-Sleep -Seconds 60
#Write-Output "Cleanup files in " $localpath
#Get-Item "$LocalPath\Virtual-Desktop-Optimization-Tool-master.zip" | Remove-Item -Force -Confirm:$false
#Get-Item $LocalPath\'ADM Files.zip' | Remove-Item -Force -Confirm:$false
#Get-Item $LocalPath\'ADM Files' | Remove-Item -Recurse -Force -Confirm:$false

#Cleanup
Write-Output "Deleting $localpath"
Start-Sleep -Seconds 1
Get-ChildItem "$LocalPath" | Remove-Item -Recurse -Force -Confirm:$false


##Reboot
& shutdown -r -t 300

<#

###################################################

#Install EndPoint Agents.
#Choco install FireEye
choco install cortex-xdr -param ='"/VDI"' -y
cytool imageprep scan timeout 4 upload 60 path c:\installs\cortex-cytool-scan.txt
#Choco install Qualys
choco upgrade qualysagent -y

#EndRegion Installers

##########################################################

#Region OptimizeImage 

#set local folder
$localpath = "C:\Installs\Virtual-Desktop-Optimization-Tool-master"
#Virtual Desktop Team Optimization Script
Set-ExecutionPolicy Bypass -Scope Process -Force; & "$localpath\Win10_VirtualDesktop_Optimize.ps1"

#Citrix Optimizer
#Analyze Windows for Optimizations
Set-ExecutionPolicy Bypass -Scope Process -Force; & 'C:\installs\Citrix Optimizer\CtxOptimizerEngine.ps1' -Analyze
#Execute Optimization for Windows 10 version 1909, create rollback file.
Set-ExecutionPolicy Bypass -Scope Process -Force; & 'C:\installs\Citrix Optimizer\CtxOptimizerEngine.ps1'-Mode Execute -OutputXml C:\installs\Rollback.xml

#EndRegion OptimizeImage

############################################################

#>