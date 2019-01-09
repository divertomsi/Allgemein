function Get-FolderSize
{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Path,
        [ValidateSet("KB", "MB", "GB")]
        $Units = "GB"
    )
    if ( (Test-Path $Path) -and (Get-Item $Path).PSIsContainer )
    {
        $Measure = Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum
        $Sum = $Measure.Sum / "1$Units"
        $sum = [math]::Round($sum, 2)
        [PSCustomObject]@{
            "Path"         = $Path
            "Size($Units)" = $Sum
        }
    }
}
    
$Einheit = "MB"
     
$Pfad = $env:Pfad
if ($env:Pfad -eq $null)
{
    $Pfad = "C:\divertoInstall", "C:\Minecraft", "C:\Users"
    write-host "Pfad environment Variable nicht erkannt. Testumgebungs Variable gesetzt. Wert: $Pfad"
}
    
foreach ($i in $pfad)
{
     
    $folders = @()
    $folders += Get-FolderSize $i $Einheit
    
    $subfolders = Get-ChildItem $i #-directory
    foreach ($ia in $subfolders.Name)
    {
        $folders += Get-FolderSize $i\$ia $Einheit
    }
    
    echo $folders | sort -Descending -Property "size($Einheit)"
    $folders = ""
    echo "------"
}