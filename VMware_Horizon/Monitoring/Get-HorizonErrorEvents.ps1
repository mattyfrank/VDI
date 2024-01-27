$ErrorActionPreference = 'Stop'

$ComputerName = [Net.Dns]::GetHostName()
$ComputerName = $ComputerName.ToUpper()

$HVSERVER="Horizon.Domain.Net"

$OutPath = "C:\Temp\HorizonErrors.json"
if(!(Test-Path $OutPath)){New-Item $OutPath}

#Get credentials
$Credentials = Import-Clixml "C:\Program Files\New Relic\newrelic-infra\custom-assets\$($ComputerName).cred"

$HVConnectionServer = $ComputerName

# Amount of days to go back for the logs
[int]$DaysBack=30
$date = get-date
$sinceDate = (get-date).AddDays(-$daysback)

function get-hverrorevents {
    param (
        [parameter(Mandatory = $true,
            HelpMessage = "Start date.")]
        $startDate,
        [parameter(Mandatory = $true,
            HelpMessage = "End Date.")]
        $endDate,
        [parameter(Mandatory = $true,
            HelpMessage = "The Horizon View Connection server object.")]
        [VMware.VimAutomation.HorizonView.Impl.V1.ViewObjectImpl]$HVConnectionServer
    )
    # Try to get the Desktop pools in this pod
    try {
        # create the service object first
        [VMware.Hv.QueryServiceService]$queryService = New-Object VMware.Hv.QueryServiceService
        # Create the object with the definiton of what to query
        [VMware.Hv.QueryDefinition]$defn = New-Object VMware.Hv.QueryDefinition
        # entity type to query
        $defn.queryEntityType = 'EventSummaryView'
        # Filter on just the user and the vlsi module
        $timeFilter = new-object VMware.Hv.QueryFilterBetween -property @{'memberName'='data.time'; 'fromValue' = $startDate; 'toValue' = $endDate}
        #$1=New-Object VMware.Hv.QueryFilterEquals -property @{'memberName'='data.severity'; 'value' = "WARNING"}
        $2=New-Object VMware.Hv.QueryFilterEquals -property @{'memberName'='data.severity'; 'value' = "ERROR"}
        #$3=New-Object VMware.Hv.QueryFilterEquals -property @{'memberName'='data.severity'; 'value' = "AUDIT_FAIL"}
        $orfilter=new-object VMware.Hv.QueryFilterOr
        $orfilters=@()
        #$orfilters+=$1
        $orfilters+=$2
        #$orfilters+=$3
        $orfilter.Filters=$orfilters
        $andfilter=new-object vmware.hv.queryfilterand
        $andfilter.filters+=$timeFilter
        $andfilter.filters+=$orfilter
        $defn.Filter = New-Object VMware.Hv.QueryFilterAnd -Property @{ 'filters' = $andfilter }

        # Perform the actual query
        [array]$queryResults= ($queryService.queryService_create($AdminSession.extensionData, $defn)).results
        # Remove the query
        $queryService.QueryService_DeleteAll($AdminSession.extensionData)
        # Return the results
        return $queryResults
    }
    catch {
        Write-Output 'There was a problem retreiving event data from the Horizon View Connection server.'
    }
}

# Connect to the Horizon View Connection Server
[VMware.VimAutomation.HorizonView.Impl.V1.ViewObjectImpl]$AdminSession = Connect-HVServer $HVserver -Credential $Credentials

$errorevents = @()

$events= get-hverrorevents -HVConnectionServer $AdminSession -startDate $sinceDate -endDate $date
foreach ($event in $events){
    $errorevents+=New-Object PSObject -Property @{"Event Type" = $event.data.eventType;
        "Pod" = $podname;
        "Severity" = $event.data.severity;
        "ErrorType" = $event.data.EventType;
        "Time" = $event.data.time;
        "Message" = $event.data.message;
        "Node" = $event.data.node;
        "User" = $event.namesdata.userdisplayname;
        "Machinename" = $event.namesdata.Machinename;
        "Poolname" = $event.namesdata.DesktopDisplayName
    }
}

Disconnect-HVServer -Server $AdminSession -Confirm:$false

write-output $errorevents | select-object -property Time,Node,message | sort-object -property Pod,Time | format-table * -autosize -wrap

$errorevents | Out-File $OutPath
return ($errorevents | ConvertTo-Json)