<# 
    Designed to run on a hybrid worker using a stored credential that has access to modify group membership.
    Adds a user by looking up their email address and add them to the given group.
#>

Param(
    [Parameter(Mandatory)]
    [String]$UserEmail,

    [Parameter(Mandatory)]
    [String]$ADGroupName
)

try {
    if ((Get-WindowsCapability -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0" -Online).State -eq 'NotPresent') {
        Write-Output 'Installing AD module'
        Add-WindowsCapability -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0" -Online | Out-Null
    }

    Write-Output 'Loading AD module'
    Import-Module ActiveDirectory

    # Get saved credential from azure automation account
    Write-Output 'Getting credentials'
    $Credential = Get-AutomationPSCredential "cred_hybrid_worker"
    
    # Get user and group info
    Write-Output 'Getting user and group details'
    $User = Get-ADUser -Filter "UserPrincipalName -eq '$UserEmail'" -Credential $Credential
    $ADGroup = Get-ADGroup $ADGroupName -Credential $Credential

    # Add to group
    Write-Output "Adding user $($User.SamAccountName) to group $($ADGroup.Name)"
    Add-ADGroupMember -Identity $ADGroup -Members $User -Credential $Credential

    Write-Output "Runbook finished."
} catch {
    Write-Error $Error[0]
    throw $Error[0]
}