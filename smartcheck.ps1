############ Thresholds #############
$PowerOnTime = 35063 #about 4 years constant runtime.
$PowerCycles = 4000 #4000 times of turning drive on and off
$Temperature = 60 #60 degrees celcius
############ End Thresholds #########
$DownloadLocation = "C:\Program Files\smartmontools\bin"
try {
    $TestDownloadLocation = Test-Path $DownloadLocation
    if (!$TestDownloadLocation) { choco install smartmontools -y --force }
}
catch {
    Write-Output "The installation of SMARTCTL failed. Error: $($_.Exception.Message)"
    exit 1
}
#update the smartmontools database
start-process -filepath "$DownloadLocation\update-smart-drivedb.exe" -ArgumentList "/S" -Wait
#find all connected HDDs
$HDDs = (& "$DownloadLocation\smartctl.exe" --scan -j | ConvertFrom-Json).devices
$HDDInfo = foreach ($HDD in $HDDs) { (& "$DownloadLocation\smartctl.exe" -t short -a -j $HDD.name) | convertfrom-json }

$DiskHealth = @{}
#Checking SMART status
$SmartFailed = $HDDInfo | Where-Object { $_.Smart_Status.Passed -ne $true }
if ($SmartFailed) { $DiskHealth.add('SmartErrors',"Smart Failed for disks: $($SmartFailed.serial_number)") }
#checking Temp Status
$TempFailed = $HDDInfo | Where-Object { $_.temperature.current -ge $Temperature }
if ($TempFailed) { $DiskHealth.add('TempErrors',"Temperature failed for disks: $($TempFailed.serial_number)") }
#Checking Power Cycle Count status
$PCCFailed = $HDDInfo | Where-Object { $_.Power_Cycle_Count -ge $PowerCycles }
if ($PCCFailed ) { $DiskHealth.add('PCCErrors',"Power Cycle Count Failed for disks: $($PCCFailed.serial_number)") }
#Checking Power on Time Status
$POTFailed = $HDDInfo | Where-Object { $_.Power_on_time.hours -ge $PowerOnTime }
if ($POTFailed) { $DiskHealth.add('POTErrors',"Power on Time for disks failed : $($POTFailed.serial_number)") }
 
if (!$DiskHealth) { $DiskHealth = "Healthy" }
