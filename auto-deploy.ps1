# auto-deploy.ps1 — τρέχει αυτόματα κάθε φορά που αλλάζει το HTML
$src  = "\\192.168.1.242\antlies\Αντλίες_CRM_v4.html"
$dest = "C:\Users\Server\Desktop\antlies-deploy\index.html"
$log  = "C:\Users\Server\Desktop\antlies-deploy\deploy.log"

# Σύγκριση — deploy μόνο αν άλλαξε το αρχείο
$srcTime  = (Get-Item $src).LastWriteTime
$destTime = if (Test-Path $dest) { (Get-Item $dest).LastWriteTime } else { [DateTime]::MinValue }

if ($srcTime -le $destTime) {
    Add-Content $log "[$(Get-Date -Format 'yyyy-MM-dd HH:mm')] Δεν χρειάζεται deploy (δεν άλλαξε)"
    exit 0
}

# Αντιγραφή νέου αρχείου
Copy-Item $src $dest -Force

# Git push
Set-Location "C:\Users\Server\Desktop\antlies-deploy"
git add index.html
git commit -m "Auto-deploy $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
git push

$msg = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm')] Deploy OK — $srcTime"
Add-Content $log $msg
Write-Host $msg