$volumenumber = 1

$minfreeGBvol1 = 1300

$a1 = 100

write-host ("$" + "a" + "1")



if (1095.68 -ge $(minfreeGBvol + $volumenumber))
{
    write-host "funktioniert"
}

write-host @("minfreeGBvol" + $volumenumber)



$a = 100, 200, 300

write-host $a[0]