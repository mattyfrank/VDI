#Set Machine Catalog Minimal Functional Level 
Get-BrokerCatalog | Where {$_.minimumFunctionalLevel –eq ‘L7_9’} | Select name

$MC = get-content '.\update-MachineCatalog-list.txt'
ForEach ($C in $MC) {
    Get-BrokerCatalog –Name $C | Set-BrokerCatalog –MinimumFunctionalLevel ‘L7_20’
}


#Set Delivery Group Minimal Functional Level 
Get-BrokerDesktopGroup | Where {$_.minimumFunctionallevel -eq ‘L7_9’} | select name

L7_9 = 7.9
L7_20 = 1811


$DG = get-content '.\update-delivery-group-list.txt'
ForEach ($obj in $DG) {
    Get-BrokerDesktopGroup –Name $obj | Set-BrokerDesktopGroup –MinimumFunctionalLevel ‘L7_20’
}
