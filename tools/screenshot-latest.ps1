# tools/screenshot-latest.ps1
# Lists the newest in-game screenshots (Gary presses Print Screen in game).
# Claude Code then opens the printed path with its Read tool to look at it.
#   powershell -ExecutionPolicy Bypass -File tools/screenshot-latest.ps1
#   ... -Count 3        newest three
#   ... -Minutes 10     only shots from the last 10 minutes
param([int]$Count = 1, [int]$Minutes = 0)
. "$PSScriptRoot\common.ps1"

$cfg = Get-OarConfig
$dir = $cfg.screenshotsDir
if (-not $dir -or -not (Test-Path $dir)) { Write-Host "No Screenshots folder yet ($dir). Gary presses Print Screen in game once." -ForegroundColor Yellow; exit 1 }
$shots = Get-ChildItem $dir -File | Where-Object { $_.Extension -match '^\.(jpg|jpeg|png|tga)$' } | Sort-Object LastWriteTime -Descending
if ($Minutes -gt 0) { $cut = (Get-Date).AddMinutes(-$Minutes); $shots = $shots | Where-Object { $_.LastWriteTime -ge $cut } }
$shots = @($shots | Select-Object -First $Count)
if ($shots.Count -eq 0) { Write-Host "No screenshots found." -ForegroundColor Yellow; exit 1 }
foreach ($s in $shots) { Write-Host ($s.FullName + "  (" + (Format-Age $s.LastWriteTime) + ")") }
