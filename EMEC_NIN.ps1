[string]$HTML = (New-Object System.Net.WebClient).DownloadString("http://10.33.22.10/")

$SearchTerm = '*Directory: *'

If ($HTML -like "$SearchTerm" )
{
    Write-EventLog -LogName divertoEvents -Source divServer -EntryType Warning -EventID 9 -Message "NIN braucht automatische Wartung"
    exit 1
}
Else
{
    Write-EventLog -LogName divertoEvents -Source divServer -EntryType Information -EventID 9 -Message "NIN braucht keine automatische Wartung"
    exit 0
}

<#
@echo off
net stop NinWindowsService_id
rmdir /s /q "C:\Windows\Temp\nin-jetty-runtime"
net start NinWindowsService_id
#>



#
# Variablen:
# --------------------------------------------------------------------------------------------------------------------
$counterrormax = 2 #Anzahl Fehler bis E-Mail ausgelöst wird

# Webseite prüfen
[string]$HTML = (New-Object System.Net.WebClient).DownloadString("http://10.33.22.10/")
# Log Pfad
$logPath = "C:\divertoScripts\NINSkript\"
# Log Datei Name
$logName = "ninskriptlog.txt"
# Nach welchem Wert wird auf der Webseite bei Fehler geprüft
$SearchTerm = '*Directory: *'
# Datei mit welcher dien Anzahl von aktiven NIN Fehlern gespeichert wird bis das Mail ausgelöst wird
$countdateiName = "errorcount.txt"

# Error Count zurücksetzten wenn Zeit zwischen (24h Format)
$min = Get-Date '04:00'
$max = Get-Date '04:30'

# --------------------------------------------------------------------------------------------------------------------
# Variablen ende

# Datum und Zeit für Log setzten
$datetime = $(get-date).ToString("yyyyMMdd HHmmss")
# Log Pfad und Name setzten
$log = $logPath + $logName
# Count Datei Pfad und Name setzten
$countdatei = $logPath + $countdateiName
# Gespeicherter Count Wert einlesen
[decimal]$count = Get-content $countdatei

# Wenn Count zurücksetzten Zeit zwischen "Variable oben gesetzt" liegt = Count auf 0 setzten
$now = Get-Date
if ($min.TimeOfDay -le $now.TimeOfDay -and $max.TimeOfDay -ge $now.TimeOfDay)
{
    $count = 0
    $count > $countdatei
}

If ($HTML -like "$SearchTerm" -or $HTML -eq $null)
{
    Write-Output "$($datetime) NIN Directory Error" >> $log
    net stop NinWindowsService_id
    Start-Sleep -s 15
    Remove-Item "C:\Windows\Temp\nin-jetty-runtime" -recurse
    Start-Sleep -s 15
    net start NinWindowsService_id
    $count++
    $count > $countdatei
    
    If ($count -ge $counterrormax)
    {
        #Email Versand wenn Fehler aktiv
        $From = "admin@electrocontrol.ch"
        $SMTPServer = "smtp.office365.com"
        $SMTPPort = "587"
        $Username = "admin@electrocontrol.ch"
        $Password = "qexdlQYJq1"
        $To = @(("m.sigg@diverto.ch").split(";")) # Mehrere Email Adressen mit ; trennen. Bsp: "email1@mail.ch;email2@mail.ch"
        $subject = "NIN Directory Error"
        $body = "NIN Fehler aktiv!! und wurde heute total $count mal neu gestartet"
        # -----------------------------------------------------------
        # SMTP Server, Port und SSL setzten
        $SMTPClient = New-Object Net.Mail.SmtpClient($SMTPServer, $SMTPPort) 
        $SMTPClient.EnableSsl = $true 
        # Setzten der Anmeldedaten für SMTP Authentifizierung
        $SMTPClient.Credentials = New-Object System.Net.NetworkCredential($Username, $Password)
        foreach ($Email in $To)
        {
            #Nachricht wird erstellt
            $mail = New-Object System.Net.Mail.Mailmessage $From, $Email, $subject, $Body
            $mail.IsBodyHTML = $true
            #Nachricht wird gesendet
            $SMTPClient.send($mail)
        }
        # $count = 0
        # $count > $countdatei
    }
}
Else
{
    Write-Output "$($datetime) Kein NIN Fehler" >> $log
}




