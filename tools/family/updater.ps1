# Update Outrider (installed by Install-Outrider.cmd into %LOCALAPPDATA%\Outrider,
# started from the "Update Outrider" desktop shortcut).
# Asks GitHub for the newest release of LackOfSkillz/outrider-releases; when it
# is newer than the installed one, downloads Install-Outrider.cmd and runs it.
# Sends nothing about the player: a plain request with a generic User-Agent.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
function Say([string]$text, [string]$icon = 'Information', [string]$buttons = 'OK') {
  return [System.Windows.Forms.MessageBox]::Show($text, 'Update Outrider', $buttons, $icon)
}

$repo = 'LackOfSkillz/outrider-releases'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$verFile = Join-Path $dir 'version.txt'
$current = if (Test-Path $verFile) { (Get-Content -Raw $verFile).Trim() } else { '0' }

try {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers @{ 'User-Agent' = 'Outrider-Updater' }
} catch {
  [void](Say "Couldn't reach GitHub to check for updates. Check the internet connection and try again." 'Warning')
  exit 1
}
$latest = ($rel.tag_name -replace '^build-', '').Trim()
if ($latest -le $current) {
  [void](Say "Outrider is up to date (build $current).")
  exit 0
}
$asset = $rel.assets | Where-Object { $_.name -eq 'Install-Outrider.cmd' } | Select-Object -First 1
if (-not $asset) { [void](Say "The newest release has no installer attached yet. Try again later." 'Warning'); exit 1 }

$answer = Say ("A newer Outrider is ready (build $latest; you have $current).`n`n" + ($rel.body -split "`n" | Select-Object -First 8 | Out-String) + "`nClose World of Warcraft, then click Yes to install it.") 'Question' 'YesNo'
if ($answer -ne 'Yes') { exit 0 }

$tmp = Join-Path $env:TEMP ('Install-Outrider-' + $latest + '.cmd')
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmp -UseBasicParsing -Headers @{ 'User-Agent' = 'Outrider-Updater' }

# Only run an installer whose SHA-256 matches both the release's .sha256 file
# and the SHA256 line in its notes. Anything missing or different: stop.
function Refuse([string]$why) {
  Remove-Item -Force $tmp -ErrorAction SilentlyContinue
  [void](Say ("The download couldn't be checked, so it was not installed.`n`n$why`n`nTry again later, or ask Gary.") 'Error')
  exit 1
}
$shaAsset = $rel.assets | Where-Object { $_.name -eq 'Install-Outrider.cmd.sha256' } | Select-Object -First 1
if (-not $shaAsset) { Refuse 'This release has no checksum file.' }
try {
  $shaText = (Invoke-WebRequest -Uri $shaAsset.browser_download_url -UseBasicParsing -Headers @{ 'User-Agent' = 'Outrider-Updater' }).Content
  if ($shaText -is [byte[]]) { $shaText = [Text.Encoding]::UTF8.GetString($shaText) }
} catch { Refuse 'The checksum file could not be downloaded.' }
$expected = ([regex]::Match([string]$shaText, '[0-9a-fA-F]{64}')).Value.ToLower()
$inNotes = ([regex]::Match([string]$rel.body, 'SHA256[^:]*:\s*([0-9a-fA-F]{64})')).Groups[1].Value.ToLower()
$actual = (Get-FileHash -Algorithm SHA256 -Path $tmp).Hash.ToLower()
if (-not $expected) { Refuse 'The checksum file is empty or unreadable.' }
if ($inNotes -and $inNotes -ne $expected) { Refuse 'The checksum file and the release notes disagree.' }
if ($actual -ne $expected) { Refuse 'The downloaded installer does not match its checksum.' }

Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', "`"$tmp`"" -Wait
Remove-Item -Force $tmp -ErrorAction SilentlyContinue
