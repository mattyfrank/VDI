<#
    Map the FSLogix Share to your computer.
    New-PSDrive -Name "F" -Root "\\AVDFSL.file.core.windows.net\" -Persist -PSProvider "FileSystem"
#>
param($Path="F:\Profiles\RAGEN")
#Region Functions

#Get the size for the top largest VHDX files recursively under a directory. Return File Name and Size in GB.
function Get-Largest_Profiles {
    param(
        $Path='F:\Profiles\RAGEN',
        $Top = 10
        )
    $VHDs = Get-ChildItem -Path $Path -Recurse -Include *.vhdx
    $Output = $VHDs | Sort -Descending -Property Length | Select -First $Top Name, @{Name="Gigabytes";Expression={[Math]::round($_.length / 1GB, 2)}}
    return $Output
}

#Get the size for all VHDX files recursively under a directory. Return File Name and Size in GB.
function Get-Profile_Size {
    param($Path='F:\Profiles\RAGEN')
    $VHDs = Get-ChildItem -Path $Path -Recurse -Include *.vhdx
    $VHDs = $VHDs | Sort -Descending -Property Length | Select Name, @{Name="Gigabytes";Expression={[Math]::round($_.length / 1GB, 2)}}
    return $VHDs
}

#Get profiles for users that are disabled and missing from the domain (deleted).
function Get-Stale_Profiles {
    param($Path='F:\Profiles\RAGEN')

    $Directory = Get-ChildItem $Path
    [System.Collections.ArrayList]$results=@()

    foreach ($dir in $Directory){
        try {
            $userName = $dir.Name.split("_")[0]
            $obj = (Get-ADUser $userName -Properties Enabled)
        }catch {
            Write-Host "$($userName) not found in domain"
            $results.Add($($dir.Name)) | Out-Null
        }
        if ($obj.Enabled -eq $false){
            Write-Host "$($userName) is disabled"
            $results.Add($($dir.Name)) | Out-Null
        }
    }
    return $results
}
#EndRegion

#Region Main
#Create Report of the largest X number of profiles.
$LargestProfiles = Get-Largest_Profiles -Path $Path -Top 20
Write-Host `n "Report of the largest profiles:"
$LargestProfiles

#Create Report of Profile Sizes
$ProfileSizes = Get-Profile_Size -Path $Path
Write-Host `n "Report of all profiles and their size:"

#Create Report of User Profiles that are no longer Enabled. 
$Results = Get-Stale_Profiles -Path $Path
Write-Host `n "Report of all profiles that are not Enabled:"

#Remove Stale Profiles
$msg = "Press 'y' to permanently delete all profile containers for users that are not enabled: "
$confirm = $(Write-Host $msg -ForegroundColor DarkRed -NoNewline; Read-Host)
$confirm = $confirm.ToLower()
if($confirm -eq 'y'){
    foreach ($_ in $Results){
        $FullPath = "$Path\$_"
        Write-Host "Delete $($FullPath)"
        Remove-Item $FullPath -Recurse -Force -Confirm:$false
    }
}else{Write-Host "No action taken."}

#EndRegion

