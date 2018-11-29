<#PSScriptInfo

.VERSION 0.1.000

.AUTHOR m.sigg@diverto.ch , t.leuenberger@diverto.ch

.COMPANYNAME diverto gmbh

.RELEASENOTES


#>


$ErrorActionPreference = 'silentlycontinue'

################## RMM Environment und Testlab Variablen #####################
# Eventlog Name welche auf dem RMM Kunden gesetzt wurde
$eventlogname = "EventTesting"
<#
$eventlogname = $env:mspEventLog
if ($env:mspEventLog -eq $null)
{
    # Name des Eventlogs
    $eventlogname = "EventTesting"
}
#>

$eventsource = $env:eventsource
if ($env:eventsource -eq $null)
{
    # Name der Eventlog Quelle
    $eventsource = "NAS Monitoring Synology"
}

$ipadress = $env:IP
if ($env:IP -eq $null)
{
    # IP Adresse des Synology NAS angeben mit ""
    $ipadress = "10.1.1.80"
}

$volumeOIDtocheck = $env:OID
if ($env:OID -eq $null)
{
    # Für Auflistung aller Volume OIDs auf "" setzten ($volumeOIDtocheck = "")
    $volumeOIDtocheck = ""
}

$minfreeGB = $env:minfree
if ($env:minfree -eq $null)
{
    # Schwellenwert für freien Speicherplatz in GB
    $minfreeGB = 500
}

################## Globale Variablen #####################
$eventIDinfo = 4000
$eventIDwarnung = 4001
$eventloginfo = ""
$errorcount = 0
$SNMP = new-object -ComObject olePrn.OleSNMP
$snmp.open($ipadress, "public", 5, 3000)
$nasmodelName = $snmp.Get(".1.3.6.1.4.1.6574.1.5.1.0")
$nasserialnumber = $snmp.Get(".1.3.6.1.4.1.6574.1.5.2.0")
$nasdsmversion = $snmp.Get(".1.3.6.1.4.1.6574.1.5.3.0")
$nasuptime = $snmp.Get(".1.3.6.1.2.1.25.1.1.0")
$nasuptime = [Math]::Round($nasuptime / 8640000 , 2) #Ausgabe in Tagen

$eventloginfo = $eventloginfo + "NAS Modell: $nasmodelName" + -join "`n"
$eventloginfo = $eventloginfo + "NAS IP: $ipadress" + -join "`n"
$eventloginfo = $eventloginfo + "NAS S/N: $nasserialnumber" + -join "`n"
$eventloginfo = $eventloginfo + "DSM Version: $nasdsmversion" + -join "`n"
$eventloginfo = $eventloginfo + "Laufzeit in Tagen: $nasuptime" + -join "`n"
$eventloginfo = $eventloginfo + -join "`n"

################## Erstellung Eventlog und Event Source #####################
# Wenn das Eventlog nicht vorhanden ist, erstelle dieses
$eventlognamecheck = Get-EventLog -list | Where-Object {$_.logdisplayname -eq $eventlogname}
if (! $eventlognamecheck)
{
    New-EventLog -LogName $eventlogname -source $eventsource 
}

# Wenn die Eventsource nicht vorhanden ist, erstelle diese
$eventsourcecheck = [System.Diagnostics.EventLog]::SourceExists($eventsource) -eq $true
if (! $eventsourcecheck)
{
    New-Eventlog -source $eventsource -logname $eventlogname
}

################## Check free disk space and convert TB to GB (String to double) if check returns TB value #####################
$nasvolumename = $snmp.Get(".1.3.6.1.2.1.25.2.3.1.3.$volumeOIDtocheck")
$nasdisktotal = $snmp.Get(".1.3.6.1.2.1.25.2.3.1.5.$volumeOIDtocheck")
$nasdiskused = $snmp.Get(".1.3.6.1.2.1.25.2.3.1.6.$volumeOIDtocheck")
$nasdiskunit = $snmp.Get(".1.3.6.1.2.1.25.2.3.1.4.$volumeOIDtocheck")
$nasdisktotalGB = [Math]::Round($(($nasdisktotal * $nasdiskunit / 1024 / 1024 / 1024)) , 2)
$nasdisktotalTB = [Math]::Round(($nasdisktotalGB / 1024) , 2)
$nasdiskfreeGB = [Math]::Round($((($nasdisktotal - $nasdiskused) * $nasdiskunit / 1024 / 1024 / 1024)) , 2)
$nasdiskfreeTB = [Math]::Round(($nasdiskfreeGB / 1024) , 2)

if ($volumeOIDtocheck -ne "" -or $null)
{
    if ($nasdiskfreeGB -ge $minfreeGB)
    {
        if ($nasdiskfreeGB -gt 1024)
        {
            $eventloginfo = $eventloginfo + "OK - Volume (Name: $nasvolumename) hat noch $nasdiskfreeTB TB von $nasdisktotalTB TB verfuegbar. Definierter Schwellenwert: $minfreeGB GB" + -join "`n"
        }
        else
        {
            $eventloginfo = $eventloginfo + "OK - Volume (Name: $nasvolumename) hat noch $nasdiskfreeGB GB von $nasdisktotalTB TB verfuegbar. Definierter Schwellenwert: $minfreeGB GB" + -join "`n"
        }
        
    }
    else
    {
        if ($nasdiskfreeGB -gt 1024)
        {
            Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$ipadress - Volume (Name: $nasvolumename) hat nur noch $nasdiskfreeTB TB von $nasdisktotalTB TB verfuegbar. Definierter Schwellenwert: $minfreeGB GB"
            $errorcount++     
        }
        else
        {
            Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$ipadress - Volume (Name: $nasvolumename) hat noch $nasdiskfreeGB GB von $nasdisktotalTB TB verfuegbar. Definierter Schwellenwert: $minfreeGB GB"
            $errorcount++
        }
    }
}
else
{
    $eventloginfo = $eventloginfo + "Fehler - Volume OID nicht definiert" + -join "`n"
    $errorcount++
}

################## Check System Temperatur #####################
$nassystemtemp = 1
$nassystemtempoid = 0
while ($nassystemtemp -ne '')
{
    $nassystemtemp = ''
    $nassystemtemp = $snmp.Get(".1.3.6.1.4.1.6574.1.2.$nassystemtempoid")
    $nassystemtempoid++

    if ($nassystemtemp -ne '')
    {
        if ($nassystemtemp -le 60)
        {
            $eventloginfo = $eventloginfo + "OK - Systemtemperatur = $nassystemtemp Grad" + -join "`n"
        }
        elseif ($nassystemtemp -ge 61)
        {
            Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$ipadress Systemtemperatur = $nassystemtemp Grad"
            $errorcount++
        }
        else
        {
            Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$ipadress - Systemtemperatur = unbekannt"
        }
    }
    else
    {
    }
}

################## Check SystemFan Status #####################
$nassystemfanstatus = 1
$nassystemfanoid = 0
while ($nassystemfanstatus -ne '')
{
    $nassystemfanstatus = ''
    $nassystemfanstatus = $snmp.Get(".1.3.6.1.4.1.6574.1.4.1.$nassystemfanoid")
    $nassystemfanoid++

    if ($nassystemfanstatus -ne '')
    {
        if ($nassystemfanstatus -eq 1)
        {
            $eventloginfo = $eventloginfo + "OK - SystemFan$nassystemfanoid Status = Normal" + -join "`n"
        }
        else
        {
            if ($hddstatus -eq 2)
            {
                Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$ipadress - SystemFan$nassystemfanoid Status = Failed(2):One of internal fan stopped."
                $errorcount++
            }
            else
            {
                Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$ipadress - SystemFan$nassystemfanoid (SystemFan Status = $nassystemfanstatus)"
                $errorcount++
            }
            else {
            }
        }
    }
}

################## Check CPUFan Status #####################
$nascpufanstatus = 1
$nascpufanoid = 0
while ($nascpufanstatus -ne '')
{
    $nascpufanstatus = ''
    $nascpufanstatus = $snmp.Get(".1.3.6.1.4.1.6574.1.4.2.$nascpufanoid")
    $nascpufanoid++

    if ($nascpufanstatus -ne '')
    {
        if ($nascpufanstatus -eq 1)
        {
            $eventloginfo = $eventloginfo + "OK - CPUFan$nascpufanoid Status = Normal" + -join "`n"
        }
        else
        {
            if ($hddstatus -eq 2)
            {
                Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$ipadress - CPUFan$nascpufanoid Status = Failed(2):One of CPU fan stopped."
                $errorcount++
            }
            else
            {
                Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$ipadress - CPUFan$nascpufanoid (SystemFan Status = $nascpufanstatus)"
                $errorcount++
            }
            else {
            }
        }
    }
}

################## Check Disk Temperatur #####################
$hddtemp = 1
$hddtempoid = 0
while ($hddtemp -ne '')
{
    $hddtemp = ''
    $hddtemp = $snmp.Get(".1.3.6.1.4.1.6574.2.1.1.6.$hddtempoid")
    $hddmodel = $snmp.Get(".1.3.6.1.4.1.6574.2.1.1.3.$hddtempoid")
    $hddtempoid++

    if ($hddtemp -ne '')
    {
        if ($hddtemp -ge 60)
        {
            Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$ipadress - Die HDD$hddtempoid hat $hddtemp Grad Temperatur - HDD Modell: $hddmodel"
            $errorcount++
        }
        else
        {
            $eventloginfo = $eventloginfo + "OK - Die HDD$hddtempoid hat $hddtemp Grad Temperatur" + -join "`n"
        }
    }
    else
    {
    }
}

################## Check Disk State (SMART Status) #####################
$hddstatus = 1
$hddstatusoid = 0
while ($hddstatus -ne '')
{
    $hddstatus = ''
    $hddstatus = $snmp.Get(".1.3.6.1.4.1.6574.2.1.1.5.$hddstatusoid")
    $hddmodel = $snmp.Get(".1.3.6.1.4.1.6574.2.1.1.3.$hddtempoid")
    $hddstatusoid++

    if ($hddstatus -ne '')
    {
        if ($hddstatus -eq 1)
        {
            $eventloginfo = $eventloginfo + "OK - HDD$hddstatusoid Status = Normal" + -join "`n"
        }
        else
        {
            if ($hddstatus -eq 2)
            {
                Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$ipadress - HDD$hddstatusoid Status = Initialized(2):The hard disk has system partition but no data. - HDD Modell: $hddmodel"
                $errorcount++
            }
            elseif ($hddstatus -eq 3)
            {
                Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$ipadress - HDD$hddstatusoid Status = NotInitialized(3):The hard disk does not have system in system partition. - HDD Modell: $hddmodel"
                $errorcount++
            }
            elseif ($hddstatus -eq 4)
            {
                Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$ipadress - HDD$hddstatusoid Status = SystemPartitionFailed(4):The system partitions on the hard disks are damaged. - HDD Modell: $hddmodel"
                $errorcount++
            }
            elseif ($hddstatus -eq 5)
            {
                Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$ipadress - HDD$hddstatusoid Status = Crashed(5):The hard disk has damaged. - HDD Modell: $hddmodel"
                $errorcount++
            }
            else
            {
                Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$ipadress - HDD$hddstatusoid (Synology disk status = $hddstatus) - HDD Modell: $hddmodel"
                $errorcount++
            }
            else {
            }
        }
    }
}

################## Check RAID State #####################
$raidstatus = 1
$raidstatusoid = 0
while ($raidstatus -ne '')
{
    $raidstatus = ''
    $raidstatus = $snmp.Get(".1.3.6.1.4.1.6574.3.1.1.3.$raidstatusoid")
    $raidstatusoid++

    if ($raidstatus -ne '')
    {
        if ($raidstatus -eq 1)
        {
            $eventloginfo = $eventloginfo + "OK - RAID Nr.$raidstatusoid Status = Normal" + -join "`n"
        }
        else
        {
            if ($raidstatus -eq 11)
            {
                Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$ipadress - RAID Nr.$raidstatusoid Status = Degrade(11):Degrade happens when a tolerable failure of disk(s) occurs."
                $errorcount++
            }
            elseif ($raidstatus -eq 12)
            {
                Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$ipadress - RAID Nr.$raidstatusoid Status = Crashed(12):Raid has crashed and just uses for read-only operation."
                $errorcount++
            }
            else
            {
                Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$ipadress - RAID Nr.$raidstatusoid (Synology Raid status = $raidstatus)"
                $errorcount++
            }
            else {
            }
        }
    }
}


################## Check if upgrade is available #####################
# Prüfen ob Meldung zu DSM Upgrade in den letzten x Minuten im Eventlog vorhanden ist
$dsmupgradecheck = get-eventlog -LogName $eventlogname -InstanceId $eventIDwarnung -After (get-date).addminutes(-10080) -Source $eventsource
# Wenn nicht im Eventlog vorhanden prüfung durchführen und Info schreiben
$eventlogdsmupgradegefunden = $false
foreach ($message in $dsmupgradecheck.Message)
{
    if ($dsmupgradecheck.Message -like "*$ipadress - DSM Upgrade Status*")
    {
        $eventlogdsmupgradegefunden = $true
    }
}
if (!$eventlogdsmupgradegefunden)
{
    if ($dsmupgradecheck.Message -notlike "*$ipadress - DSM Upgrade Status*")
    {
        $upgradestatus = ''
        $upgradestatus = $snmp.Get(".1.3.6.1.4.1.6574.1.5.4.0")

        if ($upgradestatus -ne '')
        {
            if ($upgradestatus -eq 2)
            {
                $eventloginfo = $eventloginfo + "DSM Upgrade Status = You've already the latest DSM version running." + -join "`n"
            }
            else
            {
                if ($upgradestatus -eq 1)
                {
                    Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$ipadress - DSM Upgrade Status = Available: There is a new version ready for download."
                    $errorcount++
                }
                elseif ($upgradestatus -eq 3)
                {
                    Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$ipadress - DSM Upgrade Status = Connecting: Checking for the latest DSM."
                    $errorcount++
                }
                elseif ($upgradestatus -eq 4)
                {
                    Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$ipadress - DSM Upgrade Status = Disconnected: Failed to connect to server."
                    $errorcount++
                }
                elseif ($upgradestatus -eq 5)
                {
                    Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$ipadress - DSM Upgrade Status = Other: If DSM is upgrading or downloading."
                    $errorcount++
                }
                else
                {
                    Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$ipadress - DSM Upgrade Status = $upgradestatus"
                    $errorcount++
                }
            }
        }
    }
}

################## Show Volume OIDs if not set as Argument #####################
if ($volumeOIDtocheck -eq "" -or $null)
{
    $OIDcheckoutput = "Geprueftests NAS System: $ipadress" + -join "`n"
    $OIDcheckoutput = "$OIDcheckoutput" + "Auflistung aller Volumes und OIDs. OID des zu pruefenden Volume als Argument angeben!" + -join "`n"
    $OIDcheckoutput = "$OIDcheckoutput" + -join "`n"
    $nasvolumecheckoid = 1

    while ($nasvolumecheckoid -le 100)
    {
        $nasdiskunit = $snmp.Get(".1.3.6.1.2.1.25.2.3.1.4.$nasvolumecheckoid")
        $nasdisktotalcheck = $snmp.Get(".1.3.6.1.2.1.25.2.3.1.5.$nasvolumecheckoid")
        $nasdiskDescrcheck = $snmp.Get(".1.3.6.1.2.1.25.2.3.1.3.$nasvolumecheckoid")
        $nasdisktotalcheckGB = [Math]::Round($(($nasdisktotalcheck * $nasdiskunit / 1024 / 1024 / 1024)) , 2)

        if ($nasdisktotalcheck -ne '')
        {
            $OIDcheckoutput = "$OIDcheckoutput" + "Volume Name: $nasdiskDescrcheck | Total Speicherplatz: $nasdisktotalcheckGB GB | OID: $nasvolumecheckoid" + -join "`n"
        }
        
        $nasdisktotalcheck = ''
        $nasvolumecheckoid++
    }
    Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$OIDcheckoutput"
}

################## Write Info with System state to eventlog #####################
# Prüfen ob NAS Info Meldung in den letzten x Minuten im Eventlog vorhanden ist
$eventloginfocheck = get-eventlog -LogName $eventlogname -InstanceId $eventIDinfo -After (get-date).addminutes(-1440) -Source $eventsource
# Wenn nicht im Eventlog vorhanden prüfung durchführen und Info schreiben
$eventloginfogefunden = $false
foreach ($message in $eventloginfocheck.Message)
{
    if ($eventloginfocheck.Message -like "*NAS IP: $ipadress*")
    {
        $eventloginfogefunden = $true
    }
}
if (!$eventloginfogefunden)
{
    $eventloginfo = "$eventloginfo" + -join "`n" + "Anzahl gefundene Fehler: $errorcount" + -join "`n"
    Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Information -EventID $eventIDinfo -Message "$eventloginfo"
}