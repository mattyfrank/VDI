# Rename sessiondesktop objects with friendly names
# Runs from GitLab pipeline using MS azure-powershell container image

# Connect to Azure
Disable-AzContextAutosave
$secureStringPwd = ConvertTo-SecureString "$env:ARM_CLIENT_SECRET" -AsPlainText -Force
$pscredential = New-Object -TypeName System.Management.Automation.PSCredential($env:ARM_CLIENT_ID, $secureStringPwd)
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $env:ARM_TENANT_ID
Set-AzContext -Subscription "$env:ARM_SUBSCRIPTION_ID"

$env = $env:CI_COMMIT_REF_SLUG
$AppGroups = Get-AzResource -ResourceType Microsoft.DesktopVirtualization/applicationgroups | Where-Object Name -match "-$env-" | Select-Object Name, ResourceGroupName

foreach ($AppGroup in $AppGroups) {
    $SessionDesktop = Get-AzWvdDesktop -ApplicationGroupName $AppGroup.Name -ResourceGroupName $AppGroup.ResourceGroupName

    switch -Regex ($AppGroup.Name)
    {
        "dev" {
            $NewDesktopName = "Personal Developer Desktop"
            if ($SessionDesktop.FriendlyName -ne $NewDesktopName) {
            Update-AzWvdDesktop -Name "SessionDesktop" -FriendlyName $NewDesktopName -ApplicationGroupName $AppGroup.Name -ResourceGroupName $AppGroup.ResourceGroupName
            }
        }
        "desktopgen10" {
            $NewDesktopName = "Windows 10 General"
            if ($SessionDesktop.FriendlyName -ne $NewDesktopName) {
            Update-AzWvdDesktop -Name "SessionDesktop" -FriendlyName $NewDesktopName -ApplicationGroupName $AppGroup.Name -ResourceGroupName $AppGroup.ResourceGroupName
            }
        }
    }
}