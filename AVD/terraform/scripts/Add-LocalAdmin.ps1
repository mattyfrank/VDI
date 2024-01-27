[CmdletBinding()]
Param (
    [Parameter()]
    [String]
    $Email
)

$LogFile = "C:\Logs\avd_customscript.log"

New-Item -ItemType Directory -Path "C:\Logs" -ErrorAction SilentlyContinue

Add-Content $LogFile -Value "$(Get-Date) - Script start."

Add-Content $LogFile -Value "Creating C:\Temp folder"
New-Item -ItemType Directory -Path "C:\Temp" -ErrorAction SilentlyContinue

Add-Content $LogFile -Value "Adding $LANID to Administrators group"
Add-LocalGroupMember -Group "Administrators" -Member "$Email" -ErrorAction SilentlyContinue

Add-Content $LogFile -Value "Running group policy update"
& gpupdate /force

Add-Content $LogFile -Value "$(Get-Date) - Script complete."