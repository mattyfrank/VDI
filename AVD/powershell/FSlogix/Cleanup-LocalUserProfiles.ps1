#Get all directories under C:\Users
$AllUserDirs = (Get-ChildItem C:\Users -Directory)
#$AllUserDirs
#Filter Directories to remove Public and local_*
$userDirs = $AllUsers | where {($_.Name -notlike "local_*") -and ($_.Name -notlike "Public")}
#Filter to select directories that start with "_local*"
$localDirs = $AllUsers | where {($_.Name -like "local_*")}
#Format contents to remove "Local_"
$FSlogixProfiles = $localDirs.Name.Replace("local_","")
#Filter UserDirectories that are NOT IN $LocalDirs
$MissingLocal = $userDirs | where {$_.Name -notin $FSlogixProfiles}
$MissingLocal | % {$_.STATE}
$MissingLocal.Name
#Get Current Sessions
$ActiveSessions = qwinsta | where {$_ -match 'active'}
#Format Session Output
$SessionArray = $ActiveSessions -split('\s+')

#($MissingLocal.Name) | % {if($_ -in $SessionArray){Write-Output "$($_) is Active"}}
#Filter out active sessions
$Cleanup = ($MissingLocal.Name) | Where {$_ -notin $SessionArray}

#Delete Directories of Users missing FSlogix Profile and do not have active sessions
$Cleanup | % {Remove-Item $_ -Recurse -Force}