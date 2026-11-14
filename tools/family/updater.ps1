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
Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', "`"$tmp`"" -Wait
Remove-Item -Force $tmp -ErrorAction SilentlyContinue
