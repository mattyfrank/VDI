[CmdletBinding()]
Param (
    [Parameter()]
    [String]$GroupName,
    [String]$EndPoint,
    [String]$Token

)

# Sleep until the MMA object has been registered
Write-Output "Waiting for agent registration to complete..."

# Timeout = 1800 seconds = 30 minutes
$i = 180

do {
    
    # Check for the MMA folders
    try {
        # Change the directory to the location of the hybrid registration module
        Set-Location "$env:ProgramFiles\Microsoft Monitoring Agent\Agent\AzureAutomation"
        $version = (Get-ChildItem | Sort-Object LastWriteTime -Descending | Select-Object -First 1).Name
        Set-Location "$version\HybridRegistration"

        # Import the module
        Import-Module (Resolve-Path('HybridRegistration.psd1'))

        # Mark the flag as true
        $hybrid = $true
    } catch{

        $hybrid = $false

    }
    # Sleep for 10 seconds
    Start-Sleep -s 10
    $i--

} until ($hybrid -or ($i -le 0))

if ($i -le 0) {
    throw "The HybridRegistration module was not found. Please ensure the Microsoft Monitoring Agent was correctly installed."
}

# Register the hybrid runbook worker
Write-Output "Registering the hybrid runbook worker..."
Add-HybridRunbookWorker -Name $HybridGroupName -EndPoint $AutomationEndpoint -Token $AutomationPrimaryKey