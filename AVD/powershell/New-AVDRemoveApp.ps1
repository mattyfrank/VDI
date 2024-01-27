<#
    .SYNOPSIS
    New Remote Application. 
    .EXAMPLE
    New-AVDRemoteApp.ps1 -ApplicationName $ApplicationName -AppGroupName $AppGroupName -ResourceGroupName $ResourceGroupName -AppFilePath $AppFilePath -CommandLineSetting $CommandLineSetting 
     
    -AppFilePath "C:\Program Files\Microsoft Office\root\Office16\VISIO.EXE" -ApplicationName "Visio"
#>
param(
    [Parameter(Mandatory=$True)][string]$ApplicationName,$AppGroupName,$ResourceGroupName,$AppFilePath,
    [Parameter(Mandatory=$False)][ValidateSet("DoNotAllow","Allow","Require")][string]$CommandLineSetting="DoNotAllow",
    [Parameter(Mandatory=$False)][string]$CommandLineArgs,
    [Parameter(Mandatory=$False)][string]$Description,
    [Parameter(Mandatory=$False)][string]$FriendlyName,
    [Parameter(Mandatory=$False)][int]$IconIndex=0,
    [Parameter(Mandatory=$False)][string]$IconPath=$AppFilePath
)
$AG=(Get-AzWvdApplicationGroup -Name $AppGroupName -ResourceGroupName $ResourceGroupName)
if (!($AG)){Write-Log -msg  "Missing Application Group!"}
if ($AG.ApplicationGroupType -ne "RemoteApp"){Write-Log -msg "Application Group Type is not RemoteApps"}

#If AppGroup Type is RemoteApp, Create Application under AppGroup
# if($AppGroupType -like "RemoteApp"){
#     if(!($ApplicationName) -or !($AppFilePath)){Write-Output "No Application Name or File Path"}
#     else{New-Application -ApplicationName $ApplicationName -AppGroupName $AppGroupName -ResourceGroupName $ResourceGroupName -CommandLineSetting 'DoNotAllow' -FilePath $AppFilePath}
# }else{Write-Output "Application Group Type is $($AppGroupType). No Remote Application Created"}

if(($CommandLineSetting -eq "Allow" -or "Require") -and ($CommandLineArgs -ne $null)){
    Write-Output "Command Line Setting are '$($CommandLineSetting)'"
    Write-Output "Command Line Arguments are '$($CommandLineArgs)'"
    $parameters = @{
        ResourceGroupName   = $ResourceGroupName
        GroupName           = $AppGroupName
        Name                = $ApplicationName
        FilePath            = $AppFilePath
        FriendlyName        = $FriendlyName
        Description         = $Description
        IconIndex           = $IconIndex
        IconPath            = $IconPath
        CommandLineSetting  = $CommandLineSetting
        CommandLineArgument = $CommandLineArgs
        ShowInPortal        = $true
    }
}
if (($CommandLineSetting -eq "DoNotAllow") -or $CommandLineArgs -eq $null){
    $parameters = @{
        ResourceGroupName   = $ResourceGroupName
        GroupName           = $AppGroupName
        Name                = $ApplicationName
        FilePath            = $AppFilePath
        FriendlyName        = $FriendlyName
        Description         = $Description
        IconIndex           = $IconIndex
        IconPath            = $IconPath
        CommandLineSetting  = $CommandLineSetting
        ShowInPortal        = $true
    } 
}
New-AzWvdApplication $parameters | Out-Null
$RemoteApp=(Get-AzWvdApplication -GroupName $AppGroupName -Name $ApplicationName -ResourceGroupName $ResourceGroupName)
return $RemoteApp