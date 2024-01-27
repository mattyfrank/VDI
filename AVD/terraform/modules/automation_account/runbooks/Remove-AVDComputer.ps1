Param(
    [Parameter(Mandatory)]
    [String]$ComputerName,
    [string]$Domain
)

# Validation
if ($ComputerName.ToUpper() -notmatch 'W-AVD-') {
    Write-Output "VM name does not match AVD standard. This runbook can only be used to delete AVD desktops."
    throw 'VM name does not match AVD standard. This runbook can only be used to delete AVD desktops.'
}

$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection"
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Connect-AzAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

# Get VM info
Write-Output "Getting VM info for $ComputerName"
$AzVM = Get-AzVm -Name $ComputerName.Trim()
if ($null -eq $AzVM) {
    Write-Output "Virtual desktop $HostPoolName does not exist"
    throw "Virtual desktop $HostPoolName does not exist"
}

$HostPoolName = Get-AzResource -ResourceGroupName $AzVM.ResourceGroupName | Where-Object Name -like "pool*" | Select-Object -ExpandProperty Name
Write-Output "Found host pool: $HostPoolName"

# Delete VM and associated disk, network and storage
Write-Output "Deleting VM"
Remove-AzResource -ResourceId $AzVM.Id -Force

Write-Output "Deleting Disk"
Remove-AzResource -ResourceId $AzVM.StorageProfile.OsDisk.ManagedDisk.id -Force

Write-Output "Deleting Network interface"
Remove-AzResource -ResourceId $AzVM.NetworkProfile.NetworkInterfaces.Id -Force

# If associated with session host pool, remove
if (Get-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $AzVM.ResourceGroupName -Name "$ComputerName.$($Domain).net" -EA SilentlyContinue) {
    Write-Output "Removing from session host pool"
    Remove-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $AzVM.ResourceGroupName -Name "$ComputerName.$($Domain).net"
}

Write-Output "Runbook finished."
# end