# tools/curseforge.ps1
# Builds the CurseForge release zip and, with -Upload, sends it to the Outrider
# project through CurseForge's author upload API (Gary, 2026-11-21: "we are
# going to submit this to CurseForge"). Steps for the one-time project setup on
# the website, and the listing text to paste: docs/CURSEFORGE.md.
#
# The zip (dist\curseforge\Outrider-<version>.zip) holds only addon folders,
# each with its own .toc, so the CurseForge app, WowUp and a manual unzip all
# put the same thing into Interface\AddOns:
#   Outrider, Outrider_Data_Words and the six QuestieDB-derived data addons
#   (GPLv3: LICENSE-DATA.txt and gpl-3.0.md inside each; docs/DECISIONS.md D20/D21).
# Never in it: programs or scripts (no installer, no updater), Gary's shared
# world knowledge (Outrider_Data_Shared), SavedVariables, logs.
#
# Upload needs, set once by Gary on his own PC (never typed into chat):
#   the API token in the CF_API_KEY environment variable
#     (made at https://authors.curseforge.com/#/settings/api-tokens)
#   the project ID in Outrider.toc as  ## X-Curse-Project-ID: <number>
#     (shown under "About This Project" on the project page), or -ProjectId
# Files are checked by CurseForge's moderators before players see them.
#
#   powershell -ExecutionPolicy Bypass -File tools/curseforge.ps1                    build only
#   powershell -ExecutionPolicy Bypass -File tools/curseforge.ps1 -Upload [-ReleaseType beta] [-Changelog "text"]
param(
  [switch]$Upload,
  [ValidateSet('release', 'beta', 'alpha')][string]$ReleaseType = 'release',
  [string]$Changelog = '',
  [string]$GameVersion = '',
  [int]$ProjectId = 0,
  [switch]$SkipTests
)
. "$PSScriptRoot\common.ps1"
$ErrorActionPreference = 'Stop'
$root = Get-RepoRoot
$api = 'https://wow.curseforge.com/api'

$tocPath = Join-Path $root 'addon\Outrider\Outrider.toc'
$toc = Get-Content $tocPath
function Get-TocField([string]$name) {
  $line = $toc | Where-Object { $_ -match ('^##\s*' + [regex]::Escape($name) + ':\s*(.+)$') } | Select-Object -First 1
  if ($line) { return ([regex]::Match($line, ':\s*(.+)$')).Groups[1].Value.Trim() }
  return ''
}
$version = Get-TocField 'Version'
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw "Version '$version' in Outrider.toc is not x.y.z" }

# The game version CurseForge lists for this interface number: 16001 -> 1.60.1
# (WoW Forever; ForeverPlus's Forever files show 1.60.1, checked 2026-11-21).
function ConvertTo-GameVersion([string]$interface) {
  $n = [int]($interface.Split(',')[0].Trim())
  return ('{0}.{1}.{2}' -f [math]::Floor($n / 10000), [math]::Floor(($n % 10000) / 100), ($n % 100))
}
if (-not $GameVersion) { $GameVersion = ConvertTo-GameVersion (Get-TocField 'Interface') }

if (-not $SkipTests) {
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'test.ps1') -RequirePython | Out-Host
  if ($LASTEXITCODE -ne 0) { Write-Host "Tests failed. Not packaging." -ForegroundColor Red; exit 1 }
}

# ------------------------------------------------------------------ build
$dist = Join-Path $root 'dist\curseforge'
$staging = Join-Path $dist 'staging'
if (Test-Path $staging) { Remove-Item -Recurse -Force $staging }
New-Item -ItemType Directory -Force -Path $staging | Out-Null

Copy-Item -Recurse -Path (Join-Path $root 'addon\Outrider') -Destination (Join-Path $staging 'Outrider')
Write-Utf8NoBom (Join-Path $staging 'Outrider\Core\Build.lua') "-- Core/Build.lua (stamped by tools/curseforge.ps1)`nlocal _, ns = ...`nns.build = `"v$version`"`n"
# Advisor\Advice.lua is written on Gary's PC by the companion: ship the empty one from the repo only
$folders = @('Outrider')
Get-ChildItem -Path (Join-Path $root 'addon') -Directory -Filter 'Outrider_Data_*' | ForEach-Object {
  Copy-Item -Recurse -Path $_.FullName -Destination (Join-Path $staging $_.Name); $folders += $_.Name }
$packs = 'Outrider_Data_NPC', 'Outrider_Data_Gear', 'Outrider_Data_Mobs', 'Outrider_Data_Nodes', 'Outrider_Data_Dungeons', 'Outrider_Data_Quests', 'Outrider_Data_Reagents', 'Outrider_Data_Paths'
foreach ($p in $packs) {
  $src = Join-Path $root "private\$p"
  if (-not (Test-Path (Join-Path $src "$p.toc"))) { Write-Host "Missing data addon $p (run its tools/import_*.py). Not packaging." -ForegroundColor Red; exit 1 }
  Copy-Item -Recurse -Path $src -Destination (Join-Path $staging $p); $folders += $p
}
if (-not (Add-OarDataLicenses $root $staging $folders "v$version")) { exit 1 }

# checks: every folder is an addon (its own .toc, same interface), nothing runnable
$interface = Get-TocField 'Interface'
foreach ($f in $folders) {
  $t = Join-Path $staging "$f\$f.toc"
  if (-not (Test-Path $t)) { throw "$f has no $f.toc" }
  $i = (Get-Content $t | Where-Object { $_ -match '^##\s*Interface:' } | Select-Object -First 1)
  if ($i -notmatch [regex]::Escape($interface)) { throw "$f.toc is not for interface $interface ($i)" }
}
$bad = Get-ChildItem -Path $staging -Recurse -File | Where-Object { $_.Extension -match '^\.(exe|dll|cmd|bat|ps1|vbs|js|py|sh|msi|scr)$' }
if ($bad) { throw ("Not allowed in an addon zip: " + (($bad | ForEach-Object { $_.Name }) -join ', ')) }

$zip = Join-Path $dist ("Outrider-$version.zip")
if (Test-Path $zip) { Remove-Item -Force $zip }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::Open($zip, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  Get-ChildItem -Path $staging -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($staging.Length + 1).Replace('\', '/')   # forward slashes: upload sites reject backslashes
    [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $_.FullName, $rel, [System.IO.Compression.CompressionLevel]::Optimal)
  }
} finally { $archive.Dispose() }
Remove-Item -Recurse -Force $staging
$size = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Host ("Built {0} ({1} MB): {2}" -f $zip, $size, ($folders -join ', ')) -ForegroundColor Green
Write-Host "Game version: $GameVersion (interface $interface)"
if (-not $Upload) { exit 0 }

# ------------------------------------------------------------------ upload
$token = $env:CF_API_KEY
# saved after this terminal started (setx / SetEnvironmentVariable 'User'): read the stored value
if (-not $token) { $token = [Environment]::GetEnvironmentVariable('CF_API_KEY', 'User') }
if (-not $token) { Write-Host "Set the CF_API_KEY environment variable to your CurseForge API token first (docs/CURSEFORGE.md)." -ForegroundColor Red; exit 1 }
if (-not $ProjectId) { $id = Get-TocField 'X-Curse-Project-ID'; if ($id -match '^\d+$') { $ProjectId = [int]$id } }
if (-not $ProjectId) { Write-Host "No project ID: add '## X-Curse-Project-ID: <number>' to Outrider.toc or pass -ProjectId." -ForegroundColor Red; exit 1 }

$headers = @{ 'X-Api-Token' = $token }
$versions = Invoke-RestMethod -Uri "$api/game/versions" -Headers $headers -Method Get
$match = @($versions | Where-Object { $_.name -eq $GameVersion })
if ($match.Count -eq 0) { Write-Host "CurseForge has no game version named $GameVersion. Pass -GameVersion with one it lists." -ForegroundColor Red; exit 1 }
Write-Host ("Game version ids for {0}: {1}" -f $GameVersion, (($match | ForEach-Object { "$($_.id) (type $($_.gameVersionTypeID))" }) -join ', '))

if (-not $Changelog) {
  # the newest section of CHANGELOG.md
  $lines = Get-Content (Join-Path $root 'CHANGELOG.md')
  $start = ($lines | Select-String -Pattern '^## ' | Select-Object -First 1).LineNumber
  $next = ($lines | Select-String -Pattern '^## ' | Select-Object -Skip 1 -First 1).LineNumber
  if ($start) { $Changelog = ($lines[($start - 1)..(($(if ($next) { $next } else { $lines.Count + 1 })) - 2)] -join "`n") }
  if (-not $Changelog) { $Changelog = "Outrider $version" }
}
$meta = [ordered]@{
  changelog = $Changelog; changelogType = 'markdown'; displayName = "Outrider $version"
  gameVersions = @($match | ForEach-Object { [int]$_.id }); releaseType = $ReleaseType
}
$metaFile = Join-Path $dist 'metadata.json'
Write-Utf8NoBom $metaFile ($meta | ConvertTo-Json -Depth 5)
# curl.exe (Windows 10+) for the multipart upload; the token goes in a header, never on screen
$out = & curl.exe -s -S -w "`n%{http_code}" -H "X-Api-Token: $token" -F "metadata=<$metaFile" -F "file=@$zip" "$api/projects/$ProjectId/upload-file"
Remove-Item -Force $metaFile
$code = ($out | Select-Object -Last 1)
$body = (($out | Select-Object -SkipLast 1) -join "`n")
if ($code -ne '200') { Write-Host "Upload failed (HTTP $code): $body" -ForegroundColor Red; exit 1 }
Write-Host "Uploaded Outrider $version as a $ReleaseType file: $body. CurseForge's moderators check it before players see it." -ForegroundColor Green
