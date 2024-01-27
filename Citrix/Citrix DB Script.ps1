add-pssnapin
asnp Citrix*

##restart services if below steps fail

Set-LogSite -State Disabled
##
Set-MonitorConfiguration -DataCollectionEnabled $False

##backup registry section 'hlmk\software\citrix'

## Replace <dbserver> with the New SQL server, and instance if present
## Replace <dbname> with the name of your restored Database
##
$ServerName="xen7prod.DOMAIN.net"

$DBName ="xen7prod"

#
$cs="Server=$ServerName; Initial Catalog=$DBName; Integrated Security=True"
$cs
Test-ConfigDBConnection -DBConnection $cs -AdminAddress $Controller
Test-AcctDBConnection -DBConnection $cs -AdminAddress $Controller
Test-HypDBConnection -DBConnection $cs -AdminAddress $Controller
Test-ProvDBConnection -DBConnection $cs -AdminAddress $Controller
Test-BrokerDBConnection -DBConnection $cs -AdminAddress $Controller
Test-EnvTestDBConnection -DBConnection $cs -AdminAddress $Controller
Test-SfDBConnection -DBConnection $cs -AdminAddress $Controller
Test-MonitorDBConnection -DBConnection $cs -AdminAddress $Controller
Test-MonitorDBConnection -DataStore Monitor -DBConnection $cs -AdminAddress $Controller
Test-AdminDBConnection -DBConnection $cs -AdminAddress $Controller
Test-LogDBConnection -DBConnection $cs -AdminAddress $Controller
Test-LogDBConnection -Datastore Logging -DBConnection $cs -AdminAddress $Controller

## First unregister the Delivery Controllers from the current database:
Set-ConfigDBConnection -DBConnection $null -AdminAddress $Controller
Set-AcctDBConnection -DBConnection $null -AdminAddress $Controller
Set-HypDBConnection -DBConnection $null -AdminAddress $Controller
Set-ProvDBConnection -DBConnection $null -AdminAddress $Controller
Set-BrokerDBConnection -DBConnection $null -AdminAddress $Controller
Set-EnvTestDBConnection -DBConnection $null -AdminAddress $Controller
Set-SfDBConnection -DBConnection $null -AdminAddress $Controller
Set-MonitorDBConnection -Datastore Monitor -DBConnection $null -AdminAddress $Controller
reset-MonitorDataStore -DataStore Monitor
Set-MonitorDBConnection -DBConnection $null -AdminAddress $Controller
Set-LogDBConnection -DataStore Logging -DBConnection $null -AdminAddress $Controller
reset-LogDataStore -DataStore Logging
Set-LogDBConnection -DBConnection $null -AdminAddress $Controller
Set-AdminDBConnection -DBConnection $null -AdminAddress $Controller

##if you see any errors restart services, might have to restart server
Get-Service Citrix* | Stop-Service -Force
Get-Service Citrix* | Start-Service

Get-AcctServiceStatus
Write-Host "AcctServiceStatus..."
Get-AdminServiceStatus
Write-Host "Testing AdminServiceStatus..."
Get-BrokerServiceStatus
Write-Host "Testing BrokerServiceStatus..."
Get-ConfigServiceStatus
Write-Host "Testing ConfigServiceStatus..."
Get-EnvTestServiceStatus
Write-Host "ConfigServiceStatus..."
Get-HypServiceStatus
Write-Host "HypServiceStatus..."
Get-LogServiceStatus
Write-Host "LogServiceStatus..."
Get-MonitorServiceStatus
Write-Host "MonitorServiceStatus..."
Get-ProvServiceStatus
Write-Host "ProvServiceStatus..."
Get-SfServiceStatus
Write-Host "SfServiceStatus..." 
 
Write-Host "AdminDBConnection..."
Get-AdminDBConnection
Write-Host "ConfigDBConnection..."
Get-ConfigDBConnection
Write-Host "AcctDBConnection..."
Get-AcctDBConnection
Write-Host "HypDBConnection..."
Get-HypDBConnection
Write-Host "ProvDBConnection..."
Get-ProvDBConnection
Write-Host "BrokerDBConnection..."
Get-BrokerDBConnection
Write-Host "EnvTestDBConnection..."
Get-EnvTestDBConnection
Write-Host "LogDBConnection..."
Get-LogDBConnection
Write-Host "MonitorDBConnection..."
Get-MonitorDBConnection
Write-Host "SfDBConnection..."
Get-SfDBConnection 

##verify null in registry \HLMK\Software\Citrix’

###############################################################
###################################Part 2#####################
###############################################################

## Replace <dbserver> with the New SQL server, and instance if present
## Replace <dbname> with the name of your restored Database
##
$ServerName="xen7prod.DOMAIN.net"
$DBName ="Xen7Prod_MAY24_RESTORE"
#
$cs="Server=$ServerName;Initial Catalog=$DBName;Integrated Security=True"
$cs
Set-AdminDBConnection -DBConnection $cs
Set-ConfigDBConnection -DBConnection $cs
Set-AcctDBConnection -DBConnection $cs
Set-HypDBConnection -DBConnection $cs
Set-ProvDBConnection -DBConnection $cs
##Set-PvsVmDBConnection -DBConnection $cs
Set-BrokerDBConnection -DBConnection $cs
Set-EnvTestDBConnection -DBConnection $cs
Set-LogDBConnection -DBConnection $cs
Set-LogDBConnection -DataStore Logging -DBConnection $cs
Set-MonitorDBConnection -DBConnection $cs
Set-MonitorDBConnection -DataStore Monitor -DBConnection $cs
Set-SfDBConnection -DBConnection $cs

##Enable Monitoring
Set-MonitorConfiguration -DataCollectionEnabled $true

##Enable Configuration Logging
Set-LogSite -State "Enabled"

##Restart Citrix Services

Get-Service Citrix* | Stop-Service -Force
Get-Service Citrix* | Start-Service

Get-AcctServiceStatus
Write-Host "AcctServiceStatus..."
Get-AdminServiceStatus
Write-Host "Testing AdminServiceStatus..."
Get-BrokerServiceStatus
Write-Host "Testing BrokerServiceStatus..."
Get-ConfigServiceStatus
Write-Host "Testing ConfigServiceStatus..."
Get-EnvTestServiceStatus
Write-Host "ConfigServiceStatus..."
Get-HypServiceStatus
Write-Host "HypServiceStatus..."
Get-LogServiceStatus
Write-Host "LogServiceStatus..."
Get-MonitorServiceStatus
Write-Host "MonitorServiceStatus..."
Get-ProvServiceStatus
Write-Host "ProvServiceStatus..."
Get-SfServiceStatus
Write-Host "SfServiceStatus..." 
 
Write-Host "AdminDBConnection..."
Get-AdminDBConnection
Write-Host "ConfigDBConnection..."
Get-ConfigDBConnection
Write-Host "AcctDBConnection..."
Get-AcctDBConnection
Write-Host "HypDBConnection..."
Get-HypDBConnection
Write-Host "ProvDBConnection..."
Get-ProvDBConnection
Write-Host "BrokerDBConnection..."
Get-BrokerDBConnection
Write-Host "EnvTestDBConnection..."
Get-EnvTestDBConnection
Write-Host "LogDBConnection..."
Get-LogDBConnection
Write-Host "MonitorDBConnection..."
Get-MonitorDBConnection
Write-Host "SfDBConnection..."
Get-SfDBConnection 

##Reboot Server
