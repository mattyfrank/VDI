$SiteDBName = "Xen7Prod"
$LogDBName = "xen7log"
$MonitorDBName = "Xen7MonitorDB"
$cs="Server=$ServerName;Initial Catalog=$SiteDBName;Integrated Security=True"
$csLogging= "Server=$ServerName;Initial Catalog=$LogDBName;Integrated Security=True"
$csMonitoring = "Server=$ServerName;Initial Catalog=$MonitorDBName;Integrated Security=True"
 
Set-ConfigDBConnection -DBConnection $null
Set-AcctDBConnection -DBConnection $null
Set-AnalyticsDBConnection -DBConnection $null
Set-AppLibDBConnection -DBConnection $null
Set-OrchDBConnection -DBConnection $null
Set-TrustDBConnection -DBConnection $null
Set-HypDBConnection -DBConnection $null
Set-ProvDBConnection -DBConnection $null
Set-BrokerDBConnection -DBConnection $null
Set-EnvTestDBConnection -DBConnection $null
Set-SfDBConnection -DBConnection $null
Set-MonitorDBConnection -DataStore Monitor -DBConnection $null
Set-MonitorDBConnection -DBConnection $null
Set-LogDBConnection -DataStore Logging -DBConnection $null
Set-LogDBConnection -DBConnection $null
Set-AdminDBConnection -DBConnection $null
 
 
Set-AdminDBConnection -DBConnection $cs
Set-ConfigDBConnection -DBConnection $cs
Set-AcctDBConnection -DBConnection $cs
Set-AnalyticsDBConnection -DBConnection $cs
Set-HypDBConnection -DBConnection $cs              
Set-ProvDBConnection -DBConnection $cs
Set-AppLibDBConnection –DBConnection $cs
Set-OrchDBConnection –DBConnection $cs
Set-TrustDBConnection –DBConnection $cs
Set-PvsVmDBConnection -DBConnection $cs
Set-BrokerDBConnection -DBConnection $cs
Set-EnvTestDBConnection -DBConnection $cs
Set-SfDBConnection -DBConnection $cs
Set-LogDBConnection -DBConnection $cs
Set-LogDBConnection -DataStore Logging -DBConnection $null
Set-LogDBConnection -DBConnection $null
Set-LogDBConnection -DBConnection $cs
Set-LogDBConnection -DataStore Logging -DBConnection $csLogging
Set-MonitorDBConnection -DBConnection $cs
Set-MonitorDBConnection -DataStore Monitor -DBConnection $null
Set-MonitorDBConnection -DBConnection $null
Set-MonitorDBConnection -DBConnection $cs
Set-MonitorDBConnection -DataStore Monitor -DBConnection $csMonitoring
 
 
Test-AcctDBConnection -DBConnection $cs
Test-AdminDBConnection -DBConnection $cs
Test-AnalyticsDBConnection -DBConnection $cs
Test-AppLibDBConnection -DBConnection $cs
Test-BrokerDBConnection -DBConnection $cs
Test-ConfigDBConnection -DBConnection $cs
Test-EnvTestDBConnection -DBConnection $cs
Test-HypDBConnection -DBConnection $cs
Test-LogDBConnection -DBConnection $cs
Test-MonitorDBConnection -DBConnection $cs
Test-ProvDBConnection -DBConnection $cs
Test-SfDBConnection -DBConnection $cs
 
 
Get-AcctServiceStatus
Get-AdminServiceStatus
Get-AnalyticsServiceStatus
Get-AppLibServiceStatus
Get-BrokerServiceStatus
Get-ConfigServiceStatus
Get-EnvTestServiceStatus
Get-HypServiceStatus
Get-LogServiceStatus
Get-MonitorServiceStatus
Get-ProvServiceStatus
Get-SfServiceStatus
 
 