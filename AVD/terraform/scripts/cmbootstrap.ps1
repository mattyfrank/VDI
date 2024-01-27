param (
    #Working Directory
    [string]$localPath = "C:\Temp",

    #LogFiles
    [string]$logfile = "$localPath\BootStrap_$(Get-Date -F yyyy-MM-dd_hh.mm.ss).txt",

    #TaskSequence ID
    [Parameter(Mandatory=$false)][string]$ProvisionID,

    #SMS Site Code
    [string]$smsSiteID = "P01",

    #package bootstrap calls
    [string]$file = "C:\Temp\ccmsetup.msi"
)

#setup log path
if(!(Test-Path $localPath)){Write-Output "Creating local path."; New-Item -ItemType Directory -Path $localPath}

#Verify the log directory exists
if(!(Test-Path $logfile)){Write-Output "Creating log file."; New-Item $logfile}

#Start Logging
Start-Transcript -Path $logfile

Write-Output "Date & Time $(Get-Date -f yyyy-MM-dd_hh:mm:ss)"

[int]$count = '1'
Write-Output "Update AutoEnrollment cert attempt number $count."
CertUtil -pulse
Write-Output "wait 30 seconds and verify cert has been installed"
Start-Sleep -s 30
$count++

#verify certs exist, loop to try additional times.
do {
    if ($null -ne ((Get-ChildItem -path cert:\LocalMachine\My) | Where-Object {$_.Subject -like "*$env:computername*"})) {
        Write-Output "AutoEnrollment Certificate found. Continuing";break
    } else { 
        Write-Information "AutoEnrollment Certificate not found."
        Write-Output "Update AutoEnroll Cert attempt '$($count)'"
        CertUtil -pulse
        Start-Sleep -s 30
    }
    $count++
} while ($count -lt '10')

if ($null -eq ((Get-ChildItem -path cert:\LocalMachine\My) | Where-Object {$_.Subject -like "*$env:computername*"})) {
    Write-Error "ERROR - AutoEnrollment Certificate not found. Terminating" -ErrorAction Stop
}

#install vars
$installArgs = "CCMSETUPCMD=`"/nocrlcheck /UsePKICert SMSSiteCode=$smsSiteID ProvisionTS=$ProvisionID`""
Write-Output "Install Arguments are: '$($installArgs)'"

try {
	Write-Output "Try to install CM."
	$retVal = Start-Process msiexec -ArgumentList "/i $file /qn $installArgs" -PassThru -Wait
}catch {Write-Error "something went wrong"; return}

Start-Sleep -s 10

if ($retVal.ExitCode -eq 0) {
    Write-Output "CCM Installation Started"
}else {
    Write-Error "CCM Setup encountered an error: $($retVal.ExitCode)" -ErrorAction SilentlyContinue
    EXIT $retVal.ExitCode
}

Start-Sleep 10

if (Get-Process CCMSetup -ErrorAction SilentlyContinue) {
    Write-Output "CCMSetup.exe Process Detected, Waiting for Completion"
}else {
    Write-Error "CCMSETUP.EXE Not Detected. Failed To Launch?" -ErrorAction Stop
}

#Run a loop every 10 seconds checking for completion status of install. When Installed, move to next Check, Error on timeout.
[int]$MaxN = 60
[int]$n = 1
do {
    Start-Sleep 10
    $n++
}until ((!(Get-Process CCMSetup -ErrorAction SilentlyContinue)) -or ($n -ge $MaxN))

#if not complete after max time, process is broken..
if ($n -ge $MaxN) {
    Write-Error "CCM Failed to Install within the time frame specified" -ErrorAction Stop
}

#successful output
Write-Output "CM Setup Process has completed"

#Check for TS execution
Write-Output "Checking for TS execution"
Write-Output "Wait for up to 5 mins"
$MaxN = 30
$n = 1
DO {
    Write-Output "Waiting for OSD TS To Begin..."
    Start-Sleep 10
    $n ++
    Try {
        $tsEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction Stop
        Write-Output "TS is now running"
    }
    Catch {
        Write-Output "TS not ready yet..."
    }
}Until (($null -ne $tsEnv) -or ($n -ge $MaxN))

If ($n -ge $MaxN) {
    $msg = "The Task sequence did not begin after the defined period of time."
    Write-Output $msg
    Write-Error $msg -ErrorAction Stop 
}

Write-Output "Task Sequence Detected, Now we Wait."

$TSID = $tsEnv.Value("_SMSTSPackageID")
$TSName = $tsEnv.Value("_SMSTSPackageName")
$TSAdvID = $tsEnv.Value("_SMSTSAdvertID")
$TsExecPath = "HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Software Distribution\Execution History\System\$TSID"

Write-Output "TS Name: [$TSName]"
Write-Output "TS ID: [$TSID]"
Write-Output "TS Advertisement ID: [$TSAdvID]"
Write-Output "TS Execution History Path: [$TSExecPath]"

#Once the Task Sequence is Running, we will wait for it to complete, giving ourselves 45 Minutes Before throwing an error.
#Set maximum loops, and reset loops to 1
$MaxN = 60
$n = 1
DO {
    Write-Output "Task Sequence Still Running - Minute $n of $maxN"
    Write-Output "Current step name: [$($tsEnv.Value("_SMSTSCurrentActionName"))]"
    Start-Sleep 60
    $n++
}Until ((Test-Path $TsExecPath) -or ($n -ge $MaxN))

If (Test-Path $TsExecPath) {
    Write-Output "Task Sequence Completed"
}Else {Write-Error "TS execution was not posted. Something went wrong." -ErrorAction Stop}

if ($n -ge $MaxN) {
    $msg = "Task Sequence Ran over $($MaxN) minutes, Likely unhealthy!"
    Write-Output $msg
    Write-Error $msg -ErrorAction Stop 
}

#The Task sequence began, and has since ended without an error being thrown. We will now check the registry until an execution status is posted.
$TSLog = Get-ChildItem -Path "$TsExecPath" -ErrorAction SilentlyContinue

If(($null -ne $TSLog) -and ($TSLog.Count -eq 1)) {
    $TSResults = Get-ItemProperty -Path "$($TsLog.PSPath)"
    $TSState = $TSResults._State
    $TSStartTime = $TSResults._RunStartTime
    $TSExitCode = $TSResults.SuccessOrFailureCode
}Else {
    $msg = "There should only one execution"
    Write-Output $msg
    Write-Error $msg -ErrorAction Stop
}

Write-Output "TS state is [$TSState]"
Write-Output "TS start time is [$TSStartTime]"
Write-Output "TS took $(try{((Get-Date)-[datetime]$TSStartTime).Minutes}catch {N/A})"

If($null -eq $TSExitCode) {
    $TSExitCode = 999
}

IF ($TSExitCode -eq 0) {
    Write-Output "Engine Finished successfully and all Applications report success."
}Else {
    $msg = "TS failed with error code: $TSExitCode"
    Write-Output "$msg"
    Write-Error "$msg"-ErrorAction SilentlyContinue
    EXIT $TSExitCode
}

#stop logs
Stop-Transcript