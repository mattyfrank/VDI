function Connect-Azure {
    param(
        [Parameter(Mandatory=$true)][ValidateSet("prod","nonprod")][String]$Environment,
        [Parameter(Mandatory=$true)][String]$Domain
    )
    $Environment = $Environment.ToLower()
    Connect-AzAccount -AccountId matthew.franklin@$($Domain).com  | Out-Null
    Select-AzSubscription -SubscriptionName "$($Environment)-CorporateServices-VDI" | Out-Null
}

function New-HostPool_ARM {
    #Deploy HostPool with ARM Template
    param(
        [Parameter(Mandatory=$true)][ValidateSet("prod","nonprod")][String]$Environment,
        [Parameter(Mandatory=$true)][ValidateSet("Personal","Pooled")][String]$HostPoolType,
        [Parameter(Mandatory=$true)][String]$ResourceGroupName,$HostPoolName,
        [Parameter(Mandatory=$false)][String]$TemplateFile="ARM-Templates\ARM-HostPool.json"
    )    
    $parameters = @{
        resourceGroupName       = $ResourceGroupName 
        TemplateFile            = $TemplateFile 
        env                     = $Environment
        hostpoolName            = $HostPoolName
        hostpoolType            = $HostPoolType
    }
    Write-Host "`nDeployment Params: " @parameters
    
    try{
        Write-Host "Deploy ARM Template $(Get-Date)"
        $Deployment = (New-AzResourceGroupDeployment @parameters)
    }catch{Write-Output "ERROR - ARM Deployment Failed $(Get-Date)"}
    return $HostPoolName    
}
#$HostPoolName = New-HostPool_ARM -Environment nonprod -HostPoolType Pooled -ResourceGroupName "rg-avd-nonprod-pool-ragen-westus2" -HostPoolName "vdpool-Nonprod-Pooled-TEST-westus2"

function New-AppGroup_ARM {
    #Deploy HostPool with ARM Template
    param(
        [Parameter(Mandatory=$True)][string]$AppGroupName,$ResourceGroupName,$HostPoolName,
        [Parameter(Mandatory=$True)][ValidateSet("Desktop","RemoteApp")][string]$AppGroupType,
        [Parameter(Mandatory=$false)][String]$TemplateFile="ARM-Templates\AVD-ApplicationGroup.json"
    )
    $Environment = $Environment.ToLower()
    Connect-AzAccount -AccountId matthew.franklin@$($Domain).com  | Out-Null
    Select-AzSubscription -SubscriptionName "$($Environment)-CorporateServices-VDI" | Out-Null

    $parameters = @{
        env                     = $Environment
        resourceGroupName       = $ResourceGroupName 
        TemplateFile            = $TemplateFile 
        AppGroupName            = $AppGroupName
        AppGroupType            = $AppGroupType
        HostPoolID             = $(Get-AzWvdHostPool -Name $HostPoolName -ResourceGroupName $ResourceGroupName).Id
    }
    Write-Host "`nDeployment Params:`n" @parameters

    try{
        Write-Host "Deploy ARM Template $(Get-Date)"
        $Deployment = (New-AzResourceGroupDeployment @parameters)
    }catch{Write-Output "ERROR - ARM Deployment Failed $(Get-Date)"}
    return $AppGroupName
}
#$AppGroupName = New-AppGroup_ARM -AppGroupName "vdag-$Environment-TEST-westus2" -ResourceGroupName "rg-avd-$Environment-pool-ragen-westus2" -HostPoolName $HostPoolName -AppGroupType "Desktop"

function New-Application_ARM {
    param(
        [Parameter(Mandatory=$True)][string]$AppName,$AppGroupName,$AppFilePath,$ResourceGroupName,
        [Parameter(Mandatory=$False)][string]$IconPath=$AppFilePath,
        [Parameter(Mandatory=$False)][String]$TemplateFile="ARM-Templates\AVD-Application.json"
    )
    $Environment = $Environment.ToLower()
    Connect-AzAccount -AccountId matthew.franklin@$($Domain).com  | Out-Null
    Select-AzSubscription -SubscriptionName "$($Environment)-CorporateServices-VDI" | Out-Null

    $parameters = @{
        resourceGroupName       = $ResourceGroupName 
        TemplateFile            = $TemplateFile 
        AppName                 = $AppName
        AppFilePath             = $AppFilePath
        IconPath                = $AppFilePath
        AppGroupName            = $AppGroupName
    } 
    Write-Host "`nDeployment Params:`n" @parameters

    try{
        Write-Host "Deploy ARM Template $(Get-Date)"
        $Deployment = (New-AzResourceGroupDeployment @parameters)
    }catch{Write-Output "ERROR - ARM Deployment Failed $(Get-Date)"}
    return $AppName
}
#$AppName = New-Application_ARM -AppName $AppName -AppGroupName $AppGroupName -AppFilePath "C:\windows\system32\mspaint.exe" -ResourceGroupName $ResourceGroupName
