# tools/test.ps1
# Runs the headless test suite (syntax check + specs) with whatever Lua 5.1 is available.
#   powershell -ExecutionPolicy Bypass -File tools/test.ps1            all specs
#   powershell -ExecutionPolicy Bypass -File tools/test.ps1 profiles   specs whose name contains "profiles"
param([string]$Filter)
. "$PSScriptRoot\common.ps1"
$luaArgs = @('tests/run_tests.lua')
if ($Filter) { $luaArgs += $Filter }
$code = Invoke-OarLua $luaArgs
# Companion app (P9-03): Python unit tests, standard library only.
if ($code -eq 0 -and -not $Filter) {
  $py = Get-Command py -ErrorAction SilentlyContinue
  if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
  if ($py) {
    # every companion test file (test_companion.py, test_intelligence.py, ...)
    $testDir = Join-Path (Join-Path $script:RepoRoot 'companion') 'tests'
    $pyFailed = $false
    foreach ($testFile in (Get-ChildItem -Path $testDir -Filter 'test_*.py' | Sort-Object Name)) {
      # unittest reports on stderr; run through cmd so Windows PowerShell does not turn that into errors
      $out = cmd /c "`"$($py.Source)`" -I `"$($testFile.FullName)`" 2>&1"
      if ($LASTEXITCODE -ne 0) { $pyFailed = $true }
      Write-Host ("{0}: " -f $testFile.Name) -NoNewline
      ($out | Select-Object -Last 3) | Out-Host
    }
    if ($pyFailed) { Write-Host "Companion tests failed." -ForegroundColor Red; $code = 1 }
    else { Write-Host "companion tests passed" }
  } else { Write-Host "No Python found: companion tests skipped." -ForegroundColor Yellow }
}
exit $code
