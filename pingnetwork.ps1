$ip = "192.168.200."
$ipstart = 180
$ipende = 200

for ($i = $ipstart; $i -le $ipende; $i++)
{
    ping -n 1 $ip$i
}

