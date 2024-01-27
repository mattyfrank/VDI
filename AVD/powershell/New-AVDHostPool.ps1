<#
   .SYNOPSIS
    Create new AVD Host Pool, create new Application Group (Desktop or RAIL), assign Application Group to AVD Workspace, (if RAIL) create new Application, and create new Session Hosts.

   .DESCRIPTION
    Mandatory params:
    ResourceGroupName, HostPoolName, AppGroupName, WorkspaceName, HostPoolType, HostPoolPreferredAppGroupType
   
   .EXAMPLE
    New-AVDHostPool.ps1 -Environment $Environment -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -AppGroupName $AppGroupName -WorkspaceName $WorkspaceName -HostPoolType $HostPoolType -PreferredAppGroupType $PreferredAppGroupType
    New-AVDHostPool.ps1 -Environment nonprod -ResourceGroupName "rg-avd-nonprod-pool-dev-westus2" -HostPoolName "TestPersonalDesktop" -AppGroupName "TestPersonalDesktop" -WorkspaceName "vdws-nonprod-desktops-westus2" -HostPoolType Personal -PreferredAppGroupType Desktop -UserUPN matthew.franklin@$($domain).com

    .NOTES
    New-AVDHostPool.ps1 -Environment nonprod -ResourceGroupName "rg-avd-nonprod-pool-ragen-westus2" -HostPoolName "TestRemoteApps" -AppGroupName "TestRemoteApps" -WorkspaceName "vdws-nonprod-rageneral-westus2" -HostPoolType Pooled -PreferredAppGroupType RailApplications
#>
param(
    [Parameter(Mandatory=$True)][ValidateSet("nonprod","prod")][string]$Environment,
    [Parameter(Mandatory=$True)][ValidateSet("Pooled","Personal")][string]$HostPoolType,
    [Parameter(Mandatory=$True)][ValidateSet("Desktop","RemoteApp")][string]$AppGroupType,
    [Parameter(Mandatory=$False)][string]$LocationName="westus2",
    [Parameter(Mandatory=$False,HelpMessage="HostPool Kind (DEV,RAGEN,GEN10,...)")][ValidateLength(2,5)][string]$HostPoolKind,
    [Parameter(Mandatory=$False)][string]$HostPoolName="vdpool-$Environment-$HostPoolType-$HostPoolKind-$LocationName",
    [Parameter(Mandatory=$False)][string]$AppGroupName="vdag-$Environment-$HostPoolKind-$LocationName",
    [Parameter(Mandatory=$False)][string]$ResourceGroupName="rg-avd-$Environment-pool-$HostPoolKind-$LocationName",
    [Parameter(Mandatory=$False)][ValidateSet("Desktop","RailApplications")][string]$PreferredAppGroupType,
    [Parameter(Mandatory=$False)][ValidateSet("BreadthFirst","DepthFirst","Persistent")][string]$LoadBalancerType,
    [Parameter(Mandatory=$False)][string]$HostPoolFriendlyName,
    [Parameter(Mandatory=$False)][string]$SubscriptionName="$Environment-CorporateServices-VDI",
    [Parameter(Mandatory=$False)][string]$UserUPN,
    [Parameter(Mandatory=$False)][int]$SessionLimit,
    [Parameter(Mandatory=$False)][int]$VMcount=1,
    [Parameter(Mandatory=$False)][string]$WorkspaceName,
    [Parameter(Mandatory=$False)][string]$Domain
)

function Write-Log {
    param($msg)
    Write-Output $msg
    Write-Error $msg -ErrorAction Stop
}
function New-HostPool {
    <#
   .SYNOPSIS
    Create new host pool.
     
   .DESCRIPTION
    Takes in parameter HostPoolName, looks for existing HostPool with that Name, if none found created HostPool
    Takes in ResourceGroupName, SessionLimit, HostPoolType, and AppGroupType to configure HostPool
   
   .EXAMPLE
    $HostPool = (New-HostPool -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -HostPoolType $HostPoolType -LoadBalancerType $LoadBalancerType -SessionLimit 5)
   #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True)][string] $HostPoolName,$ResourceGroupName,
        [Parameter(Mandatory=$True)][ValidateSet("Pooled","Personal")][string]$HostPoolType,
        [Parameter(Mandatory=$False)][ValidateSet("Desktop","RailApplications")][string]$PreferredAppGroupType='Desktop',
        [Parameter(Mandatory=$False)][ValidateSet("BreadthFirst","DepthFirst","Persistent")][string]$LoadBalancerType="DepthFirst",
        [Parameter(Mandatory=$False)][int]$SessionLimit=10
    )
    if(($HostPoolType -like "Pooled") -and ($LoadBalancerType -like "Persistent")){Write-Log -msg "Host Pool Type does not match Load Balancer Type! `nPooled Host Pools must be 'BreadthFirst' or 'DepthFirst'"}
    if($HostPoolType -like "Personal"){$
        $StartVMOnConnect       = $true
        $PreferredAppGroupType  = "Desktop"
        $LoadBalancerType       = "Persistent"
    }else{$StartVMOnConnect=$false}
    $RG = (Get-AzResourceGroup $ResourceGroupName -ErrorVariable NotPresent -ErrorAction SilentlyContinue)
    if(!($RG)) {Write-Log -msg "Resource Group not found!"}
    $HostPool = (Get-AzWVDHostPool -Name $HostPoolName -ResourceGroupName $ResourceGroupName -ErrorVariable NotPresent -ErrorAction SilentlyContinue)
    if (!($HostPool)){
        Write-Output "Host Pool '$($HostPoolName)' does not exist..."
        $parameters = @{
            Name                  = $HostPoolName
            ResourceGroupName     = $ResourceGroupName
            HostPoolType          = $HostPoolType
            LoadBalancerType      = $LoadBalancerType
            PreferredAppGroupType = $PreferredAppGroupType
            MaxSessionLimit       = $SessionLimit
            Location              = $LocationName
            FriendlyName          = $HostPoolFriendlyName
            StartVMOnConnect      = $StartVMOnConnect
            Tag=@{
                team="VDI_Team"
                env=$Environment
                managedBy="PowerShell"
                description="Azure Virtual Desktop"
            }
        }
        Write-Output $parameters
        Write-Output "Creating Host Pool '$($HostPoolName)' in Resource Group '$($ResourceGroupName)'"
        New-AzWvdHostPool @parameters | Out-Null
    } 
    else {Write-Output "Host Pool '$($HostPoolName)' already exists!"}
    #$HP = (Get-AzWVDHostPool -Name $HostPoolName -ResourceGroupName $ResourceGroupName)
    #return $HP
}
function New-ApplicationGroup {
    <#
    .SYNOPSIS
    Create new Application Group. 
        
    .DESCRIPTION
    Takes in mandatory parameter ResourceGroupName and HostPoolName
    Takes in optional parameter for the Application Group Name. 
    Takes in optional parameter for the type of resource for the application group.
    Returns Application Group 

    .EXAMPLE
    New-ApplicationGroup -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -AppGroupName $AppGroupName -AppGroupType $AppGroupType
    #>

    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True)][string]$AppGroupName,$ResourceGroupName,$HostPoolName,
        [Parameter(Mandatory=$True)][ValidateSet("Desktop","RemoteApp")][string]$AppGroupType
    )
    $RG = (Get-AzResourceGroup $ResourceGroupName -ErrorAction SilentlyContinue)
    $HostPool = (Get-AzWvdHostPool -Name $HostPoolName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue)
    $AG = (Get-AzWvdApplicationGroup -Name $AppGroupName -ResourceGroupName $ResourceGroupName -ErrorVariable NotPresent -ErrorAction SilentlyContinue)
    if (!($RG)) {Write-Log -msg  "Missing Resource Group!"}
    if (!($HostPool)){Write-Log -msg  "Missing Host Pool!"}
    if (!($AG)){
        Write-Output "Resource Group: '$($ResourceGroupName)'"
        Write-Output "Host Pool: '$($HostPoolName)'"
        Write-Output "Creating Application Group '$($AppGroupName)'."
        $parameters=@{
            Name                 = $AppGroupName
            ResourceGroupName    = $ResourceGroupName 
            ApplicationGroupType = $AppGroupType 
            HostPoolArmPath      = $($HostPool.id)
            Location             = $LocationName 
            Tag=@{
                team="VDI_Team"
                env=$Environment
                managedBy="PowerShell"
                description="Azure Virtual Desktop"
    }
}
        New-AzWvdApplicationGroup  @parameters  | Out-Null
    }
    else {Write-Output "Application Group '$($AppGroupName)' already exists!"}
    $AppGroup = (Get-AzWvdApplicationGroup -Name $AppGroupName -ResourceGroupName $ResourceGroupName)
    #return $AppGroup
}
function Set-AppGroupWorkspace {
    <#
    .SYNOPSIS
    Register AG with Workspace. 
    .EXAMPLE
    Set-AppGroupWorkspace -AppGroupName $AppGroupName -WorkspaceName $WorkspaceName -ResourceGroupName $ResourceGroupName 
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True)][string]$AppGroupName,$WorkspaceName,$ResourceGroupName,
        [Parameter(Mandatory=$False)][string]$WS_ResourceGroupName="rg-avd-$Environment-mgmt-$LocationName"
    )
    $AG = (Get-AzWvdApplicationGroup -Name $AppGroupName -ResourceGroupName $ResourceGroupName)
    $WS = (Get-AzWvdWorkspace -Name $WorkspaceName -ResourceGroupName $WS_ResourceGroupName)
    $AZSubID = $SubscriptionID
    if (!($AG)){Write-Log -msg  "Missing Application Group!"}
    if (!($WS)){Write-Log -msg  "Missing Workspace!"}
    $Verify = "/subscriptions/$($AZSubID)/resourcegroups/$($ResourceGroupName)/providers/Microsoft.DesktopVirtualization/applicationgroups/$AppGroupName"
    if ($WS.ApplicationGroupReference -contains $Verify ){Write-Log -msg "Application Group already registered!"}
    else {
            Write-Output "Workspace Name: '$($WorkspaceName)'"
            Write-Output "Workspace Resource Group: '$($WS_ResourceGroupName)'"
            Write-Output "Application Group: '$($AppGroupName)'"
            Write-Output "Registering Application Group '$($AppGroupName)' to Workspace '$($WorkspaceName)'"
            #Workspace Resource Group, not ApplicationGroup RG
            Register-AzWvdApplicationGroup  -ResourceGroupName $WS_ResourceGroupName `
                                            -WorkspaceName $WorkspaceName `
                                            -ApplicationGroupPath $($AG.id) `
                                            | Out-Null
    }
}

#Connect to Azure & Select Subscription
$User = "matthew.franklin@$($Domain).com"
Connect-AzAccount -AccountId $User | Out-Null
Select-AzSubscription -SubscriptionName $SubscriptionName | Out-Null

if(!($WorkspaceName)){
    if($AppGroupType -like "Desktop"){$WorkspaceName="vdws-$Environment-desktops-$LocationName"}
    if($AppGroupType -like "RemoteApp"){$WorkspaceName="vdws-$Environment-rageneral-$LocationName"}
    #if($HostPoolKind -like "RAPCI"){$WorkspaceName="vdws-$Environment-rasecure-$LocationName"}  
}

#Create HostPool
New-HostPool -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -HostPoolType $HostPoolType

#Create Application Group
New-ApplicationGroup -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -AppGroupName $AppGroupName -AppGroupType $AppGroupType

#Assign App Group to AVD Workspace
$AG = Get-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupName -Name $AppGroupName 
if(!$($AG.WorkspaceArmPath)){
    Set-AppGroupWorkspace -AppGroupName $AppGroupName -WorkspaceName $WorkspaceName -ResourceGroupName $ResourceGroupName
}
else {Write-Output "Application Group $AppGroupName is already assigned to Workspace $($AG.WorkspaceArmPath.Split("/")[-1])"}

#Deploy AVD Session Host
if($HostPoolType -like "Personal"){
    Write-Output "Deploy Personal Session Host"
    & New-AVDComputer\New-AVDSessionHost.ps1 -UserUPN $UserUPN -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName
    }
else{
    Write-Output "Deploy Pooled Session Host"
    & New-AVDComputer\New-AVDSessionHost.ps1 -ResourceGroupName $ResourceGroupName  -HostPoolName $HostPoolName -OUPath "OU=rpos,OU=Pooled,OU=NonProd,OU=AVD,OU=Workstations,DC=$($Domain),DC=net" -SubnetName "snet-avd-nonprd-012" -ImageName "img-avd-nonprod-W11-V2-westus2" -ComputerPrefix "avms-n-rpos" -VMcount $VMcount
}
