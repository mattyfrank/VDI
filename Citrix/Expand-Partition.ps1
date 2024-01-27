#requires -runasadministrator 

# Get Volume C size and then resize the volume
$drive_letter = "C"
$size = (Get-PartitionSupportedSize -DriveLetter $drive_letter)
Resize-Partition -DriveLetter $drive_letter -Size $size.SizeMax

