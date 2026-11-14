# Outrider family installer (embedded in Install-Outrider.cmd by tools/family.ps1).
# Finds World of Warcraft Forever, then copies Outrider and its data addons into
# _forever_\Interface\AddOns. Touches nothing else: no settings, no saved data.
param([string]$Self)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Say([string]$text, [string]$icon = 'Information') {
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

$forever = Find-Forever
if (-not $forever) {
  $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
  $dlg.Description = "Couldn't find World of Warcraft Forever. Pick your 'World of Warcraft' folder (the one that holds _forever_)."
  if ($dlg.ShowDialog() -ne 'OK') { Say 'Install cancelled.' 'Warning'; exit 1 }
  $pick = $dlg.SelectedPath
  if (Test-Path (Join-Path $pick '_forever_')) { $forever = Join-Path $pick '_forever_' }
  elseif ((Split-Path $pick -Leaf) -eq '_forever_') { $forever = $pick }
  else { Say "That folder has no _forever_ inside. Run WoW Forever once from Battle.net, then try again." 'Error'; exit 1 }
}
$addons = Join-Path $forever 'Interface\AddOns'

# 2. The game should be closed so it loads the new files.
if (Get-Process -Name 'Wow', 'WowClassic', 'WowT' -ErrorAction SilentlyContinue) {
  Say "World of Warcraft is running. Close the game first, then click OK to install." 'Warning'
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

try {
  New-Item -ItemType Directory -Force -Path $addons | Out-Null
  $names = @()
  foreach ($dir in (Get-ChildItem -Path $out -Directory | Where-Object { $_.Name -notlike '_*' })) {
    $dest = Join-Path $addons $dir.Name
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    Copy-Item -Recurse -Path $dir.FullName -Destination $dest
    $names += $dir.Name
  }
} catch [System.UnauthorizedAccessException] {
  Say "Windows wouldn't let the installer write to the WoW folder. Right-click Install-Outrider and choose 'Run as administrator'." 'Error'
  exit 1
}

# 4. The updater: a copy in %LOCALAPPDATA%\Outrider and an "Update Outrider"
#    shortcut on the desktop. It asks GitHub for a newer build when double-clicked.
$updaterNote = ''
try {
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
} catch { $updaterNote = '' }
Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue

Say ("Outrider is installed in:`n$addons`n`nStart World of Warcraft Forever, log in, and type /ride to open it.`n`nInstalled: " + ($names -join ', ') + $updaterNote)
