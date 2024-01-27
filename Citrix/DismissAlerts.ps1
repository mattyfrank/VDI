try
    {
        asnp citrix*
		$Datastore = Get-MonitorDataStore

		$SiteString = $null
		$DBString = $null
		foreach($object in $Datastore)
		{
			if($object.DataStore -eq "Monitor")
			{
				$DBString = $object.ConnectionString
			}
			if($object.DataStore -eq "Site")
			{
				$SiteString = $object.ConnectionString

			}
		}
		
		Write-Output "Obtained the connection string"
		$MonitoringDBConnection =  $DBString
		$MonitoringSiteConnection = $SiteString

        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection
        $sqlConnection.ConnectionString = $MonitoringDBConnection
        $sqlConnection.Open()

        if ($sqlConnection.State -ne [Data.ConnectionState]::Open)
        {
             Write-Output "Connection to DB is not open."
             exit
        }

        Write-Output "Database connection opened"
			
    $sqlCommand = New-Object System.Data.SqlClient.SqlCommand
    $sqlCommand.Connection = $sqlConnection

    $sqlCommand.CommandText = "UPDATE MonitorData.Notification SET Notification.LifecycleState = 3 where Notification.NotificationRuleId 
    in (Select NotificationRule.Id from MonitorData.NotificationRule where NotificationRule.NotificationTemplateId like 'HypervisorHealth%') 
    AND Notification.LifecycleState != 3"

    $sqlCommand.ExecuteScalar()

    $sqlCommand.CommandText = "UPDATE MonitorData.NotificationLog SET NotificationLog.NotificationState = 6 where NotificationLog.NotificationRuleId 
    in (Select NotificationRule.Id from MonitorData.NotificationRule where NotificationRule.NotificationTemplateId like 'HypervisorHealth%') 
    AND NotificationLog.NotificationState != 6"

    $sqlCommand.ExecuteScalar()

    Write-Output "Hypervisor Alerts dismissed"

    }
    catch
    {
       "Error occured in dismissing alerts"
    }