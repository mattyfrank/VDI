    
connect-azaccount -AccountId UserName@Domain.com | Out-Null
connect-azuread -AccountId UserName@Domain.com | Out-Null

##Prod
$subscription = Select-AzSubscription -SubscriptionName Prod-VDI
[ValidateLength (3,15)][string]$account= "AVD-FSL-Storage-Account" 
$ResourceGroupName= "rg-avd-prod-mgmt-westus2"
$OUPath= "OU=Management,OU=Prod,OU=AVD,OU=Workstations,DC=DOMAIN,DC=net"

#IF AD Authentication is broken, run this. 
#Update Kerberos Password Kerb1 & kerb2. There is a two stage update of the kerb tokens.
Update-AzStorageAccountADObjectPassword -ResourceGroupName $ResourceGroupName -StorageAccountName $account -Confirm:$false -RotateToKerbKey kerb1 #kerb2 

##Verify ad is connected, via az Portal, and/or the AD Object.

#AzPortal, go to Storage Account, and then Locate FileShares in the Left Pane. The AD status should be listed in this screen. 
$keys = Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -AccountName $account
$context = New-AzStorageContext -StorageAccountName $account -StorageAccountKey $($keys[0].Value)
$fileshare = (Get-AZStorageShare -Context $context).Name

#Verifies the status of the share
Debug-AzStorageAccountAuth -StorageAccountName $account -ResourceGroupName $ResourceGroupName -Verbose -UserName $($env:USERNAME) -Domain $($env:USERDOMAIN) -FilePath "\\$($account).file.core.windows.net\$($fileshare)"


