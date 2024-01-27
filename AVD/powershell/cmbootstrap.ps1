param (
	[Parameter(Mandatory=$false,HelpMessage="CM TaskSequence ID")][string]$ProvisionID,
	[Parameter(Mandatory=$false,HelpMessage="Working Directory")][string]$localPath="C:\Temp",
    [Parameter(Mandatory=$false,HelpMessage="LogFile")][string]$logfile="$localPath\BootStrap_$(Get-Date -F yyyy-MM-dd_hh.mm.ss).txt",
    [Parameter(Mandatory=$false,HelpMessage="SMS Site Code")][string]$smsSiteID="P01",
    [Parameter(Mandatory=$false,HelpMessage="CCM Setup")][string]$file="C:\Temp\ccmsetup.msi"
)
function Write-Log{
    param ($msg)
    Write-Output $msg
    Write-Error $msg -ErrorAction Stop
}

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
        Write-Output "AutoEnrollment Certificate not found."
        Write-Output "Update AutoEnroll Cert attempt '$($count)'"
        CertUtil -pulse
        Start-Sleep -s 30
    }
    $count++
} while ($count -lt '10')

if ($null -eq ((Get-ChildItem -path cert:\LocalMachine\My) | Where-Object {$_.Subject -like "*$env:computername*"})) {
    Write-Log -msg"ERROR - AutoEnrollment Certificate not found. Terminating"
}

#install vars
$installArgs = "CCMSETUPCMD=`"/nocrlcheck /UsePKICert SMSSiteCode=$smsSiteID ProvisionTS=$ProvisionID`""
Write-Output "Install Arguments are: '$($installArgs)'"

try {
	Write-Output "Try to install CM."
	$retVal = Start-Process msiexec -ArgumentList "/i $file /qn $installArgs" -PassThru -Wait
}catch {Write-Log -msg "something went wrong"; return}

Start-Sleep -s 10

if ($retVal.ExitCode -eq 0) {
    Write-Output "CCM Installation Started"
}else {
    Write-Log -msg "CCM Setup encountered an error: $($retVal.ExitCode)"
    EXIT $retVal.ExitCode
}

Start-Sleep 10

if (Get-Process CCMSetup -ErrorAction SilentlyContinue) {
    Write-Output "CCMSetup.exe Process Detected, Waiting for Completion"
}else {Write-Log -msg "CCMSETUP.EXE Not Detected. Failed To Launch?"}

#Run a loop every 10 seconds checking for completion status of install. When Installed, move to next Check, Error on timeout.
[int]$MaxN = 60
[int]$n = 1
do {
    Start-Sleep 10
    $n++
}until ((!(Get-Process CCMSetup -ErrorAction SilentlyContinue)) -or ($n -ge $MaxN))

#if not complete after max time, process is broken..
if ($n -ge $MaxN) {Write-Log -msg "CCM Failed to Install within the time frame specified"}

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
    }Catch {Write-Output "TS not ready yet..."}
}Until (($null -ne $tsEnv) -or ($n -ge $MaxN))

If($n -ge $MaxN){Write-Log -msg "The Task sequence did not begin after the defined period of time."}

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
$MaxN = 45
$n = 1
DO{
    Write-Output "Task Sequence Still Running - Minute $n of $maxN"
    Write-Output "Current step name: [$($tsEnv.Value("_SMSTSCurrentActionName"))]"
    Start-Sleep 60
    $n++
}Until ((Test-Path $TsExecPath) -or ($n -ge $MaxN))

If(Test-Path $TsExecPath) {
    Write-Output "Task Sequence Completed"
}Else {Write-Log -msg "TS execution was not posted. Something went wrong."}

if($n -ge $MaxN) {Write-Log -msg "Task Sequence Ran over 30 minutes, Likely unhealthy!"}

#The Task sequence began, and has since ended without an error being thrown. We will now check the registry until an execution status is posted.
$TSLog = Get-ChildItem -Path "$TsExecPath" -ErrorAction SilentlyContinue

If(($null -ne $TSLog) -and ($TSLog.Count -eq 1)) {
    $TSResults = Get-ItemProperty -Path "$($TsLog.PSPath)"
    $TSState = $TSResults._State
    $TSStartTime = $TSResults._RunStartTime
    $TSExitCode = $TSResults.SuccessOrFailureCode
}Else {Write-Log -msg "There should only one execution"}

Write-Output "TS state is [$TSState]"
Write-Output "TS start time is [$TSStartTime]"
Write-Output "TS took $(try{((Get-Date)-[datetime]$TSStartTime).Minutes}catch {N/A})"

If($null -eq $TSExitCode) {$TSExitCode = 999}

IF($TSExitCode -eq 0) {
    Write-Output "Engine Finished successfully and all Applications report success."
}Else {
    Write-Log -msg "TS failed with error code: $TSExitCode"
    EXIT $TSExitCode
}

#stop logs
Stop-Transcript