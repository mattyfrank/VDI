##author: matthew.franklin
##updated: 10-21-2021
<#
.SYNOPSIS
This was designed to delete and remove resources within VMware and ActiveDirectory. 
Custom functions can be combined to remove all artifacts. 
.DESCRIPTION
!REQUIRED Modules! - VMware PowerCLI & ActiveDirectory.
Call functions as needed. Use tab complete on each function to see available parameters.
Functions were designed to be modular and used in combination to simplify routine tasks. 
Parameters could be optional or mandatory. If a parameter is not provided, some functions will auto-generate results. 
Assign a variable to a function, and use the variable in other functions as an input parameter.
.EXAMPLE 
Delete-GPO -GPOName $GPOName
.EXAMPLE
Cleanup -Datacenter vCenter.DOMAIN.net -GPOName "Xen-FSLogix-TEST-singlesession" -ComputerName "TEST-IMG" -OU "OU=VDI,OU=Workstations,DC=ad,DC=DOMAIN,DC=NET" -FolderPath "\\SERVER\vlab_upm1\TEST" -CS "TEST-IMG" -VMName "TEST-IMG" -VMFolder "TEST"
#>
function Connect-Vcenter {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True,HelpMessage="Select vCenter: VDI_DC1/VDI_DC2, or DC2/DC1.")]
        [ValidateSet("vdi_vCenter1.DOMAIN.net","vCenter1.DOMAIN.net","vCenter2.DOMAIN.net","vdi_vCenter2.DOMAIN.net")][string] $Datacenter
    )
     Write-Host -ForegroundColor Green "Connecting to '$($Datacenter)'"
     Connect-VIServer $Datacenter
 }
function Delete-GPO {
    [CmdletBinding(SupportsShouldProcess=$true)]param ($GPOName)
    Write-Host "Deleting GPO $GPOName"
    Get-GPO -Name $GPOName | Remove-GPO -Confirm:$false | Out-Null
}
function Delete-Computer {
    [CmdletBinding(SupportsShouldProcess=$true)]param ($ComputerName)
    Write-Host "Deleting AD Computer Object $ComputerName"
    Get-ADComputer -Identity $ComputerName | Remove-ADComputer -Confirm:$false | Out-Null
}
function Delete-OU {
    [CmdletBinding(SupportsShouldProcess=$true)]param ($OU)
    Write-Host "Deleting AD OU $OU"
    Get-ADOrganizationalUnit -Identity $OU | Set-ADObject -ProtectedFromAccidentalDeletion:$false -PassThru | Remove-ADOrganizationalUnit -Confirm:$false | Out-Null
}
function Delete-Folder {
    [CmdletBinding(SupportsShouldProcess=$true)]param ($FolderPath)
    Write-Host "Deleting User Profile Folder $FolderPath"
    Get-Item -Path $FolderPath | Remove-Item -Confirm:$false | Out-Null
} 
function Delete-Customization {
    [CmdletBinding(SupportsShouldProcess=$true)]param ($CS)
    Write-Host "Deleting VM Customization $CS"
    Get-OSCustomizationSpec -Name $CS | Remove-OSCustomizationSpec -Confirm:$false | Out-Null
}
function StopVM {
    [CmdletBinding(SupportsShouldProcess=$true)]param ($VMName)
    Write-Host "Stopping VM $VMName"
    Get-VM -Name $VMName | Stop-VM -Confirm:$false | Out-Null
}
function Delete-VM {
    [CmdletBinding(SupportsShouldProcess=$true)]param ($VMName)
    Write-Host "Deleting VM $VMName"
    Get-VM -Name $VMName | Remove-VM -Confirm:$false | Out-Null
}
function Delete-VMFolder{
    [CmdletBinding(SupportsShouldProcess=$true)]param ($VMFolder)
    Write-Host "Deleting vCenter VM Folder $VMFolder"
    Get-Folder -Name $VMFolder | Remove-Folder -Confirm:$false | Out-Null
}
function Disconnect-vCenter {
    [CmdletBinding(SupportsShouldProcess=$true)]param ($Datacenter)
    Write-Host "Disconnecting from vCenter"
    Disconnect-VIServer $Datacenter -Confirm:$false 
}

Function Cleanup {
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param([Parameter(Mandatory=$False)][string] $Datacenter,$GPOName,$ComputerName,$OU,$FolderPath,$CS,$VMName,$VMFolder)
    Start-Transcript C:\Temp\New-VLAB-Resources_$(get-date -format yyyyMMdd-hh:mm).txt
    $userinput = $(Write-Host "Resources can not be recovered once deleted!`nDo you want to Cleanup? (y)es/(n)o: " -ForegroundColor DarkRed -NoNewline; Read-Host)
    switch ($userinput){
    y {
        if(!($Datacenter)){$Datacenter = Read-Host "Enter vCenter Name"}
        Connect-Vcenter -Datacenter $Datacenter

        if(!($GPOName)){$GPOName = Read-Host "Enter GPO Name"}
        Delete-GPO -GPOName $GPOName

        if(!($ComputerName)){$ComputerName = Read-Host "Enter AD Computer Object Name"}
        Delete-Computer -ComputerName $ComputerName

        if(!($OU)){$OU = Read-Host "Enter AD Organizational Unit distinguishedName"}
        Delete-OU -OU $OU

        if(!($FolderPath)){$FolderPath = Read-Host "Enter Folder Path"}
        Delete-Folder -FolderPath $FolderPath

        if(!($CS)){$CS = Read-Host "Enter vCenter Customization Specification"}
        Delete-Customization -CS $CS

        if(!($VMName)){$VMName = Read-Host "Enter vCenter VM Name"}
        $VM = (Get-VM $VMName)
        if ($VM.ExtensionData.Runtime.PowerState -like "PoweredOn") {StopVM -VMName $VMName; Start-Sleep -Seconds 2}
        Delete-VM -VMName $VMName

        if(!($VMFolder)){$VMFolder = Read-Host "Enter vCenter VM Folder Name"}
        Delete-VMFolder -VMFolder $VMFolder

        if(!($Datacenter)){$Datacenter = Read-Host "Enter vCenter Name"}
        Disconnect-vCenter -Datacenter $Datacenter
        Stop-Transcript
        #Completed
    }
    default {break}
    }
}
