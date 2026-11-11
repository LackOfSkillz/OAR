# tools/read-logs.ps1
# Prints what Outrider saved during the last session. SavedVariables are written
# only on /reload, logout or exit, so ask Gary to /reload first.
#   powershell -ExecutionPolicy Bypass -File tools/read-logs.ps1
#   ... -Section log|errors|probe|chars|snapshots|all
#   ... -Mark "P2-04"        only log lines after the last /ride mark containing that text
#   ... -Last 120            more log lines
#   ... -Bugs                also show BugGrabber errors that mention Outrider
param(
  [ValidateSet('summary', 'log', 'errors', 'probe', 'chars', 'snapshots', 'all')]
  [string]$Section = 'summary',
  [string]$Mark,
  [int]$Last = 60,
  [switch]$AllSessions,
  [switch]$Bugs
)
. "$PSScriptRoot\common.ps1"

$cfg = Get-OarConfig
$svDir = Get-SavedVariablesDir $cfg
if (-not $svDir -or -not (Test-Path $svDir)) {
  Write-Host "No SavedVariables folder yet. Gary needs to log in once with Outrider enabled, then /reload." -ForegroundColor Yellow
  exit 1
}
$file = Join-Path $svDir 'Outrider.lua'
if (-not (Test-Path $file)) {
  Write-Host "No Outrider.lua in $svDir yet. Is Outrider enabled? Ask Gary to /reload." -ForegroundColor Yellow
  Get-ChildItem $svDir -Filter '*.lua' | Sort-Object LastWriteTime -Descending | Select-Object -First 10 |
    ForEach-Object { Write-Host ("  " + $_.Name + "  " + (Format-Age $_.LastWriteTime)) }
  exit 1
}

$info = Get-Item $file
Write-Host ("Outrider.lua written " + (Format-Age $info.LastWriteTime) + "  ($file)")
$stateFile = Join-Path $PSScriptRoot '.last-deploy.json'
if (Test-Path $stateFile) {
  $deployState = Get-Content -Raw $stateFile | ConvertFrom-Json
  if ([datetime]$deployState.at -gt $info.LastWriteTime) {
    Write-Host "Warning: this file is OLDER than the last deploy ($($deployState.build)). Gary has not reloaded since." -ForegroundColor Yellow
  }
}

$luaArgs = @('tools/sv_dump.lua', $file, $Section, '--last', "$Last")
if ($Mark) { $luaArgs += @('--mark', $Mark) }
if ($AllSessions) { $luaArgs += '--all-sessions' }
$code = Invoke-OarLua $luaArgs

if ($Bugs) {
  $bg = Join-Path $svDir '!BugGrabber.lua'
  if (Test-Path $bg) {
    Write-Host "== BugGrabber errors mentioning Outrider"
    Invoke-OarLua @('tools/sv_dump.lua', $bg, 'bugs') | Out-Null
  } else {
    Write-Host "(BugGrabber not installed or has not saved yet)"
  }
}
exit $code
