# Update AVD session host pool registration tokens if needed
# Runs from GitLab pipeline using MS azure-powershell container image

# Connect to Azure
Disable-AzContextAutosave
$secureStringPwd = ConvertTo-SecureString "$env:ARM_CLIENT_SECRET" -AsPlainText -Force
$pscredential = New-Object -TypeName System.Management.Automation.PSCredential($env:ARM_CLIENT_ID, $secureStringPwd)
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $env:ARM_TENANT_ID
Set-AzContext -Subscription "$env:ARM_SUBSCRIPTION_ID"

# Get pool resources and check that the registration token is valid. If not then generate a new one.
Get-AzResource -ResourceType 'Microsoft.DesktopVirtualization/hostpools' | ForEach-Object {
    $TokenCheck = Get-AzWvdRegistrationInfo -ResourceGroupName $_.ResourceGroupName -HostPoolName $_.Name | Select-Object -ExpandProperty Token

    if ([String]::IsNullOrEmpty($TokenCheck)) {
        Write-Output "Renewing registration token for pool: $($_.Name)"
        New-AzWvdRegistrationInfo -ResourceGroupName $_.ResourceGroupName -HostPoolName $_.Name -ExpirationTime $((get-date).ToUniversalTime().AddDays(27).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))
    }
}