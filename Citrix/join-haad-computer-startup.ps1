## Run dscmdreg /join as a GPO startup script (non-persistent only)

# Get master image status from registry
[int]$isMaster = 0
$isMaster = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Citrix\Configuration' -EA SilentlyContinue).MasterImage

if ( -not $isMaster ){
    [string]$cmd     = 'C:\Windows\System32\dsregcmd.exe'
    [string]$params  = '/join'
    [string]$logFile = "$env:temp\HAAD_Join_$(Get-Date -Format 'yyyyMMdd_hhmmsstt').log"
    
    Write-Output 'Running dsregcmd /join...' | Out-File -FilePath $logFile
    
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
        
        Write-Output "dsregcmd /join completed with exit code of $exitCode" | Out-File -FilePath $logFile -Append
    
        ## Write status to registry
        if ($exitCode -eq 0){
            New-Item -Path 'HKLM:\Software\HAAD' -ErrorAction 'SilentlyContinue' | Out-Null
            New-ItemProperty -Path 'HKLM:\Software\HAAD' -Name 'HAADJoin_Status' -Value 1 -Force -ErrorAction 'SilentlyContinue' | Out-Null
            New-ItemProperty -Path 'HKLM:\Software\HAAD' -Name 'HAADJoin_TimeStamp' -Value "$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss tt')" -Force -ErrorAction 'SilentlyContinue' | Out-Null
        }else{
            New-Item -Path 'HKLM:\Software\HAAD' -ErrorAction 'SilentlyContinue' | Out-Null
            New-ItemProperty -Path 'HKLM:\Software\HAAD' -Name 'HAADJoin_Status' -Value 0 -Force -ErrorAction 'SilentlyContinue' | Out-Null
            New-ItemProperty -Path 'HKLM:\Software\HAAD' -Name 'HAADJoin_TimeStamp' -Value "$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss tt')" -Force -ErrorAction 'SilentlyContinue' | Out-Null
    
        }
    }catch{
        Write-Output "HAAD error occurred`n-dsregcmd /join failed with: $_" | Out-File -FilePath $logFile -Append
    }    
}
