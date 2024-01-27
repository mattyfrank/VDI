[CmdletBinding(SupportsShouldProcess=$true)]
param 
(
    [Parameter()][string] $token 
)

#Verify the directory exists
if(!(Test-Path C:\temp)){
    Write-Output "path not found, creating folder."
    New-Item C:\temp -ItemType Directory 
}

Start-Transcript -Path C:\temp\AVDinstall_$(Get-Date -F yyyy-MM-dd_HH:mm:ss)

#Get Installed Apps
$Apps = Get-WmiObject -Class Win32_Product

#Uninstall 
$BL = $Apps | Where-Object{$_.Name -eq "Remote Desktop Agent Boot Loader"}
if($BL){
    foreach ($y in $BL){
        Write-Output "$($y.Name) - Start uninstall."
        Start-Process msiexec -ArgumentList "/x $($y.IdentifyingNumber) /norestart /quiet" -PassThru -Wait
        Write-Output "$($y.Name) - Uninstall Completed.`n"
    }
    Write-Output "$($BL.Name) Uninstalls completed!"`n
}

$RDA = $Apps | Where-Object{$_.Name -eq "Remote Desktop Services Infrastructure Agent"}
if($RDA){
    foreach ($x in $RDA){
        Write-Output "$($x.Name) - Start uninstall."
        Start-Process msiexec -ArgumentList "/x $($x.IdentifyingNumber) /norestart /quiet" -PassThru -Wait
        Write-Output "$($x.Name)  - Uninstall completed."
    }
    Write-Output "$($RDA.Name) Uninstalls completed!"`n
}

$RDGA = $Apps | Where-Object{$_.Name -like "Remote Desktop Services Infrastructure Geneva Agent *"}
if($RDGA){
    foreach ($z in $RDGA){
        Write-Output "$($z.Name) - Start uninstall."
        Start-Process msiexec -ArgumentList "/x $($z.IdentifyingNumber) /norestart /quiet" -PassThru -Wait
        Write-Output "$($z.Name) - Uninstall completed."
    }
    Write-Output "$($RDGA.Name) Uninstalls completed!"`n
}

Write-Output "`nEnd of uninstalls!`n"

Start-Sleep -s 60

#Check installed apps again
$Apps2 = Get-WmiObject -Class Win32_Product
$Apps2 | where {$_.Name -like "Remote Desktop *"} | select Name
$RDGA = $Apps2 | Where-Object{$_.Name -eq "Remote Desktop Services Infrastructure Geneva Agent 44.3.1"}
if ($RDGA){Write-Error "RD Geneva still installed!";break}
$BL = $Apps2 | Where-Object{$_.Name -eq "Remote Desktop Agent Boot Loader"}
if ($BL){Write-Error "RD BootLoader still installed!";break}
$RDA = $Apps2 | Where-Object{$_.Name -eq "Remote Desktop Services Infrastructure Agent"}
if ($RDA){Write-Error "RD Infra still installed!";break}

Write-Output "Begin installs."

$rda_url = "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv"
$bl_url = "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH"
$rdaoutpath = "C:\temp\Microsoft-RDInfra-RDAgent-Installer.msi"
$bloutpath = "C:\temp\Microsoft-RDInfra-RDAgentBootLoader-Installer.msi"
try{
    Invoke-WebRequest -Uri $rda_url -OutFile $rdaoutpath
    Invoke-WebRequest -Uri $bl_url -OutFile $bloutpath
    Write-Output `n"Install RD Infra Agent and Token"
    Start-Process msiexec.exe "/i $rdaoutpath /qn REGISTRATIONTOKEN=$token" -Wait -PassThru
    Start-Sleep -s 5
    Write-Output `n"Install RD Agent Boot Loader"
    Start-Process msiexec.exe "/i $bloutpath /qn" -Wait -PassThru
    Start-Sleep -s 5
}
catch{
    Write-Information "Installs Failed"
    #[int]$counter=0
    #do {Start-Sleep -S 30;Start-Process msiexec.exe "/i $bloutpath /qb";$counter+=1 }
    #until ($counter -gt 3)  
}

Write-Output `n"$(hostname) & $($(Get-ChildItem -Path C:\Users -Attributes D -Exclude "public").Name)"`n

Stop-Transcript