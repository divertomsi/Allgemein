$ErrorActionPreference= 'silentlycontinue'

$ipadresse = $env:IP
$errorcount = 0
$SNMP = new-object -ComObject olePrn.OleSNMP
$snmp.open($ipadresse,"public",5,3000)
$nasmodelName = $snmp.Get(".1.3.6.1.4.1.6574.1.5.1.0")
$nasserialnumber = $snmp.Get(".1.3.6.1.4.1.6574.1.5.2.0")
$nasdsmversion = $snmp.Get(".1.3.6.1.4.1.6574.1.5.3.0")
$nasuptime = $snmp.Get(".1.3.6.1.2.1.25.1.1.0")
$nasuptime = [Math]::Round($nasuptime / 8640000 , 2)

################## Convert TB to GB (String to double) if check returns TB value #####################
$arg2OID = $env:OID

$nasvolumename = $snmp.Get(".1.3.6.1.2.1.25.2.3.1.3.$arg2OID")
$nasdisktotal = $snmp.Get(".1.3.6.1.2.1.25.2.3.1.5.$arg2OID")
$nasdiskused = $snmp.Get(".1.3.6.1.2.1.25.2.3.1.6.$arg2OID")
$nasdiskunit = $snmp.Get(".1.3.6.1.2.1.25.2.3.1.4.$arg2OID")
$nasdisktotalGB = [Math]::Round($(($nasdisktotal * $nasdiskunit / 1024 / 1024 / 1024)) , 2)
$nasdisktotalTB = [Math]::Round(($nasdisktotalGB / 1024) , 2)
$nasdiskfreeGB = [Math]::Round($((($nasdisktotal - $nasdiskused) * $nasdiskunit / 1024 / 1024 / 1024)) , 2)
$nasdiskfreeTB = [Math]::Round(($nasdiskfreeGB / 1024) , 2)

if ($nasdiskfreeGB -ge $env:minfree){
    if($nasdiskfreeGB -gt 1024){
        write-host "OK - Volume (Name: $nasvolumename) hat noch $nasdiskfreeTB TB von $nasdisktotalTB verfuegbar"
    }
    else{
        write-host "OK - Volume (Name: $nasvolumename) hat noch $nasdiskfreeGB GB von $nasdisktotalTB verfuegbar"
    }
     
}
else{
    if($nasdiskfreeGB -gt 1024){
        Write-EventLog -LogName divertoEvents -Source divNAS -EntryType Warning -EventID 4000 -Message "$ipadresse - Volume (Name: $nasvolumename) hat nur noch $nasdiskfreeTB TB von $nasdisktotalTB verfuegbar"
        $errorcount++     
    }
    else{
        Write-EventLog -LogName divertoEvents -Source divNAS -EntryType Warning -EventID 4000 -Message "$ipadresse - Volume (Name: $nasvolumename) hat noch $nasdiskfreeGB GB von $nasdisktotalTB verfuegbar"
        $errorcount++
    }
}

################## Check System Temperatur #####################

$nassystemtemp = 1
$nassystemtempoid = 0
while ($nassystemtemp -ne ''){
    $nassystemtemp = ''
    $nassystemtemp = $snmp.Get(".1.3.6.1.4.1.6574.1.2.$nassystemtempoid")
    $nassystemtempoid++

    if ($nassystemtemp -ne ''){
        if($nassystemtemp -le 60){
            write-host "OK - Systemtemperatur = $nassystemtemp Grad"
        }
        elseif($nassystemtemp -ge 61){
            Write-EventLog -LogName divertoEvents -Source divNAS -EntryType Warning -EventID 4001 -Message "$ipadresse Systemtemperatur = $nassystemtemp Grad"
            $errorcount++
        }
        else{
            Write-EventLog -LogName divertoEvents -Source divNAS -EntryType Warning -EventID 4002 -Message "$ipadresse - Systemtemperatur = unbekannt"
        }
    }
    else{
    }
}

################## Check SystemFan Status #####################

$nassystemfanstatus = 1
$nassystemfanoid = 0
while ($nassystemfanstatus -ne ''){
    $nassystemfanstatus = ''
    $nassystemfanstatus = $snmp.Get(".1.3.6.1.4.1.6574.1.4.1.$nassystemfanoid")
    $nassystemfanoid++

    if ($nassystemfanstatus -ne ''){
        if($nassystemfanstatus -eq 1){
                write-host "OK - SystemFan$nassystemfanoid Status = Normal"
        }
        else{
            if($hddstatus -eq 2){
                Write-EventLog -LogName divertoEvents -Source divNAS -EntryType Warning -EventID 4003 -Message "$ipadresse - SystemFan$nassystemfanoid Status = Failed(2):One of internal fan stopped."
                $errorcount++
            }
            else{
               Write-EventLog -LogName divertoEvents -Source divNAS -EntryType Warning -EventID 4004 -Message "$ipadresse - SystemFan$nassystemfanoid (SystemFan Status = $nassystemfanstatus)"
                $errorcount++
            }
            else{
            }
        }
    }
}

################## Check CPUFan Status #####################

$nascpufanstatus = 1
$nascpufanoid = 0
while ($nascpufanstatus -ne ''){
    $nascpufanstatus = ''
    $nascpufanstatus = $snmp.Get(".1.3.6.1.4.1.6574.1.4.2.$nascpufanoid")
    $nascpufanoid++

    if ($nascpufanstatus -ne ''){
        if($nascpufanstatus -eq 1){
                write-host "OK - CPUFan$nascpufanoid Status = Normal"
        }
        else{
            if($hddstatus -eq 2){
                Write-EventLog -LogName divertoEvents -Source divNAS -EntryType Warning -EventID 4005 -Message "$ipadresse - CPUFan$nascpufanoid Status = Failed(2):One of CPU fan stopped."
                $errorcount++
            }
            else{
               Write-EventLog -LogName divertoEvents -Source divNAS -EntryType Warning -EventID 4006 -Message "$ipadresse - CPUFan$nascpufanoid (SystemFan Status = $nascpufanstatus)"
                $errorcount++
            }
            else{
            }
        }
    }
}

##################Check Disk Temperatur#####################

$hddtemp = 1
$hddtempoid = 0
while ($hddtemp -ne ''){
    $hddtemp = ''
    $hddtemp = $snmp.Get(".1.3.6.1.4.1.6574.2.1.1.6.$hddtempoid")
    $hddmodel = $snmp.Get(".1.3.6.1.4.1.6574.2.1.1.3.$hddtempoid")
    $hddtempoid++

    if ($hddtemp -ne ''){
        if($hddtemp -ge 60){
            Write-EventLog -LogName divertoEvents -Source divNAS -EntryType Warning -EventID 4007 -Message "$ipadresse - Die HDD$hddtempoid hat $hddtemp Grad Temperatur - HDD Modell: $hddmodel"
            $errorcount++
        }
        else{
            write-host "OK - Die HDD$hddtempoid hat $hddtemp Grad Temperatur"
        }
    }
    else{
    }
}

##################Check Disk State (SMART Status)#####################

$hddstatus = 1
$hddstatusoid = 0
while ($hddstatus -ne ''){
    $hddstatus = ''
    $hddstatus = $snmp.Get(".1.3.6.1.4.1.6574.2.1.1.5.$hddstatusoid")
    $hddmodel = $snmp.Get(".1.3.6.1.4.1.6574.2.1.1.3.$hddtempoid")
    $hddstatusoid++

    if ($hddstatus -ne ''){
        if($hddstatus -eq 1){
                write-host "OK - HDD$hddstatusoid Status = Normal"
        }
        else{
            if($hddstatus -eq 2){
                Write-EventLog -LogName divertoEvents -Source divNAS -EntryType Warning -EventID 4008 -Message "$ipadresse - HDD$hddstatusoid Status = Initialized(2):The hard disk has system partition but no data. - HDD Modell: $hddmodel"
                $errorcount++
            }
            elseif($hddstatus -eq 3){
                Write-EventLog -LogName divertoEvents -Source divNAS -EntryType Warning -EventID 4008 -Message "$ipadresse - HDD$hddstatusoid Status = NotInitialized(3):The hard disk does not have system in system partition. - HDD Modell: $hddmodel"
                $errorcount++
            }
            elseif($hddstatus -eq 4){
                Write-EventLog -LogName divertoEvents -Source divNAS -EntryType Warning -EventID 4008 -Message "$ipadresse - HDD$hddstatusoid Status = SystemPartitionFailed(4):The system partitions on the hard disks are damaged. - HDD Modell: $hddmodel"
                $errorcount++
            }
            elseif($hddstatus -eq 5){
                Write-EventLog -LogName divertoEvents -Source divNAS -EntryType Warning -EventID 4008 -Message "$ipadresse - HDD$hddstatusoid Status = Crashed(5):The hard disk has damaged. - HDD Modell: $hddmodel"
                $errorcount++
            }
            else{
                Write-EventLog -LogName divertoEvents -Source divNAS -EntryType Warning -EventID 4008 -Message "$ipadresse - HDD$hddstatusoid (Synology disk status = $hddstatus) - HDD Modell: $hddmodel"
                $errorcount++
            }
            else{
            }
        }
    }
}

##################Check RAID State#####################

$raidstatus = 1
$raidstatusoid = 0
while ($raidstatus -ne ''){
    $raidstatus = ''
    $raidstatus = $snmp.Get(".1.3.6.1.4.1.6574.3.1.1.3.$raidstatusoid")
    $raidstatusoid++

    if ($raidstatus -ne ''){
        if($raidstatus -eq 1){
                write-host "OK - RAID Nr.$raidstatusoid Status = Normal"
        }
        else{
            if($raidstatus -eq 11){
                Write-EventLog -LogName divertoEvents -Source divNAS -EntryType Warning -EventID 4009 -Message "$ipadresse - RAID Nr.$raidstatusoid Status = Degrade(11):Degrade happens when a tolerable failure of disk(s) occurs."
                $errorcount++
            }
            elseif($raidstatus -eq 12){
                Write-EventLog -LogName divertoEvents -Source divNAS -EntryType Warning -EventID 4009 -Message "$ipadresse - RAID Nr.$raidstatusoid Status = Crashed(12):Raid has crashed and just uses for read-only operation."
                $errorcount++
            }
            else{
                Write-EventLog -LogName divertoEvents -Source divNAS -EntryType Warning -EventID 4009 -Message "$ipadresse - RAID Nr.$raidstatusoid (Synology Raid status = $raidstatus)"
                $errorcount++
            }
            else{
            }
        }
    }
}


	##################Check if upgrade is available#####################
<###
	$upgradestatus = ''
	$upgradestatus = $snmp.Get(".1.3.6.1.4.1.6574.1.5.4.0")

	if ($upgradestatus -ne ''){
		if($upgradestatus -eq 2){
				write-host "DSM Upgrade Status = You've already the latest DSM version running."
		}
		else{
			if($upgradestatus -eq 1){
				Write-EventLog -LogName divertoEvents -Source divNAS -EntryType Warning -EventID 4000 -Message "$ipadresse - DSM Upgrade Status = Available: There is a new version ready for download."
				#$errorcount++
			}
			elseif($upgradestatus -eq 3){
				Write-EventLog -LogName divertoEvents -Source divNAS -EntryType Warning -EventID 4000 -Message "$ipadresse - DSM Upgrade Status = Connecting: Checking for the latest DSM."
				#$errorcount++
			}
			elseif($upgradestatus -eq 4){
				Write-EventLog -LogName divertoEvents -Source divNAS -EntryType Warning -EventID 4000 -Message "$ipadresse - DSM Upgrade Status = Disconnected: Failed to connect to server."
				#$errorcount++
			}
			elseif($upgradestatus -eq 5){
				Write-EventLog -LogName divertoEvents -Source divNAS -EntryType Warning -EventID 4000 -Message "$ipadresse - DSM Upgrade Status = Other: If DSM is upgrading or downloading."
				#$errorcount++
			}
			else{
				Write-EventLog -LogName divertoEvents -Source divNAS -EntryType Warning -EventID 4000 -Message "$ipadresse - DSM Upgrade Status = $upgradestatus"
				#$errorcount++
			}
			else{
			}
		}
	}

###>

##################Show Volume OIDs if not set as Argument#####################

if($nasdisktotalGB -eq 0){
    
    Write-EventLog -LogName divertoEvents -Source divNAS -EntryType Warning -EventID 4000 -Message "$ipadresse - OIDs aller Volumes. OID des zu prüfenden Volume als Argument angeben."
    
    $nasvolumecheckoid = 1

    while ($nasvolumecheckoid -le 100){

        $nasdiskunit = $snmp.Get(".1.3.6.1.2.1.25.2.3.1.4.$nasvolumecheckoid")
        $nasdisktotalcheck = $snmp.Get(".1.3.6.1.2.1.25.2.3.1.5.$nasvolumecheckoid")
        $nasdiskDescrcheck = $snmp.Get(".1.3.6.1.2.1.25.2.3.1.3.$nasvolumecheckoid")
        $nasdisktotalcheckGB = [Math]::Round($(($nasdisktotalcheck * $nasdiskunit / 1024 / 1024 / 1024)) , 2)

        if($nasdisktotalcheck -ne ''){
            Write-EventLog -LogName divertoEvents -Source divNAS -EntryType Warning -EventID 4000 -Message "$ipadresse - Volume Name:"$nasdiskDescrcheck "- Total Speicherplatz:"$nasdisktotalcheckGB "GB" "- OID:"$nasvolumecheckoid
        }
        else{
        }
        $nasdisktotalcheck = ''
        $nasvolumecheckoid++
    }
}
else{
}