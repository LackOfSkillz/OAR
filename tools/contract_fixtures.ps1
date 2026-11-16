# tools/contract_fixtures.ps1
# Refreshes the cross-language contract fixtures (Outrider Intelligence, spec 12.4):
#   1. the Lua addon (fake client, made-up character) writes a /ride ask snapshot code
#   2. the companion answers it without a model (deterministic) -> advice code
# tests/spec/contract_spec.lua pastes that advice back into the addon, and
# companion/tests/test_contract_golden.py checks the Python side still makes it.
# Review the diff before committing new fixtures.
. "$PSScriptRoot\common.ps1"
$root = Get-RepoRoot
$dir = Join-Path $root 'tests\fixtures\contract'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$snap = Join-Path $dir 'snapshot_v2.txt'
$code = Invoke-OarLua @('tools/contract_fixtures.lua', $snap)
if ($code -ne 0) { Write-Host "Lua snapshot failed." -ForegroundColor Red; exit 1 }
$py = (Get-Command py -ErrorAction SilentlyContinue) ; if (-not $py) { $py = Get-Command python }
Push-Location (Join-Path $root 'companion')
try {
  & $py.Source -m outrider_companion.intelligence.ask "I have 30 minutes" --snapshot $snap --out (Join-Path $dir 'advice_v2.txt') --no-model
  if ($LASTEXITCODE -ne 0) { Write-Host "Companion answer failed." -ForegroundColor Red; exit 1 }
} finally { Pop-Location }
Write-Host "Fixtures refreshed in $dir" -ForegroundColor Green
