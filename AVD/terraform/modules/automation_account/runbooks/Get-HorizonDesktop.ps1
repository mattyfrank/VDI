<#
    Designed to run on on-premise connected hybrid worker. Gets the N10_DEV machine
    assigned to a given user email. Outputs JSON for logic apps. Purposely no output
    stream except for JSON.
#>

Param(
    [Parameter(Mandatory)]
    [String]$UserEmail,
    [String]$HorizonServer = "Horizon.DOMAIN.net",
    [String]$HorizonPoolName = "Win10_VDI",
    [String]$HorizonCredentialName = "cred_horizon_api"
)

try {
    # Install VMware CLI module if needed
    if (-not (Get-Module Vmware.PowerCLI -ListAvailable)) {
        if (-not (Get-PackageProvider Nuget -ListAvailable)) {
            Install-PackageProvider -Name NuGet -Force | Out-Null
        }
        Install-Module -Name Vmware.PowerCLI -Force -Confirm:$false | Out-Null
    }

    # Import VMware CLI
    Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false | Out-Null
    Import-Module -Name VMware.VimAutomation.HorizonView | Out-Null

    # Install Horizon View module if needed
    if (-not (Test-Path "$env:temp\PowerCLI-Example-Scripts")) {
        Invoke-WebRequest -Uri "https://github.com/vmware/PowerCLI-Example-Scripts/archive/refs/heads/master.zip" -OutFile "$env:temp\PowerCLI-Example-Scripts.zip" -UseBasicParsing
        Expand-Archive "$env:temp\PowerCLI-Example-Scripts.zip" -DestinationPath "$env:temp\PowerCLI-Example-Scripts"
    }

    # Import Horizon module
    Import-Module "$env:temp\PowerCLI-Example-Scripts\PowerCLI-Example-Scripts-master\Modules\VMware.Hv.Helper" | Out-Null

    # Install RSAT AD module if needed
    if ((Get-WindowsCapability -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0" -Online).State -eq 'NotPresent') {
        Add-WindowsCapability -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0" -Online | Out-Null
    }

    # Get LANID from email
    $UserSAMAccountName = Get-ADUser -Filter "UserPrincipalName -eq '$UserEmail'" | Select-Object -ExpandProperty SamAccountName

    # Get saved credential from azure automation account
    $Credential = Get-AutomationPSCredential "cred_horizon_api"

    # Connect to Horizon using saved credentials
    Connect-HVServer $HorizonServer -Credential $Credential | Out-null

    # Get machine info
    $DevPool = Get-HVMachineSummary -PoolName $HorizonPoolName
    $MachineName = $DevPool | Select-Object -Property @{Name = 'MachineName'; Expression = {$_.base.name}}, @{Name = 'User'; Expression = {$_.namesdata.username}} | Where-Object User -like "*$UserSAMAccountName" | Select-Object -ExpandProperty MachineName
    if ($null -eq $MachineName) {
        $MachineName = "None"
    }

    # Output
    $JsonOutput = @{
        MachineName = $MachineName
        UserEmail = $UserEmail
    } | ConvertTo-Json

    Write-Output $JsonOutput
}
catch {
    throw $Error[0]
}

#end