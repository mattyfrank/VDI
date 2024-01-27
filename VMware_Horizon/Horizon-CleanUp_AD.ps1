##Find GPOs that are linked but not enabled.
function Get-DisabledGPOs {
    param(
        [string]$filePath = "$env:USERPROFILE\Desktop\GPOReviewList.txt",
        [string]$TargetOU = "OU=VDI,OU=Workstations,DC=DOMAIN,DC=net"
    )

    #Step1: Target Parent OU, and all Child OUs. 
    $OUs = (Get-ADOrganizationalUnit -Filter * -SearchBase $TargetOU).DistinguishedName

    #Step2: Loop through the list of OUs
    foreach ($ou in $ous){
    
        #Step3: Get GPOs linked to the OU
        $GPlinks = ((Get-GPInheritance -Target $ou).GPOLinks.DisplayName)
    
        #Step4: Loop through GPO link
        foreach ($GPLink in $GPLinks){

            #Step5: Create a GPO report for the GPO linked GPO.
            [xml]$GPReport= (Get-GPOReport -Name $GPLink -ReportType Xml)

            #Step6: Verify all links are set to false(disabled)
            if ($GPReport.GPO.LinksTo.Enabled -notcontains 'true'){
                #Write-Output "'$($GPReport.GPO.Name)' is still linked, but disabled everywhere."
            
                #Step7: Add results to a new array list
                [array]$GPOReviewList += $($GPReport.GPO.Name)
            }
        }
    }

    #Step8: Verify & Sort list.
    #Write-Output "Linked and disabled GPOs:" `r $GPOReviewList
    #Write-Output `n"Before sorting: $($GPOReviewList.count)"
    [array]$uniqueList = $GPOReviewList | Select -Unique
    #Write-Output "After sorting: $($uniqueList.count)"`n

    #!After changing the comparison operator from "$_.Enabled -eq 'false'" to "$_.Enabled -notcontains 'true'" there are less false positives!
    #Step9: Double check that the GPOs in the list are not enabled, and list the OU where it is enabled.
    foreach ($gpo in $uniqueList){
        [xml]$report = Get-GPOReport -Name $gpo -ReportType Xml
        if ($report.GPO.LinksTo.Enabled -contains 'true'){
            foreach ($link in $report.gpo.LinksTo) {
                if ($link.Enabled -eq 'true'){
                    Write-Output "'$($report.GPO.Name)' is linked and enabled at OU Path: '$($link.SOMPath)'"`n
                }
            }
        }
        #Create new list where all links are disabled
        else {
            #Write-Output "GPO '$($report.GPO.Name)' links are disabled"
            [array]$finalList += $($report.GPO.Name)
            $finalList = $finalList | select -Unique
        }   
    }

    Write-Output "Final List: "`r $finalList
    #Step10: Export the report    
    $finalList | Out-File -FilePath $filePath 

    #Clear GPO review list for next run
    Remove-Variable *list -ErrorAction SilentlyContinue
}

##Convert Canonical Name to Distinguished Name
function Get-DistinguishedName {
    param ([string]$CanonicalName)
        $SplitName = $CanonicalName -split '/'
        [array]::reverse($SplitName)
        $DN = @()
        $DN += ($SplitName| select -SkipLast 1) -replace '^.*$', 'OU=$_'
        $DN += ($SplitName | ? { $_ -like '*.*' }) -split '\.' -replace '^.*$', 'DC=$_'
        return ($DN -join ',')
}

#Remove GPOs that are Disabled or Unlinked
#Do we need a GPO Backup Function? 
function Cleanup-GPOs {
    param ([string]$SearchString= "VDI*")
    $GPOs = (Get-GPO -All | where {$_.DisplayName -like "$SearchString*"})
    foreach ($gpo in $GPOs){
        [xml]$report = (Get-GPOReport -Guid $gpo.Id -ReportType Xml)
        if(!($report)){Write-Error "missing gpo";break}
        #GPOs with no links
        if ($report.GPO.LinksTo.Count -eq 0){
            Write-Output "'$($report.GPO.Name)' is not linked."
            [array]$GPOs_NotLinked += $($report.GPO.Name)
        }
        #GPO where All Links are Disabled
        if (($report.GPO.LinksTo.Enabled -notcontains 'true') -and ($report.GPO.LinksTo.Enabled -contains 'false')){
            Write-Output "'$($report.GPO.Name)' is linked but disabled everywhere."
            [array]$GPOs_AllLinksDisabled += $($report.GPO.Name)
        }
        #GPOs with Links Enabled and Disabled, output Disabled Links.
        if (($report.GPO.LinksTo.Enabled -contains 'false') -and ($report.GPO.LinksTo.Enabled -contains 'true')){
            foreach ($link in $report.gpo.LinksTo) {
                if ($link.Enabled -eq 'false'){
                    Write-Output "'$($report.GPO.Name)' is linked but disabled at OU Path: '$($link.SOMPath)'"
                    [array]$GPOS_Linked_Enabled_Disabled += $report.GPO.Name
                }
            }
        }
    }
    Write-Host -ForegroundColor Green `n"UNLINKED GPOs"
    Write-Output $GPOs_NotLinked
    $confirm = Read-Host "Are you sure you want to delete UNLINKED GPOs? (Y/N)"
    if ($confirm -like "y") {
        try {$GPOs_NotLinked | Remove-GPO} 
        catch {Write-Error "$_"}        
    } 
    else {Write-Host "Operation Canceled."}

    Write-Host -ForegroundColor Green `n"GPOs where All Links are Disabled"
    Write-Output $GPOs_AllLinksDisabled
    $confirm = Read-Host "Are you sure you want to delete DISABLED GPOs? (Y/N)"
    if ($confirm -like "y") {
        try {
            Write-Output "Deleting GPOs..."
            $GPOs_AllLinksDisabled | Remove-GPO
        } 
        catch {Write-Error "Failed to Delete GPOs"}        
    } 
    else {Write-Host "Operation Canceled."}

    Write-Host -ForegroundColor Green `n"GPOs Links that are Disabled"    
    Write-Output $GPOS_Linked_Enabled_Disabled
    $confirm = Read-Host "Are you sure you want to delete GPO Links that are Disabled? (Y/N)"
    if ($confirm -like "y") {
        foreach ($gpo in $GPOS_Linked_Enabled_Disabled){
            [xml]$report = (Get-GPOReport -Name $gpo -ReportType Xml)
            foreach ($link in $report.GPO.LinksTo){
                if($link.Enabled -eq 'false') {
                    Write-Output "'$($report.GPO.Name)' is linked to '$($link.SoMPath)' and Disabled"
                    try{
                        #Convert from Canonical to DistinguishedName
                        $DN = (Get-DistinguishedName -CanonicalName "$($link.SoMPath)")
                        Remove-GPLink -Name "$($report.GPO.Name)" -Target "$DN" 
                    }
                    catch {Write-Error "Failed to delete GPlink at $DN."} 
                }    
            }
        }   
    } 
    else {Write-Host "Operation Canceled."}
}

#Export Bitlocker Key from AD Computer Object
#could use PSobj instead of string for parameter. would not need to get-adcomputer, but would require passing a computer object.
function Export-BitlockerKey {
    param([string]$computerName)
    try{
        $computer = (Get-ADComputer $computerName -ErrorAction SilentlyContinue)
        $KeyObjects = (Get-ADObject -Filter * -SearchBase $($computer.DistinguishedName) -Properties * | Where-Object {$_.ObjectClass -eq "msFVE-RecoveryInformation"})
        #if(!($KeyObjects)){Write-Output "No Bitlocker Key Found for $computerName"; break}
        foreach ($key in $KeyObjects) {
            $keyExport = [PSCustomObject]@{
                ComputerName = $computer.Name;
                DNSName = $computer.DNSHostName;
                ComputerDN = $computer.DistinguishedName;
                KeyName = $key.Name;
                KeyDN = $Key.DistinguishedName;
                KeyGuid = $Key.ObjectGuid;
                KeyPassword = $key.'msFVE-RecoveryPassword'
            }
        }
    }
    catch{Write-Error "$computerName not found."; break}
    return $keyExport
}

##Delete Stale Computer Objects
function Cleanup-Computers {
    Param(
        [Parameter(Mandatory=$false)]
        [string]$SearchBase = "OU=VDI,OU=Workstations,DC=DOMAIN,DC=net",
        [int]$NumOfDays= 365,
        [switch]$RemoveStaleComputers,
        [switch]$ExportStaleComputers,
        [string]$StaleComputerPath= ".\StaleComputerList.csv",
        [switch]$RemoveNoLogonObj,
        [switch]$ExportNoLogonObj,
        [string]$NoLogonComputerPath= ".\NoLogonComputerList.csv",
        [switch]$ExportBitLockerKeys,
        [string]$KeyOutputPath= ".\ExportedBitlockerRecoveryKeys.csv"
    )
    #Create DateTime var based on the param
    [DateTime]$CutoffDate=(Get-Date).AddDays(-$NumOfDays)

    #Create var of Computer objects within the OU defined as SearchBase
    #$computers = Get-ADComputer -Filter * -SearchBase $SearchBase -Properties *
    #more efficient query
    $computers = (Get-ADComputer -Filter * -SearchBase $SearchBase -Properties CanonicalName, LastLogonDate, WhenCreated, OperatingSystem, OperatingSystemVersion, PasswordLastSet)

    #Create vars to take action on
    $Stale        = $computers | where {($_.LastLogonDate -lt $CutoffDate)}
    $ComputerList = $computers | where {($_.LastLogonDate -lt $CutoffDate) -and ($_.LastLogonDate -ne $null)}
    $NoLogon      = $computers | where {($_.LastLogonDate -eq $null) -and ($_.whenCreated -lt $CutoffDate)}
    #$DisabledComputers = $computers | Where {$_.Enabled -eq 'False'}

    ##Identification of computer accounts to be removed
    if ($ExportStaleComputers){
        try {
            Write-Output "Output Computer Objects that have not logged in within '$($NumOfDays)' days. This list includes computer objects that have Never Logged in."
            $ComputerList | Select Name, CanonicalName, LastLogonDate, Created, OperatingSystem, OperatingSystemVersion, PasswordLastSet, Enabled | Export-Csv -Path $StaleComputerPath -NoTypeInformation
            Write-Output "Successfully Exported List of Computers that have not been authenticated in Active Directory since $CutoffDate to $StaleComputerPath."
        } 
        catch {Write-Error "Failed to Export Computer Account List.  Please check file permissions for $StaleComputerPath."}
    }

    ##Identification of computer accounts to be removed
    if ($ExportNoLogonObj){
        try {
            Write-Output "Output Computer Objects that have not logged in, and were created over '$($NumOfDays)' days ago."
            $NoLogon | Select Name, CanonicalName, LastLogonDate, Created, OperatingSystem, OperatingSystemVersion, PasswordLastSet, Enabled | Export-Csv -Path $NoLogonComputerPath -NoTypeInformation
            Write-Output "Successfully Exported List of Computers that have not logged in, and were created over '$($NumOfDays)' days ago to $NoLogonComputerPath."
        } 
        catch {Write-Error "Failed to Export Computer Account List.  Please check file permissions for $NoLogonComputerPath."}
    }

    ##Bitlocker Key Export Process, export Keys for all Computers.
    if ($ExportBitLockerKeys) {
        $BitlockerKeys = @()
        foreach ($computer in $ComputerList.Name) {
            $keyExport  = (Export-BitlockerKey -computerName $computer)
            $BitlockerKeys += $keyExport 
        }
        if ($BitlockerKeys.Count -eq 0) {Write-Information "No AD Key objects found. Are you logged in as an Admin?"} 
        else {
            try {
                $BitlockerKeys | Export-Csv -Path $KeyOutputPath -NoTypeInformation
                Write-Output "Successfully exported Bitlocker Keys to  $KeyOutputPath"
            }
            catch {Write-Error "Failed to export BitlockerKeys. Check File Permissions."}
        }
    }

    ##Delete AD Computer Objects
    if ($RemoveStaleComputers) {
        if ($Stale.Count -gt 0) {
            Write-Output "WARNING: The following computer accounts will be deleted.  Please take note and ensure that these are no longer in use."
            $Stale | ft Name, LastLogonDate
            $confirm = (Read-Host "All of the $($Stale.Count) computer accounts listed above will be REMOVED!  Are you sure you want to proceed? (Y/N)")
            if ($confirm -like "y") {
                try {
                    #$stale | Disable-ADAccount
                    $Stale | Remove-ADObject -Recursive -Confirm:$false
                } 
                catch {Write-Error "Computer Accounts could not be deleted."} 
            } 
            else {Write-Host "Canceled: No Computer Objects were removed."}
        } 
        else {Write-Output "No computer accounts were found that would require cleanup. Exiting.";break}
    }  

    ##Review List of Computers with No Last Logon Date
    if ($RemoveNoLogonObj) {
        if ($NoLogon.count -gt 0){
            $NoLogon | ft Name, whenCreated
            $confirm = Read-Host "All of the computer accounts listed above will be REMOVED!  Are you sure you want to proceed? (Y/N)"
            if ($confirm -like "y") {
                    try {$NoLogon | Remove-ADObject -Recursive -Confirm:$false} 
                    catch {Write-Error "Computer Accounts could not be deleted."} 
            } 
            else {Write-Host "Canceled: No Computer Objects were removed."}
        } 
        else {Write-Output "No computer objects found matching the query."}
    }
}

##Delete Empty OUs
function Cleanup-EmptyOUs{
    param([string]$ParentOU = "OU=VDI,OU=Workstations,DC=DOMAIN,DC=net")
    $EmptyOUs = (Get-ADOrganizationalUnit -Filter * -SearchBase "$ParentOU" -Properties *| ?{!(Get-ADObject -Filter * -SearchBase $_.Distinguishedname -SearchScope 1)})
  
    foreach ($ou in $EmptyOUs){
        $confirm = Read-Host "Are you sure you want to Permantely Delete '$($OU)' (Y/N)"
        if ($confirm -like "y") {
            try{
                Write-Output "Deleting OU: '$($ou.DistinguishedName)'"
                if ($OU.ProtectedFromAccidentalDeletion -eq $true){
                    Write-Output "OU is protected, removing protection..."
                    Set-ADObject -Identity $($OU.DistinguishedName) -ProtectedFromAccidentalDeletion:$false -PassThru |Out-Null
                }
                Remove-ADOrganizationalUnit -Identity $($ou.DistinguishedName) -Confirm:$false
            }
            catch {Write-Error "OU could not be deleted."}
        }
        else{Write-Output "'$($ou.DistinguishedName)' was not deleted."}
    }     
}   

##Search all GPOs for User Right Assignment SeImpersonatePrivilege
function Get-ImpersonatePrivilege{
    $allGPOs = Get-GPO -All 
    $selectGPOs = $allGPOs | Where-Object {$_.displayname -like "CorpClient_*"}
    [array]$GPONames=@()
    foreach ($gpo in $selectGPOs){
        [xml]$GPOReport = Get-GPOReport -Guid $($gpo.id.Guid) -ReportType xml
        $assignment = $($GPOReport.GPO.Computer.ExtensionData.Extension.UserRightsAssignment) | ? {$_.Name -like "SeImpersonatePrivilege"}
        if ($($assignment.Member.Name.innerXml) -contains "NT AUTHORITY\Authenticated Users"){
            foreach ($link in $GPOReport.GPO.LinksTo){
                if($link.Enabled -eq 'true') {
                    $DN = (Get-DistinguishedName -CanonicalName "$($link.SoMPath)")
                    echo "'$($GPOReport.GPO.Name)' is enabled at '$($dn)'"
                }
            } 
            $GPONames += $($GPOReport.Gpo.Name)
        }
    }
    $GPONames | Out-File -FilePath "$env:UserProfile\Desktop\GPO-Report.txt"
}

#end