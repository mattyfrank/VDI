# Connect to Azure
Disable-AzContextAutosave
$secureStringPwd = ConvertTo-SecureString "$env:ARM_CLIENT_SECRET" -AsPlainText -Force
$pscredential = New-Object -TypeName System.Management.Automation.PSCredential($env:ARM_CLIENT_ID, $secureStringPwd)
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $env:ARM_TENANT_ID
Set-AzContext -Subscription "$env:ARM_SUBSCRIPTION_ID"

# Get terraform output variables
Write-Output 'Reading terraform output variables'
$TFVars = Get-Content .\terraform_output.json | ConvertFrom-Json
Write-Output $TFVars

Write-Output 'Setting storage account context'
$Keys = Get-AzStorageAccountKey -ResourceGroupName $TFVars.management_resource_group_name.value -Name $TFVars.storage_account_name.value
$Key = $Keys.Value[0]
$StorageAccountContext = New-AzStorageContext -StorageAccountName $TFVars.storage_account_name.value -StorageAccountKey $Key

Write-Output 'Getting files to upload'
$Files = Get-ChildItem "./scripts" -File -Recurse

$Files | ForEach-Object {
    $UploadFile = @{
        Context = $StorageAccountContext
        Container = $TFVars.container_name.value
        File = $_.FullName
    }

    Write-Output "Uploading $($UploadFile.File)"
    Set-AzStorageBlobContent @UploadFile -Force
}

# end