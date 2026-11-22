# tools/export_trails.ps1
# Copies Gary's SavedVariables (read only, never the live file) and writes his
# characters' walked paths into addon/Outrider_Data_Trails (tools/export_trails.lua).
# Run before a release; the next deploy and every package pick it up.
#   powershell -ExecutionPolicy Bypass -File tools/export_trails.ps1
. "$PSScriptRoot\common.ps1"
$root = Get-RepoRoot
$cfg = Get-OarConfig
$sv = Join-Path (Get-SavedVariablesDir $cfg) 'Outrider.lua'
if (-not (Test-Path $sv)) { Write-Host "No SavedVariables found at $sv" -ForegroundColor Red; exit 1 }
$copy = Join-Path $env:TEMP ('outrider-sv-' + [guid]::NewGuid().ToString('N') + '.lua')
Copy-Item -Path $sv -Destination $copy
$out = Join-Path $root 'addon\Outrider_Data_Trails'
New-Item -ItemType Directory -Force -Path $out | Out-Null
try {
  $code = Invoke-OarLua @('tools/export_trails.lua', $copy, $out, (Get-Date -Format 'yyyy-MM-dd'))
} finally { Remove-Item -Force $copy }
if ($code -ne 0) { Write-Host "Export failed." -ForegroundColor Red; exit 1 }
