
param(
    $HVserver,
    $Domain,
    $CredPath = ".\creds.xml"
)
#Connect to Horizon
$creds = Import-Clixml $CredPath
$AdminSession = Connect-HVServer -Server $HVserver -Credential $Creds

#Get Horizon Permissions
$PermissionList = $AdminSession.ExtensionData.Permission.Permission_List()

#Get-Roles
$Roles= @{}
Foreach ($Role in $PermissionList.Base.Role) {
    $RoleID = $Role.Id
    If (!($Roles.ContainsKey($RoleID))) {
        $Roles[$RoleID] = ($AdminSession.ExtensionData.Role.Role_Get($Role)).Base.Name
    }
}
#Write-Output `n $Roles.Values

#Get-AccessGroups or Scopes of Permissions
$AccessGroups = @{}
Foreach ($AG in $PermissionList.Base.AccessGroup) {
    $AccessGroupID = $AG.Id
    If (!($AccessGroups.ContainsKey($AccessGroupID))) {
        $AccessGroups[$AccessGroupID] = ($AdminSession.ExtensionData.AccessGroup.AccessGroup_Get($AG)).base.name
    }
}
#Write-Output `n $AccessGroups.Values

#Get User or Group that is Granted Admin Access
$Admins = @{}
Foreach ($Admin in $PermissionList.Base.UserOrGroup) {
    $AdminID = $Admin.Id
    If (!($Admins.ContainsKey($AdminID))) {
        $Admins[$AdminID] = ($AdminSession.ExtensionData.AdminUserOrGroup.AdminUserOrGroup_Get($Admin)).base.displayname
    }
}
#Write-Output `n $Admins.Values

#Format Output
$Report=@()
[int]$count=0
Foreach ($Permission in $PermissionList){
    $obj=@{
        $count="$($Admins[$Permission.Base.UserOrGroup.Id]); $($Roles[$Permission.Base.Role.Id]); $($AccessGroups[$Permission.Base.AccessGroup.Id])"
        #$Admins[$Permission.Base.UserOrGroup.Id]= "$($Roles[$Permission.Base.Role.Id]); $($AccessGroups[$Permission.Base.AccessGroup.Id])"
    }
    $Report+=$Obj
    $count++
}
Write-Output `n $Report.Values

#Remove Domain Users
$Output = $Report | % {$_.Values} | ? {$_ -notlike "$($Domain)\Domain Users; *"}
Write-Output `n $Output

#$Output.Keys