[CmdletBinding(SupportsShouldProcess=$True)]
Param(
    [Parameter(Mandatory=$true)][string]$UserUPN,
    [Parameter(Mandatory=$false)][ValidateSet("prod","nonprod")][String]$Environment,
    [Parameter(Mandatory=$false)][String]$LocationName="eastus2",
    [Parameter(Mandatory=$false)][String]$ResourceGroupName= "rg-avd-$Environment-pool-dev-$LocationName",
    [Parameter(Mandatory=$false)][string]$HostPoolName= "vdpool-$Environment-personal-dev-$LocationName",
    [Parameter(Mandatory=$false)][string]$DomainName
)

<##!!Install Modules if needed!!# >
if (!(Get-Module AZ -ListAvailable)) {
    Install-Module -Name Az -AllowClobber -Force -Confirm:$false | Out-Null
    Import-Module -Name Az
}
if (!(Get-Module Az.DesktopVirtualization)) {
    Install-Module -Name Az.DesktopVirtualization -Force -Confirm:$false | Out-Null
    Import-Module -Name Az.DesktopVirtualization
}
if (!(Get-Module AzureAD)) {
    Install-Module -Name AzureAD -Force -Confirm:$false | Out-Null
    Import-Module -Name AzureAD
}
#>

#Region Variables 
#EndRegion Variables

#Region Main
try{
    <# Azure Automation RunAs Connection #>
    $connectionName = "AzureRunAsConnection"
    try {
        $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName
        #Write-Output "Logging in to Azure..."
        $connection = (Connect-AzAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint) 
    }
    catch {
        if (!$servicePrincipalConnection){
            Write-Error "Connection $connectionName not found."
        } else{Write-Error $_}
    }
    #>

    # Search for Assigned SessionHost
    $SessionHost = (Get-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName | ? {$_.AssignedUser -eq $UserUPN})
    if (!($SessionHost)){ 
        Write-Error "No Session Host Assigned to $($UserUPN)" -ErrorAction Stop
    }else {
        #Format Session Host Name
        $SessionHostName = ($SessionHost.Name).replace("$HostPoolName/","")
        #Format Output to JSON
        $Json = @{
            SessionHost = $SessionHostName
        } | ConvertTo-Json
        Write-Output $Json
    }
}catch {$_}
#EndRegion Main