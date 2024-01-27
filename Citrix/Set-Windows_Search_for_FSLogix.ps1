#Install FSLogix Agent and Windows Search Service configuration

#Region Search Service
# Configure Windows Search service auto-start
$ServiceName = "WSearch"
$Service = Get-Service -Name $ServiceName
If (($Service).StartType -eq "Disabled")
{
    Set-Service -Name $ServiceName -StartupType Automatic -Verbose

        If (($Service).Status -eq "Stopped")
        {
            Start-Service -Name $ServiceName -Verbose
        
            # Disable Delayed Auto Start
            Set-ItemProperty -Path "HKLM:SYSTEM\CurrentControlSet\Services\WSearch" -Name "DelayedAutoStart" -Value "0" -Verbose
        }
}
#EndRegion





