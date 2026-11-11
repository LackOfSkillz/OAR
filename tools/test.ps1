# tools/test.ps1
# Runs the headless test suite (syntax check + specs) with whatever Lua 5.1 is available.
#   powershell -ExecutionPolicy Bypass -File tools/test.ps1            all specs
#   powershell -ExecutionPolicy Bypass -File tools/test.ps1 profiles   specs whose name contains "profiles"
param([string]$Filter)
. "$PSScriptRoot\common.ps1"
$luaArgs = @('tests/run_tests.lua')
if ($Filter) { $luaArgs += $Filter }
$code = Invoke-OarLua $luaArgs
exit $code
