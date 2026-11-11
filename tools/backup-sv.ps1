# tools/backup-sv.ps1
# Copies OAR's SavedVariables (and BugGrabber's) to backups\<timestamp>\ in the
# repo. Run before risky tests and before any schema migration. Keeps the
# newest 30 backups. Never writes into the WoW folder.
#   powershell -ExecutionPolicy Bypass -File tools/backup-sv.ps1
#   ... -Restore 20261111-153000   (only while the game is CLOSED)
param([string]$Restore)
. "$PSScriptRoot\common.ps1"

$cfg = Get-OarConfig
$svDir = Get-SavedVariablesDir $cfg
if (-not $svDir -or -not (Test-Path $svDir)) { Write-Host "No SavedVariables folder yet." -ForegroundColor Yellow; exit 1 }
$backupRoot = Join-Path (Get-RepoRoot) 'backups'

if ($Restore) {
  if (Test-WowRunning) { Write-Host "Close the game first: WoW overwrites SavedVariables when it exits." -ForegroundColor Red; exit 1 }
  $from = Join-Path $backupRoot $Restore
  if (-not (Test-Path $from)) { Write-Host "No backup named $Restore" -ForegroundColor Red; exit 1 }
  Get-ChildItem $from -File | ForEach-Object { Copy-Item $_.FullName (Join-Path $svDir $_.Name) -Force; Write-Host "restored $($_.Name)" }
  exit 0
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$dest = Join-Path $backupRoot $stamp
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$copied = 0
foreach ($pattern in @('OAR*.lua', '!BugGrabber.lua', 'BugSack.lua')) {
  Get-ChildItem $svDir -Filter $pattern -File -ErrorAction SilentlyContinue | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $dest $_.Name)
    $copied++
  }
}
Write-Host "Backed up $copied file(s) to backups\$stamp"
$all = Get-ChildItem $backupRoot -Directory | Sort-Object Name -Descending
if ($all.Count -gt 30) { $all | Select-Object -Skip 30 | ForEach-Object { Remove-Item -Recurse -Force $_.FullName } }
