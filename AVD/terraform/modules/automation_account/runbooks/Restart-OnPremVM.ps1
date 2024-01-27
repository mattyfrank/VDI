<# 
    Designed to run on a hybrid worker. Credential must have access to remotely shutdown system.
    Restarts an on prem computer.
#>

Param(
    [Parameter(Mandatory)]
    [String]$ComputerName
)

try {
    # Get saved credential from azure automation account
    Write-Output 'Getting credentials'
    $Credential = Get-AutomationPSCredential "cred_hybrid_worker"

    # restart computer
    Write-Output "Restarting computer $ComputerName"
    Restart-Computer -ComputerName $ComputerName -Wait -Force -Credential $Credential

    Write-Output "Runbook finished."
} catch {
    Write-Error $Error[0]
    throw $Error[0]
}