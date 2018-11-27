$ErrorActionPreference = 'silentlycontinue'

################## RMM Environment und Testlab Variablen #####################
$eventlogname = $env:eventlogname
if ($env:eventlogname -eq $null)
{
    # Name des Eventlogs
    $eventlogname = "EventTesting"
}

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
    $ipadress = "10.1.1.81"
}

$minfreeGB = $env:1, $env:2, $env:3, $env:4
if ($env:1 -eq $null)
{
    # Schwellenwert für freien Speicherplatz in GB
    # Maximal 4 Volumes mit , trennen (z.B. $minfreeGB = 500,200)
    $minfreeGB = 500
}

################## Globale Variablen #####################
$eventIDinfo = 4000
$eventIDwarnung = 4001
$eventloginfo = ""
$errorcount = 0
$SNMP = new-object -ComObject olePrn.OleSNMP
$snmp.open($ipadress, "public", 5, 3000)
$hdnumber = $snmp.Get(".1.3.6.1.4.1.24681.1.3.10.0")
$volumenumber = $snmp.Get(".1.3.6.1.4.1.24681.1.2.16.0")
$nasmodelName = $snmp.Get(".1.3.6.1.4.1.24681.1.2.12.0")
$nashostname = $snmp.Get(".1.3.6.1.4.1.24681.1.2.13.0")
$nashostname = $nashostname.Substring(0, $nashostname.Length - 1) #Zeilenumbruch vom ausgelesenen Hostnamen entfernen
$nasuptime = $snmp.Get(".1.3.6.1.2.1.25.1.1.0")
$nasuptime = [Math]::Round($nasuptime / 8640000 , 2)

$eventloginfo = $eventloginfo + "NAS Modell: $nasmodelName" + -join "`n"
$eventloginfo = $eventloginfo + "Anzahl Festplatten: $hdnumber" + -join "`n"
$eventloginfo = $eventloginfo + "Anzahl Volumes: $volumenumber" + -join "`n"
$eventloginfo = $eventloginfo + "Hostname: $nashostname" + -join "`n"
$eventloginfo = $eventloginfo + "NAS IP: $ipadress" + -join "`n"
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
    new-eventlog -source $eventsource -logname $eventlogname
}

################## Convert TB to GB (String to double) if check returns TB value #####################
$hddvolumecount = 1
while ($hddvolumecount -le $volumenumber)
{
    $nasdisksizetotal = $snmp.Get(".1.3.6.1.4.1.24681.1.2.17.1.4.$hddvolumecount")
    $nasfreedisk = $snmp.Get(".1.3.6.1.4.1.24681.1.2.17.1.5.$hddvolumecount")

    if ($nasfreedisk -like "* TB")
    {
        [double]$intNasFreeDisk = $nasfreedisk.Substring(0, $nasfreedisk.Length - 3)
        $intNasFreeDisk = $intNasFreeDisk * 1024
    }
    else
    {
        [double]$intNasFreeDisk = $nasfreedisk.Substring(0, $nasfreedisk.Length - 3)
    }
    
    ################## Check available Space #####################
    $minfreeGBcurrentvolume = $minfreeGB[$hddvolumecount - 1]
    if ($intNasFreeDisk -ge $minfreeGB[$hddvolumecount - 1])
    {
        $eventloginfo = $eventloginfo + "OK - Volume$hddvolumecount hat noch $nasfreedisk von $nasdisksizetotal verfügbar. Definierter Schwellenwert: $minfreeGBcurrentvolume GB"
    }
    else
    {
        Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$nashostname : Volume$hddvolumecount hat nur noch $nasfreedisk von $nasdisksizetotal verfügbar. Definierter Schwellenwert: $minfreeGBcurrentvolume GB"
        $errorcount++
             
    }
    $hddvolumecount++
}
################## Check System Temperatur #####################
$nasTempStatus = $snmp.Get(".1.3.6.1.4.1.24681.1.2.6.0")
if (($nasTempStatus -le 59) -and ($nasTempStatus -gt 0))
{
    $eventloginfo = $eventloginfo + "OK - Systemtemperatur = $nasTempStatus Grad"
}
elseif ($nasTempStatus -ge 60)
{
    Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$nashostname : - Systemtemperatur = $nasTempStatus Grad"
    $errorcount++
}
else
{
    Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Information -EventID $eventIDwarnung -Message "Systemtemperatur unbekannt."
    $errorcount++
}

################## Check Disk Temperatur #####################
$hddtempcount = 1
while ($hddtempcount -le $hdnumber)
{
    $nasHDtemp = $snmp.Get(".1.3.6.1.4.1.24681.1.2.11.1.3.$hddtempcount")
    $hddmodel = $snmp.Get(".1.3.6.1.4.1.24681.1.2.11.1.5.$hddtempcount")
    $hddmodel = $hddmodel.Substring(0, $hddmodel.Length - 1)
    if ($nasHDtemp -ge 60)
    {
        Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$nashostname : - Die HDD$hddtempcount hat $nasHDtemp Grad Temperatur - HDD Modell: $hddmodel"
        $errorcount++
    }
    else
    {
        $eventloginfo = $eventloginfo + "OK - Die HDD$hddtempcount hat $nasHDtemp Grad Temperatur"
    }
    $hddtempcount++
}

################## Check Disk State (SMART Status) #####################
$hddstatuscount = 1
while ($hddstatuscount -le $hdnumber)
{
    $nasHDDStatus = $snmp.Get(".1.3.6.1.4.1.24681.1.2.11.1.7.$hddstatuscount")
    $hddmodel = $snmp.Get(".1.3.6.1.4.1.24681.1.2.11.1.5.$hddtempcount")
    if ($nasHDDStatus -eq "GOOD")
    {
        $eventloginfo = $eventloginfo + "OK - HDD$hddstatuscount Status = OK"
    }
    else
    {
        Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Warning -EventID $eventIDwarnung -Message "$nashostname : - HDD$hddstatuscount Status = $nasHDDStatus - HDD Modell: $hddmodel. Das NAS läuft seit "$nasuptime "Tag(en)"
        $errorcount++
    }
    $hddstatuscount++
}

################## Write Info with System state to eventlog #####################
$eventloginfo = "$eventloginfo" + -join "`n" + "Anzahl gefundene Fehler: $errorcount" + -join "`n"
Write-EventLog -LogName $eventlogname -Source $eventsource -EntryType Information -EventID $eventIDinfo -Message "$eventloginfo"
