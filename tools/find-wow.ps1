# tools/find-wow.ps1
# Finds the WoW install and the WoW Forever client folder, then writes
# tools/local.json (git-ignored) for the other scripts.
#   powershell -ExecutionPolicy Bypass -File tools/find-wow.ps1
#   powershell -ExecutionPolicy Bypass -File tools/find-wow.ps1 -WowRoot "D:\Games\World of Warcraft" -Flavor _forever_
param(
  [string]$WowRoot,
  [string]$Flavor
)
. "$PSScriptRoot\common.ps1"

function Test-WowRoot([string]$Path) {
  if (-not $Path -or -not (Test-Path $Path)) { return $false }
  $flavors = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^_.+_$' }
  return [bool]$flavors
}

$candidates = New-Object System.Collections.Generic.List[string]
if ($WowRoot) { $candidates.Add($WowRoot) }

# Battle.net records the install path (it points at a flavor folder; take its parent).
foreach ($key in @('HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft',
                   'HKLM:\SOFTWARE\Blizzard Entertainment\World of Warcraft')) {
  try {
    $p = (Get-ItemProperty -Path $key -ErrorAction Stop).InstallPath
    if ($p) {
      $p = $p.TrimEnd('\', '/')
      if ((Split-Path -Leaf $p) -match '^_.+_$') { $p = Split-Path -Parent $p }
      $candidates.Add($p)
    }
  } catch { }
}

$drives = @()
try { $drives = Get-PSDrive -PSProvider FileSystem -ErrorAction Stop | ForEach-Object { $_.Root } } catch { }
foreach ($d in $drives) {
  foreach ($sub in @('Program Files (x86)\World of Warcraft', 'Program Files\World of Warcraft',
                     'World of Warcraft', 'Games\World of Warcraft', 'Blizzard\World of Warcraft')) {
    $candidates.Add((Join-Path $d $sub))
  }
}

$root = $null
foreach ($c in $candidates) { if (Test-WowRoot $c) { $root = (Resolve-Path $c).Path; break } }
if (-not $root) {
  Write-Host "Could not find World of Warcraft. Re-run with -WowRoot 'X:\path\to\World of Warcraft'" -ForegroundColor Red
  exit 1
}

$flavors = Get-ChildItem -Path $root -Directory | Where-Object { $_.Name -match '^_.+_$' } | ForEach-Object { $_.Name }
Write-Host "WoW install: $root"
Write-Host ("Client folders found: " + ($flavors -join ', '))

if (-not $Flavor) {
  foreach ($pref in @('_forever_', '_classic_beta_')) { if ($flavors -contains $pref) { $Flavor = $pref; break } }
}
if (-not $Flavor) {
  Write-Host "No _forever_ folder found. Re-run with -Flavor <one of the folders above>." -ForegroundColor Yellow
  exit 1
}
if ($flavors -notcontains $Flavor) { Write-Host "Folder $Flavor not found under $root" -ForegroundColor Red; exit 1 }

$flavorDir = Join-Path $root $Flavor
$addonsDir = Join-Path (Join-Path $flavorDir 'Interface') 'AddOns'
if (-not (Test-Path $addonsDir)) {
  New-Item -ItemType Directory -Path $addonsDir -Force | Out-Null
  Write-Host "Created $addonsDir"
}

$cfg = [pscustomobject]@{
  wowRoot        = $root
  flavor         = $Flavor
  addonsDir      = $addonsDir
  screenshotsDir = (Join-Path $flavorDir 'Screenshots')
  logsDir        = (Join-Path $flavorDir 'Logs')
  wtfAccountDir  = $null
}
Save-OarConfig $cfg
$sv = Get-SavedVariablesDir $cfg   # fills wtfAccountDir if the account folder exists

Write-Host "AddOns folder: $addonsDir"
if ($sv) { Write-Host "SavedVariables: $sv" } else { Write-Host "SavedVariables: not created yet (appears after the first login)" -ForegroundColor Yellow }
$accounts = Join-Path (Join-Path $flavorDir 'WTF') 'Account'
if (Test-Path $accounts) {
  $names = Get-ChildItem -Path $accounts -Directory | Where-Object { $_.Name -ne 'SavedVariables' } | ForEach-Object { $_.Name }
  if (@($names).Count -gt 1) { Write-Host ("Several account folders: " + ($names -join ', ') + " (using the newest; edit tools/local.json to change)") -ForegroundColor Yellow }
}
Write-Host "Saved tools/local.json"
