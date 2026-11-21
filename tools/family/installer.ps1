# Outrider family installer (embedded in Install-Outrider.cmd by tools/family.ps1).
# Finds World of Warcraft Forever, then copies Outrider and its data addons into
# _forever_\Interface\AddOns. Touches nothing else: no settings, no saved data.
# The old Outrider folders are backed up first and put back if anything fails.
# The old Outrider folders are backed up first and put back if anything fails.
# -TestAddOns <folder> -TestBackup <folder>: install into a scratch folder (specs and
# tools only): no WoW lookup or check, no updater, no shortcut, no message boxes.
param([string]$Self, [string]$TestAddOns, [string]$TestBackup, [switch]$TestFail)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Say([string]$text, [string]$icon = 'Information') {
  if ($TestAddOns) { Write-Host "[$icon] $text"; return }
  [void][System.Windows.Forms.MessageBox]::Show($text, 'Outrider installer', 'OK', $icon)
}

# 1. Where is WoW Forever?
function Find-Forever {
  $roots = New-Object System.Collections.Generic.List[string]
  foreach ($key in @('HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft',
                     'HKLM:\SOFTWARE\Blizzard Entertainment\World of Warcraft')) {
    try {
      $p = (Get-ItemProperty -Path $key -ErrorAction Stop).InstallPath
      if ($p) { $roots.Add((Split-Path ($p.TrimEnd('\')) -Parent)); $roots.Add($p.TrimEnd('\')) }
    } catch {}
  }
  foreach ($d in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root })) {
    foreach ($rel in @('Program Files (x86)\World of Warcraft', 'Program Files\World of Warcraft', 'World of Warcraft',
                       'Games\World of Warcraft', 'Blizzard\World of Warcraft', 'Battle.net\World of Warcraft')) {
      $roots.Add((Join-Path $d.Root $rel))
    }
  }
  foreach ($r in $roots) {
    if ($r -and (Test-Path (Join-Path $r '_forever_'))) { return (Join-Path $r '_forever_') }
    if ($r -and ((Split-Path $r -Leaf) -eq '_forever_') -and (Test-Path $r)) { return $r }
  }
  return $null
}

$forever = if ($TestAddOns) { 'test' } else { Find-Forever }
if (-not $forever) {
  $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
  $dlg.Description = "Couldn't find World of Warcraft Forever. Pick your 'World of Warcraft' folder (the one that holds _forever_)."
  if ($dlg.ShowDialog() -ne 'OK') { Say 'Install cancelled.' 'Warning'; exit 1 }
  $pick = $dlg.SelectedPath
  if (Test-Path (Join-Path $pick '_forever_')) { $forever = Join-Path $pick '_forever_' }
  elseif ((Split-Path $pick -Leaf) -eq '_forever_') { $forever = $pick }
  else { Say "That folder has no _forever_ inside. Run WoW Forever once from Battle.net, then try again." 'Error'; exit 1 }
}
$addons = if ($TestAddOns) { $TestAddOns } else { Join-Path $forever 'Interface\AddOns' }

# 2. The game must be closed: it holds the addon files and would not load the
#    new ones. Wait until it is (Retry), or stop (Cancel). Nothing is touched yet.
while (-not $TestAddOns -and (Get-Process -Name 'Wow', 'WowClassic', 'WowT' -ErrorAction SilentlyContinue)) {
  $a = [System.Windows.Forms.MessageBox]::Show("World of Warcraft is running. Close the game completely, then click Retry.`n`nCancel stops the install; nothing has been changed.",
    'Outrider installer', 'RetryCancel', 'Warning')
  if ($a -ne 'Retry') { exit 1 }
}

# 3. Unpack the embedded zip and copy the addon folders.
$text = Get-Content -Raw -LiteralPath $Self
$marker = '#' + 'ZIP#'
$b64 = ($text -split [regex]::Escape($marker), 2)[1]
$tmp = Join-Path $env:TEMP ('outrider-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$zip = Join-Path $tmp 'outrider.zip'
[IO.File]::WriteAllBytes($zip, [Convert]::FromBase64String(($b64 -replace '\s', '')))
$out = Join-Path $tmp 'files'
[IO.Compression.ZipFile]::ExtractToDirectory($zip, $out)

# Transactional: copy the current Outrider folders to a backup first
# (%LOCALAPPDATA%\Outrider\backup\<time>, last 3 kept), then replace them. If
# anything fails, every folder is put back from the backup and the install stops.
$folders = @(Get-ChildItem -Path $out -Directory | Where-Object { $_.Name -notlike '_*' })
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = if ($TestBackup) { $TestBackup } else { Join-Path $env:LOCALAPPDATA 'Outrider\backup' }
$backup = Join-Path $backupRoot $stamp
$names = @()
$done = @()
try {
  New-Item -ItemType Directory -Force -Path $addons | Out-Null
  New-Item -ItemType Directory -Force -Path $backup | Out-Null
  foreach ($dir in $folders) {
    $dest = Join-Path $addons $dir.Name
    if (Test-Path $dest) { Copy-Item -Recurse -Force -Path $dest -Destination (Join-Path $backup $dir.Name) }
  }
  foreach ($dir in $folders) {
    $dest = Join-Path $addons $dir.Name
    $done += $dir.Name
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    Copy-Item -Recurse -Path $dir.FullName -Destination $dest
    $names += $dir.Name
    if ($TestFail -and $names.Count -eq 2) { throw 'test failure after two folders' }
  }
} catch {
  $why = $_.Exception.Message
  foreach ($n in $done) {
    $dest = Join-Path $addons $n
    try {
      if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
      $saved = Join-Path $backup $n
      if (Test-Path $saved) { Copy-Item -Recurse -Force -Path $saved -Destination $dest }
    } catch {}
  }
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
  if ($_.Exception -is [System.UnauthorizedAccessException]) {
    Say "Windows wouldn't let the installer write to the WoW folder. Your old Outrider was put back. Right-click Install-Outrider and choose 'Run as administrator'." 'Error'
  } else {
    Say ("The install failed and your old Outrider was put back.`n`n" + $why) 'Error'
  }
  exit 1
}
# keep the newest 3 backups
Get-ChildItem -Path $backupRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending |
  Select-Object -Skip 3 | ForEach-Object { Remove-Item -Recurse -Force $_.FullName -ErrorAction SilentlyContinue }

# 4. The updater: a copy in %LOCALAPPDATA%\Outrider and an "Update Outrider"
#    shortcut on the desktop. It asks GitHub for a newer build when double-clicked.
$updaterNote = ''
if (-not $TestAddOns) { try {
  $src = Join-Path $out '_updater'
  if (Test-Path $src) {
    $home2 = Join-Path $env:LOCALAPPDATA 'Outrider'
    New-Item -ItemType Directory -Force -Path $home2 | Out-Null
    Copy-Item -Force -Path (Join-Path $src '*') -Destination $home2
    $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Update Outrider.lnk'
    $sh = New-Object -ComObject WScript.Shell
    $sc = $sh.CreateShortcut($lnk)
    $sc.TargetPath = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $sc.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + (Join-Path $home2 'Update-Outrider.ps1') + '"'
    $sc.WorkingDirectory = $home2
    $sc.Description = 'Check for a newer Outrider and install it'
    $sc.Save()
    $updaterNote = "`n`nFor updates: double-click 'Update Outrider' on your desktop (WoW closed)."
  }
} catch { $updaterNote = '' } }
Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
# plain steps (Gary, 2026-11-21: "super simple, my daughters will try it")
Say ("Outrider is installed!`n`n" +
  "1. Start World of Warcraft Forever.`n" +
  "2. On the character screen, click AddOns (bottom left) and make sure Outrider is ticked. If you see 'Load out of date AddOns', tick that too.`n" +
  "3. Log in and type /ride to open Outrider." + $updaterNote +
  "`n`n(" + $names.Count + " folders installed in " + $addons + ")")
