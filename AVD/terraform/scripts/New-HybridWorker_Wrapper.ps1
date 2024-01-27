######################################################################
param(
    [Parameter(Mandatory=$true)][ValidateSet("nonprod","prod")][string]$env
)

#InstallRSAT Tools
$Win_OS_Type = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").InstallationType
if ($Win_OS_Type -eq "Server"){
    #Write-Output "Windows Server detected"
    if ((Get-WindowsFeature RSAT-AD-PowerShell).InstallState -ne "Installed"){
        Write-Output "Try to install RSAT"
        #Import-Module ServerManager 
        Add-WindowsFeature -Name "RSAT-AD-PowerShell" –IncludeAllSubFeature
    }
}
if ($Win_OS_Type -eq "Client"){
    #Write-Output "Windows client detected"
    if ((Get-WindowsCapability -Name "Rsat.ActiveDirectory.DS-LDS.Tools*" -Online).State -ne "Installed"){
        Write-Output "Try to install RSAT"
        $AD = Get-WindowsCapability -Name "Rsat.ActiveDirectory.DS-LDS.Tools*" -Online 
        Add-WindowsCapability -Online -Name $AD.Name
    }
}

#Install Modules if needed. 
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

#Install PowerCLI
#Offline Installation files are here - https://developer.vmware.com/web/tool/vmware-powercli
Install-Module VMware.PowerCLI -scope AllUsers -Force -SkipPublisherCheck -AllowClobber

#Install Horizon Vew 
Get-Module VMware.VimAutomation.HorizonView -ListAvailable | Import-Module -Verbose

<# Install Horizon Helper Scripts
#Click Code and Download ZIP "https://github.com/vmware/PowerCLI-Example-Scripts"
#Extract ZIP, and locate "PowerCLI-Example-Scripts-master\Modules\VMware.Hv.Helper"
#Copy entire folder to PS Module Path. If necessary unblock the downloaded files.
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$WorkingDir = "C:\Temp"
cd $WorkingDir
$Output = "PowerCLI-Scripts"
Invoke-WebRequest -Uri "https://github.com/vmware/PowerCLI-Example-Scripts/archive/refs/heads/master.zip" -OutFile "$Output.zip"
Expand-Archive "$Output.zip"
cd "$WorkingDir\$Output\PowerCLI-Example-Scripts-master\Modules"
##Get-ChildItem * -Recurse | Unblock-File
##$Env:PSModulePath
Copy-Item -Path ".\VMware.Hv.Helper" -Destination "C:\Program Files\WindowsPowerShell\Modules" -Recurse -Force
Get-Module -ListAvailable 'Vmware.Hv.Helper' | Import-Module 
#>

#List all commands
#Get-Command -Module 'VMware.Hv.Helper'

#Disable Customer Feedback 
Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP $false -Confirm:$false

#AZSubscripton
#NonProd-CorporateServices-VDI   
if($env -eq "nonprod"){$subID = "f2d3f274-9c2e-4004-852a-d4ee1a4998ad"}
#Prod-CorporateServices-VDI 
if($env -eq "prod"){$subID = "271ba44d-c44b-48dc-90ab-0a56a5267fd4"}

Connect-AzAccount
Set-AzContext -Subscription $subID | Out-null
#Connect-AzureAD 

$ResourceGroupName = (Get-AzResourceGroup -Name "rg-avd-$($env)-mgmt-westus2").ResourceGroupName
$AAName = (Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name "aa-avd-$($env)-westus2").AutomationAccountName
$HybridGroupName = (Get-AzAutomationHybridWorkerGroup -Name "HybridWorkerGroup$($env)" -ResourceGroupName $ResourceGroupName -AutomationAccountName $AAName).Name
$WorkspaceName = (Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -Name "la-avd-$($env)-automation-westus2").Name

& .\New-OnPremiseHybridWorker `
    -SubscriptionID $subID `
    -AAResourceGroupName $ResourceGroupName `
    -AutomationAccountName $AAName `
    -HybridGroupName $HybridGroupName `
    -WorkspaceName $WorkspaceName

#