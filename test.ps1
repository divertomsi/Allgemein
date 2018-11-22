$eventlogname = "divertoEvents"
$eventsource = "divNAS"

Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID 4005 -Message "Status = Failed(2):One of CPU fan stopped."
