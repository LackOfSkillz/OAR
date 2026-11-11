# tools/package.ps1
# Builds a release zip: dist\OAR-<version>.zip containing the OAR folder,
# with Core\Build.lua stamped "v<version>". Runs the tests first.
#   powershell -ExecutionPolicy Bypass -File tools/package.ps1
param([switch]$SkipTests)
. "$PSScriptRoot\common.ps1"

$root = Get-RepoRoot
$source = Join-Path (Join-Path $root 'addon') $script:AddonName
$toc = Get-Content (Join-Path $source 'OAR.toc')
$versionLine = $toc | Where-Object { $_ -match '^##\s*Version:\s*(.+)$' } | Select-Object -First 1
if (-not $versionLine) { throw "No ## Version in OAR.toc" }
$version = ([regex]::Match($versionLine, '^##\s*Version:\s*(.+)$')).Groups[1].Value.Trim()

if (-not $SkipTests) {
  $code = Invoke-OarLua @('tests/run_tests.lua')
  if ($code -ne 0) { Write-Host "Tests failed. Not packaging." -ForegroundColor Red; exit 1 }
}

$dist = Join-Path $root 'dist'
$staging = Join-Path $dist 'staging'
if (Test-Path $staging) { Remove-Item -Recurse -Force $staging }
New-Item -ItemType Directory -Force -Path $staging | Out-Null
Copy-Item -Recurse -Path $source -Destination (Join-Path $staging $script:AddonName)
$buildLua = "-- Core/Build.lua (stamped by tools/package.ps1)`nlocal _, ns = ...`nns.build = `"v$version`"`n"
Write-Utf8NoBom (Join-Path (Join-Path (Join-Path $staging $script:AddonName) 'Core') 'Build.lua') $buildLua

$zip = Join-Path $dist ("OAR-$version.zip")
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path (Join-Path $staging $script:AddonName) -DestinationPath $zip
Remove-Item -Recurse -Force $staging
Write-Host "Built $zip" -ForegroundColor Green
