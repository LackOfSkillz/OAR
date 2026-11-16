# tools/family.ps1
# One-file Outrider installer for family (Gary, 2026-11-14: "my daughters want
# a copy ... easy, as one click as possible, all the db info needs to transfer").
# Builds dist\family\Install-Outrider.cmd: double-click it on the other PC and
# it finds WoW Forever and installs Outrider, its data addons (including the
# private QuestieDB packs, GPLv3: LICENSE-DATA.txt and gpl-3.0.md go into each)
# and Outrider_Data_Shared:
# Gary's world knowledge exported from his SavedVariables (NPCs met, places,
# nodes, rare sightings, prices; never characters, gold or logs).
# Also writes dist\family\Outrider-family.zip for unzipping by hand.
# Published by tools/publish.ps1 (data licensing: docs/DECISIONS.md, Q3).
#   powershell -ExecutionPolicy Bypass -File tools/family.ps1
param([switch]$SkipTests)
. "$PSScriptRoot\common.ps1"

$root = Get-RepoRoot
$cfg = Get-OarConfig
if (-not $SkipTests) {
  # the full suite, companion included and required (AI spec 12.4)
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'test.ps1') -RequirePython | Out-Host
  if ($LASTEXITCODE -ne 0) { Write-Host "Tests failed. Not packaging." -ForegroundColor Red; exit 1 }
}

$dist = Join-Path $root 'dist\family'
$staging = Join-Path $dist 'staging'
if (Test-Path $staging) { Remove-Item -Recurse -Force $staging }
New-Item -ItemType Directory -Force -Path $staging | Out-Null

# Outrider itself, stamped as a family build
$toc = Get-Content (Join-Path $root 'addon\Outrider\Outrider.toc')
$version = ([regex]::Match(($toc | Where-Object { $_ -match '^##\s*Version:' } | Select-Object -First 1), 'Version:\s*(.+)$')).Groups[1].Value.Trim()
$stamp = (Get-Date -Format 'yyyyMMdd-HHmm')
Copy-Item -Recurse -Path (Join-Path $root 'addon\Outrider') -Destination (Join-Path $staging 'Outrider')
Write-Utf8NoBom (Join-Path $staging 'Outrider\Core\Build.lua') "-- Core/Build.lua (stamped by tools/family.ps1)`nlocal _, ns = ...`nns.build = `"v$version-family-$stamp`"`n"

# data addons: the public ones in addon\, the private QuestieDB packs
$folders = @('Outrider')
Get-ChildItem -Path (Join-Path $root 'addon') -Directory -Filter 'Outrider_Data_*' | ForEach-Object {
  Copy-Item -Recurse -Path $_.FullName -Destination (Join-Path $staging $_.Name); $folders += $_.Name }
Get-ChildItem -Path (Join-Path $root 'private') -Directory -Filter 'Outrider_Data_*' | ForEach-Object {
  Copy-Item -Recurse -Path $_.FullName -Destination (Join-Path $staging $_.Name); $folders += $_.Name }

# Gary's shared knowledge, read from a copy of his SavedVariables (never the live file)
$sv = Join-Path (Get-SavedVariablesDir $cfg) 'Outrider.lua'
if (Test-Path $sv) {
  $copy = Join-Path $dist 'sv-copy.lua'
  Copy-Item -Force $sv $copy
  $shared = Join-Path $staging 'Outrider_Data_Shared'
  New-Item -ItemType Directory -Force -Path $shared | Out-Null
  $code = Invoke-OarLua @('tools/export_shared.lua', $copy, $shared, $stamp)
  Remove-Item -Force $copy
  if ($code -ne 0) { Write-Host "Shared knowledge export failed." -ForegroundColor Red; exit 1 }
  $folders += 'Outrider_Data_Shared'
} else {
  Write-Host "No SavedVariables found: building without shared knowledge." -ForegroundColor Yellow
}

# licence note for the QuestieDB-derived packs, plus the full GPLv3 text taken
# from the QuestieDB source we built them from (QuestieDB/LICENSE.md: the
# Questie team allows copying under the GPLv3 terms; the Questie name and logo
# are not ours to use)
$note = @"
Outrider build $version ($stamp)

The Outrider_Data_NPC, _Gear, _Mobs, _Nodes and _Dungeons folders contain data
converted from QuestieDB (https://github.com/Questie/Questie), shared under the
GNU General Public License version 3 (full text in gpl-3.0.md next to this file).
Upstream licensing notes: https://github.com/Questie/Questie/blob/master/LICENSE.md
Outrider is not made by or affiliated with the Questie team.
Outrider_Data_Words has its own licence file inside it.
"@
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$gpl = $null
$qzip = Get-ChildItem -Path (Join-Path $root 'private\questie-source') -Filter '*.zip' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($qzip) {
  $za = [System.IO.Compression.ZipFile]::OpenRead($qzip.FullName)
  try {
    $e = $za.GetEntry('QuestieDB/gpl-3.0.md')
    if ($e) { $r = New-Object System.IO.StreamReader($e.Open()); $gpl = $r.ReadToEnd(); $r.Dispose() }
  } finally { $za.Dispose() }
}
if (-not $gpl) { Write-Host "GPLv3 text not found in private\questie-source: not packaging." -ForegroundColor Red; exit 1 }
foreach ($f in $folders) {
  if ($f -match '^Outrider_Data_(NPC|Gear|Mobs|Nodes|Dungeons)$') {
    Write-Utf8NoBom (Join-Path $staging "$f\LICENSE-DATA.txt") $note
    Write-Utf8NoBom (Join-Path $staging "$f\gpl-3.0.md") $gpl
    # the generated TOC still carries the private-copy note: say what applies
    $tocPath = Join-Path $staging "$f\$f.toc"
    if (Test-Path $tocPath) {
      $lines = Get-Content $tocPath | ForEach-Object {
        if ($_ -match '^##\s*Notes:') { '## Notes: Data converted from QuestieDB, shared under GPLv3 (see LICENSE-DATA.txt).' } else { $_ } }
      Write-Utf8NoBom $tocPath (($lines -join "`n") + "`n")
    }
  }
}

# the updater (installed to %LOCALAPPDATA%\Outrider by the installer, never into AddOns)
$upd = Join-Path $staging '_updater'
New-Item -ItemType Directory -Force -Path $upd | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot 'family\updater.ps1') -Destination (Join-Path $upd 'Update-Outrider.ps1')
Write-Utf8NoBom (Join-Path $upd 'version.txt') $stamp
Write-Utf8NoBom (Join-Path $dist 'version.txt') $stamp

# zip (forward slashes)
$zip = Join-Path $dist 'Outrider-family.zip'
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

# one-file installer: a .cmd that runs the PowerShell part on itself, zip appended as base64
$ps = Get-Content -Raw (Join-Path $PSScriptRoot 'family\installer.ps1')
$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($zip), 'InsertLineBreaks')
$head = "@echo off`r`n" +
  "echo Installing Outrider for World of Warcraft Forever...`r`n" +
  "powershell -NoProfile -ExecutionPolicy Bypass -Command `"`$t=Get-Content -Raw -LiteralPath '%~f0'; `$m='#'+'PS#'; `$s=(`$t -split [regex]::Escape(`$m))[1]; `$sb=[scriptblock]::Create(`$s); & `$sb -Self '%~f0'`"`r`n" +
  "exit /b`r`n"
$cmd = $head + '#PS#' + "`r`n" + $ps + "`r`n" + '#PS#' + "`r`n" + '#ZIP#' + "`r`n" + $b64 + "`r`n"
$out = Join-Path $dist 'Install-Outrider.cmd'
[IO.File]::WriteAllText($out, $cmd, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("Built {0} and {1} ({2})" -f $out, $zip, ($folders -join ', ')) -ForegroundColor Green
