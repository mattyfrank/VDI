## Run dsregcmd /leave on any master image

# Get master image status from registry
[int]$isMaster = 0
$isMaster = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Citrix\Configuration' -EA SilentlyContinue).MasterImage

# Leave hybrid join on shutdown if run on master image
if( $isMaster ) {
    [string]$cmd     = 'C:\Windows\System32\dsregcmd.exe'
    [string]$params  = '/leave'
    [string]$logFile = "$env:temp\HAAD_Leave_$(Get-Date -Format 'yyyyMMdd_hhmmsstt').log"

    Write-Output 'Running dsregcmd /leave...' | Out-File -FilePath $logFile
    try {
        [int]$totalRuns = 5 # Number of attempts
        do {
            $process = $null
            $exitCode = $null
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = New-Object System.Diagnostics.ProcessStartInfo($cmd, $params)
            $process.StartInfo.RedirectStandardOutput = $true
            $process.StartInfo.UseShellExecute = $false
            $process.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
            $process.Start() | Out-Null
            $process.BeginOutputReadLine()
            $process.WaitForExit()
            $exitCode = $process.ExitCode
            $process.Dispose()
            $totalRuns--
        } until ($exitCode -eq 0 -or $totalRuns -le 0)

        Write-Output "dsregcmd /leave completed with exit code of $exitCode" | Out-File -FilePath $logFile -Append

        ## Write status to registry
        if ($exitCode -eq 0){
            New-Item -Path 'HKLM:\Software\HAAD' -ErrorAction 'SilentlyContinue' | Out-Null
            New-ItemProperty -Path 'HKLM:\Software\HAAD' -Name 'HAADJoin_Status' -Value 0 -Force -ErrorAction 'SilentlyContinue' | Out-Null
            New-ItemProperty -Path 'HKLM:\Software\HAAD' -Name 'HAADJoin_TimeStamp' -Value "$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss tt')" -Force -ErrorAction 'SilentlyContinue' | Out-Null
        }
    }catch{
        Write-Output "HAAD error occurred`n-dsregcmd /leave failed with: $_" | Out-File -FilePath $logFile -Append
    }
}
