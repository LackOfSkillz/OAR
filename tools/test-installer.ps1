# tools/test-installer.ps1
# Checks the family installer's transactional copy in a scratch folder (never
# the real WoW folder): a normal install replaces the old folders and keeps a
# backup; a failure halfway puts every old folder back.
# Needs dist\family\Install-Outrider.cmd (tools/family.ps1).
#   powershell -ExecutionPolicy Bypass -File tools/test-installer.ps1
. "$PSScriptRoot\common.ps1"
$root = Get-RepoRoot
$cmd = Join-Path $root 'dist\family\Install-Outrider.cmd'
if (-not (Test-Path $cmd)) { Write-Host "Build dist\family first (tools/family.ps1)." -ForegroundColor Red; exit 1 }
$installer = Join-Path $PSScriptRoot 'family\installer.ps1'
$scratch = Join-Path $env:TEMP ('outrider-installer-test-' + [guid]::NewGuid().ToString('N'))
$addons = Join-Path $scratch 'AddOns'
$backup = Join-Path $scratch 'backup'
$fail = 0
function Check([bool]$ok, [string]$what) {
  if ($ok) { Write-Host "  ok   $what" } else { Write-Host "  FAIL $what" -ForegroundColor Red; $script:fail++ }
}
function OldInstall {
  if (Test-Path $addons) { Remove-Item -Recurse -Force $addons }
  foreach ($n in @('Outrider', 'Outrider_Data_NPC')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $addons $n) | Out-Null
    Set-Content -Path (Join-Path $addons "$n\old.txt") -Value 'old build'
  }
  New-Item -ItemType Directory -Force -Path (Join-Path $addons 'SomeOtherAddon') | Out-Null
}
try {
  OldInstall
  & powershell -NoProfile -ExecutionPolicy Bypass -File $installer -Self $cmd -TestAddOns $addons -TestBackup $backup | Out-Null
  Check (Test-Path (Join-Path $addons 'Outrider\Outrider.toc')) 'new Outrider installed'
  Check (-not (Test-Path (Join-Path $addons 'Outrider\old.txt'))) 'old Outrider files replaced'
  Check (Test-Path (Join-Path $addons 'SomeOtherAddon')) 'other addons left alone'
  $b = Get-ChildItem -Path $backup -Directory | Select-Object -First 1
  Check ($b -and (Test-Path (Join-Path $b.FullName 'Outrider\old.txt'))) 'old Outrider kept as a backup'

  OldInstall
  Remove-Item -Recurse -Force $backup
  & powershell -NoProfile -ExecutionPolicy Bypass -File $installer -Self $cmd -TestAddOns $addons -TestBackup $backup -TestFail | Out-Null
  Check ($LASTEXITCODE -eq 1) 'failed install exits with an error'
  Check (Test-Path (Join-Path $addons 'Outrider\old.txt')) 'failure: old Outrider put back'
  Check (Test-Path (Join-Path $addons 'Outrider_Data_NPC\old.txt')) 'failure: old data addon put back'
  Check (-not (Test-Path (Join-Path $addons 'Outrider\Outrider.toc'))) 'failure: no half-new Outrider left'
} finally {
  Remove-Item -Recurse -Force $scratch -ErrorAction SilentlyContinue
}
if ($fail -gt 0) { Write-Host "$fail installer checks failed" -ForegroundColor Red; exit 1 }
Write-Host "installer checks passed" -ForegroundColor Green
