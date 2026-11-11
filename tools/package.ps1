# tools/package.ps1  (R-01)
# Builds a release zip: dist\Outrider-<version>.zip containing the Outrider folder
# (Core\Build.lua stamped "v<version>") plus the redistributable data addons kept in
# the repo (addon\Outrider_Data_*, e.g. Outrider_Data_Words with its LICENSE.txt).
# The private packs built from QuestieDB (private\Outrider_Data_NPC, _Gear) are never
# included: they live outside addon\ and are Gary's only (D10, D13).
# Zip entries use forward slashes (Windows PowerShell's Compress-Archive writes
# backslashes, which some upload sites reject). Runs the tests first.
#   powershell -ExecutionPolicy Bypass -File tools/package.ps1
param([switch]$SkipTests)
. "$PSScriptRoot\common.ps1"

$root = Get-RepoRoot
$addonDir = Join-Path $root 'addon'
$source = Join-Path $addonDir $script:AddonName
$toc = Get-Content (Join-Path $source 'Outrider.toc')
$versionLine = $toc | Where-Object { $_ -match '^##\s*Version:\s*(.+)$' } | Select-Object -First 1
if (-not $versionLine) { throw "No ## Version in Outrider.toc" }
$version = ([regex]::Match($versionLine, '^##\s*Version:\s*(.+)$')).Groups[1].Value.Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw "Version '$version' is not semantic (x.y.z)" }

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
$folders = @($script:AddonName)
Get-ChildItem -Path $addonDir -Directory -Filter 'Outrider_Data_*' | ForEach-Object {
  Copy-Item -Recurse -Path $_.FullName -Destination (Join-Path $staging $_.Name)
  $folders += $_.Name
}

$zip = Join-Path $dist ("Outrider-$version.zip")
if (Test-Path $zip) { Remove-Item -Force $zip }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::Open($zip, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  Get-ChildItem -Path $staging -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($staging.Length + 1).Replace('\', '/')
    [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $_.FullName, $rel, [System.IO.Compression.CompressionLevel]::Optimal)
  }
} finally { $archive.Dispose() }
Remove-Item -Recurse -Force $staging
Write-Host ("Built {0} ({1})" -f $zip, ($folders -join ', ')) -ForegroundColor Green
