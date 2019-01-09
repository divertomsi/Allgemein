<#PSScriptInfo

.VERSION 0.1.004
#>
$skriptversion = "0.1.004"
<#
.AUTHOR m.sigg@diverto.ch , t.leuenberger@diverto.ch

.COMPANYNAME diverto gmbh

.RELEASENOTES
0.1.001 - Prüfung Show Volume OIDs fehlerhafte foreach Schleife behoben
0.1.002 - Eventlog Prüfung foreach Schleifen [$i] in Abfrage ergänzt
0.1.003 - Ergänzung Env Variable für Schreibinterval der Zusammenfassung als Info in das Eventlog 
0.1.004 - Ergänzung if Prüfung von Show Volume OIDs if not set as Argument. Ergänzung: -or $nasdisktotalTB -eq 0

#>

$ErrorActionPreference = 'silentlycontinue'

################## RMM Environment und Testlab Variablen #####################
# Eventlog Name welche auf dem RMM Kunden gesetzt wurde
$eventlogname = $env:mspEventLog
if ($env:mspEventLog -eq $null)
{
    # Name des Eventlogs
    $eventlogname = "EventTesting"
    write-host "EventLogName environment Variable nicht erkannt. Testumgebungs Variable gesetzt. Wert: $eventlogname"
}

$eventsource = $env:eventsource
if ($env:eventsource -eq $null)
{
    # Name der Eventlog Quelle
    $eventsource = "NAS Monitoring testing Synology"
    write-host "EventSource environment Variable nicht erkannt. Testumgebungs Variable gesetzt. Wert: $eventsource"
}

$ipadress = $env:IP
if ($env:IP -eq $null)
{
    # IP Adresse des NAS angeben mit ""
    $ipadress = "10.1.1.80"
    write-host "IP Adresse environment Variable nicht erkannt. Testumgebungs Variable gesetzt. Wert: $ipadress"
}

$volumeOIDtocheck = $env:OID
if ($env:OID -eq $null)
{
    # Für Auflistung aller Volume OIDs auf "" setzten ($volumeOIDtocheck = "")
    # Nach der ersten Prüfung OID des zu prüfenden Volumes angeben
    $volumeOIDtocheck = ""
    write-host "OID environment Variable nicht erkannt. Testumgebungs Variable gesetzt. Wert: $volumeOIDtocheck"
}

$minfreeGB = $env:minfree
if ($env:minfree -eq $null)
{
    # Schwellenwert für freien Speicherplatz in GB
    $minfreeGB = 500
    write-host "Speicherplatz environment Variable nicht erkannt. Variable für Testumgebung wurde gesetzt. Wert: $minfreeGB"
}

$writeinfominutes = $env:writeinfominutes
if ($env:writeinfominutes -eq $null)
{
    # Schreibe eine Zusammenfassung also Information in das Eventlog alle x Minuten
    $writeinfominutes = 1440 # Default 1440 Minuten = 24h
    write-host "Infor schreiben environment Variable nicht erkannt. Variable für Testumgebung wurde gesetzt. Wert: $writeinfominutes"
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
# Wenn Eventlog nicht vorhanden ist, erstellen
$eventlognamecheck = Get-EventLog -list | Where-Object {$_.logdisplayname -eq $eventlogname}
if (! $eventlognamecheck)
{
    New-EventLog -LogName $eventlogname -source $eventsource 
}

# Wenn Eventsource nicht vorhanden, erstellen
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

if ($volumeOIDtocheck -ne "" -or $volumeOIDtocheck -ne $null)
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
$nassystemtempoid = 0
$nassystemtemp = $snmp.Get(".1.3.6.1.4.1.6574.1.2.$nassystemtempoid")
if ($nassystemtemp -ne $null)
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

################## Check SystemFan Status #####################
$nassystemfanoid = 0
$nassystemfanstatus = $snmp.Get(".1.3.6.1.4.1.6574.1.4.1.$nassystemfanoid")
if ($nassystemfanstatus -ne $null)
{
    if ($nassystemfanstatus -eq 1)
    {
        $eventloginfo = $eventloginfo + "OK - SystemFan$nassystemfanoid Status = Normal" + -join "`n"
    }
    else
    {
        if ($nassystemfanstatus -eq 2)
        {
            Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$ipadress - SystemFan$nassystemfanoid Status = Failed(2):One of internal fan stopped."
            $errorcount++
        }
        else
        {
            Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$ipadress - SystemFan$nassystemfanoid (SystemFan Status = $nassystemfanstatus)"
            $errorcount++
        }
    }
}

################## Check CPUFan Status #####################
$nascpufanoid = 0
$nascpufanstatus = $snmp.Get(".1.3.6.1.4.1.6574.1.4.2.$nascpufanoid")
if ($nascpufanstatus -ne $null)
{
    if ($nascpufanstatus -eq 1)
    {
        $eventloginfo = $eventloginfo + "OK - CPUFan$nascpufanoid Status = Normal" + -join "`n"
    }
    else
    {
        if ($nascpufanstatus -eq 2)
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
# Prüfen ob Meldung zu DSM Upgrade in den definierter Zeit im Eventlog vorhanden ist (Zeit in Minuten)
$dsmupgradecheck = get-eventlog -LogName $eventlogname -InstanceId $eventIDwarnung -After (get-date).addminutes(-10080) -Source $eventsource
$i = 0
$eventlogdsmupgradegefunden = $false
foreach ($message in $dsmupgradecheck.Message)
{
    if ($dsmupgradecheck[$i].Message -like "*$ipadress - DSM Upgrade Status*")
    {
        $eventlogdsmupgradegefunden = $true
    }
    $i++
}

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
        # Wenn Upgrade verfügbar und nicht im Eventlog vorhanden Warnung in Eventlog schreiben
        if (!$eventlogdsmupgradegefunden)
        {
            if ($dsmupgradecheck.Message -notlike "*$ipadress - DSM Upgrade Status*")
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
$oidcheck = get-eventlog -LogName $eventlogname -InstanceId $eventIDwarnung -After (get-date).addminutes(-1440) -Source $eventsource
$i = 0
$eventlogoidgefunden = $false
foreach ($message in $oidcheck.Message)
{
    if ($oidcheck[$i].Message -like "*Geprueftests NAS System: $ipadress*")
    {
        $eventlogoidgefunden = $true
    }
    $i++
}

if (!$eventlogoidgefunden)
{
    if ($volumeOIDtocheck -eq "" -or $volumeOIDtocheck -eq $null -or $nasdisktotalTB -eq 0)
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
}

################## Write Info with System state to eventlog #####################
# Prüfen ob NAS Info Meldung in den definierter Zeit im Eventlog vorhanden ist (Zeit in Minuten)
$eventloginfocheck = get-eventlog -LogName $eventlogname -InstanceId $eventIDinfo -After (get-date).addminutes(-$writeinfominutes) -Source $eventsource
# Wenn nicht im Eventlog vorhanden prüfung durchführen und Info schreiben
$i = 0
$eventloginfogefunden = $false
foreach ($message in $eventloginfocheck.Message)
{
    if ($eventloginfocheck[$i].Message -like "*NAS IP: $ipadress*")
    {
        $eventloginfogefunden = $true
    }
    $i++
}
if (!$eventloginfogefunden)
{
    $eventloginfo = "$eventloginfo" + -join "`n" + "Anzahl gefundene Fehler: $errorcount" + -join "`n"
    $eventloginfo = "$eventloginfo" + -join "`n" + "Skript Version: $skriptversion" + -join "`n"
    Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Information -EventID $eventIDinfo -Message "$eventloginfo"
}
