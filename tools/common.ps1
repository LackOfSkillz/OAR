# tools/common.ps1
# Shared helpers, dot-sourced by the other scripts:  . "$PSScriptRoot\common.ps1"
# Works in Windows PowerShell 5.1 and PowerShell 7 (no ternaries, no ??).

$ErrorActionPreference = 'Stop'
$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:ConfigPath = Join-Path $PSScriptRoot 'local.json'
$script:AddonName = 'Outrider'

function Get-RepoRoot { return $script:RepoRoot }

function Write-Utf8NoBom([string]$Path, [string]$Text) {
  # WoW reads Lua files fine without a BOM; PowerShell 5.1's -Encoding UTF8 adds one.
  $enc = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($Path, $Text, $enc)
}

function Get-OarConfig {
  if (-not (Test-Path $script:ConfigPath)) {
    throw "No tools/local.json yet. Run: powershell -ExecutionPolicy Bypass -File tools/find-wow.ps1"
  }
  $cfg = Get-Content -Raw -Path $script:ConfigPath | ConvertFrom-Json
  foreach ($field in @('wowRoot', 'flavor', 'addonsDir')) {
    if (-not $cfg.$field) { throw "tools/local.json is missing '$field'. Re-run tools/find-wow.ps1" }
  }
  return $cfg
}

function Save-OarConfig($cfg) {
  $json = $cfg | ConvertTo-Json -Depth 5
  Write-Utf8NoBom $script:ConfigPath $json
}

# Windows PowerShell 5.1 turns a native command's stderr into a terminating
# error when ErrorActionPreference is Stop. Run native probes with Continue.
function Invoke-NativeQuiet([scriptblock]$Block) {
  $old = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { & $Block } finally { $ErrorActionPreference = $old }
}

# Finds a way to run Lua 5.1: a real interpreter, or python + lupa (tools/lua.py).
function Get-LuaCommand {
  foreach ($name in @('lua5.1', 'luajit', 'lua')) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) {
      if ($name -eq 'lua') {
        $src = $cmd.Source
        $ver = Invoke-NativeQuiet { & $src -v 2>&1 | Out-String }
        if ($ver -notmatch 'Lua 5\.1') { continue }   # 5.2+ lacks setfenv; tests need 5.1
      }
      return @($cmd.Source)
    }
  }
  foreach ($py in @('python', 'python3', 'py')) {
    $cmd = Get-Command $py -ErrorAction SilentlyContinue
    if ($cmd) {
      $src = $cmd.Source
      $okLupa = Invoke-NativeQuiet { & $src -c "import lupa" 2>$null; $LASTEXITCODE -eq 0 }
      if ($okLupa) { return @($src, (Join-Path $PSScriptRoot 'lua.py')) }
    }
  }
  return $null
}

function Invoke-OarLua([string[]]$LuaArgs) {
  $lua = Get-LuaCommand
  if (-not $lua) {
    Write-Host "No Lua 5.1 found. Install one of:" -ForegroundColor Yellow
    Write-Host "  python -m pip install lupa      (then tests run through tools/lua.py)"
    Write-Host "  winget install DEVCOM.LuaJIT     (or any Lua 5.1 on PATH)"
    return 3
  }
  Push-Location $script:RepoRoot
  try {
    $code = Invoke-NativeQuiet {
      if ($lua.Count -gt 1) { & $lua[0] $lua[1] @LuaArgs | Out-Host } else { & $lua[0] @LuaArgs | Out-Host }
      $LASTEXITCODE
    }
    return $code
  } finally { Pop-Location }
}

function Get-SavedVariablesDir($cfg) {
  if ($cfg.wtfAccountDir -and (Test-Path $cfg.wtfAccountDir)) {
    return (Join-Path $cfg.wtfAccountDir 'SavedVariables')
  }
  # Account folder appears after the first login; find it now if it exists.
  $accountRoot = Join-Path (Join-Path (Join-Path $cfg.wowRoot $cfg.flavor) 'WTF') 'Account'
  if (Test-Path $accountRoot) {
    $acct = Get-ChildItem -Path $accountRoot -Directory | Where-Object { $_.Name -ne 'SavedVariables' } |
      Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($acct) {
      $cfg | Add-Member -NotePropertyName wtfAccountDir -NotePropertyValue $acct.FullName -Force
      Save-OarConfig $cfg
      return (Join-Path $acct.FullName 'SavedVariables')
    }
  }
  return $null
}

function Test-WowRunning {
  $p = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^Wow' }
  return [bool]$p
}

function Get-GitShort {
  $git = Get-Command git -ErrorAction SilentlyContinue
  if (-not $git) { return 'nogit' }
  Push-Location $script:RepoRoot
  try {
    $sha = Invoke-NativeQuiet { & git rev-parse --short HEAD 2>$null }
    if (-not $sha) { return 'nogit' }
    $dirty = Invoke-NativeQuiet { & git status --porcelain 2>$null }
    if ($dirty) { $sha = "$sha+" }
    return "$sha".Trim()
  } finally { Pop-Location }
}

function Format-Age([datetime]$When) {
  $span = (Get-Date) - $When
  if ($span.TotalSeconds -lt 90) { return ('{0:N0} seconds ago' -f $span.TotalSeconds) }
  if ($span.TotalMinutes -lt 90) { return ('{0:N0} minutes ago' -f $span.TotalMinutes) }
  return ('{0:N1} hours ago' -f $span.TotalHours)
}

# Licence files for the QuestieDB-derived data addons in a staged build
# (shared by tools/family.ps1 and tools/curseforge.ps1): LICENSE-DATA.txt and
# the full GPLv3 text (taken from the QuestieDB source we built them from) go
# into each, and the generated TOC's old "private copy" note is replaced.
# Returns $false when the GPLv3 text can't be found.
function Add-OarDataLicenses([string]$Root, [string]$Staging, [string[]]$Folders, [string]$Label) {
  # licence note for the QuestieDB-derived packs, plus the full GPLv3 text taken
  # from the QuestieDB source we built them from (QuestieDB/LICENSE.md: the
  # Questie team allows copying under the GPLv3 terms; the Questie name and logo
  # are not ours to use)
  $note = @"
Outrider build $Label

The Outrider_Data_NPC, _Gear, _Mobs, _Nodes, _Dungeons, _Quests, _Reagents, _Paths, _Travel and _Crafting folders contain data
converted from QuestieDB (https://github.com/Questie/Questie), shared under the
GNU General Public License version 3 (full text in gpl-3.0.md next to this file).
Upstream licensing notes: https://github.com/Questie/Questie/blob/master/LICENSE.md
Outrider is not made by or affiliated with the Questie team.

Since 0.4.5 the Gear, NPC, Travel and Crafting folders also use:
- ForeverDB (https://github.com/foreverfraddons/forever-db), GNU GPL v3: a merge of
  the WoW Forever client tables, AllTheThings, QuestieDB, VMaNGOS (GPL v2 or later),
  cMaNGOS classic-db (GPL v3), pfQuest (MIT, (c) 2017-2021 Eric Mauser), and
  Drop Tables (https://github.com/valcheffnet/DropTables, data CC BY-SA 4.0,
  "Drop Tables contributors"), which is where the drop chances come from.
- Shortest Path Forever (https://github.com/cjber/shortest-path-forever), GPL v3 or
  later, via ForeverDB: flight paths, boats, zeppelins, docks and portals (Travel).
- AllTheThings (https://github.com/ATTWoWAddon/AllTheThings), MIT licence,
  Copyright (c) 2026 AllTheThings WoW Addon: how each recipe is learned (Crafting).
- WoW Forever client tables (Blizzard Entertainment's game data, exported by
  wago.tools): what each recipe makes, skill levels and reagents (Crafting).
World of Warcraft and all related names are trademarks of Blizzard Entertainment.
Outrider is not affiliated with Blizzard Entertainment or with any project above.
Outrider_Data_Words has its own licence file inside it.
"@
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $gpl = $null
  $qzip = Get-ChildItem -Path (Join-Path $Root 'private\questie-source') -Filter '*.zip' -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($qzip) {
    $za = [System.IO.Compression.ZipFile]::OpenRead($qzip.FullName)
    try {
      $e = $za.GetEntry('QuestieDB/gpl-3.0.md')
      if ($e) { $r = New-Object System.IO.StreamReader($e.Open()); $gpl = $r.ReadToEnd(); $r.Dispose() }
    } finally { $za.Dispose() }
  }
  if (-not $gpl) { Write-Host "GPLv3 text not found in private\questie-source: not packaging." -ForegroundColor Red; return $false }
  foreach ($f in $Folders) {
    if ($f -match '^Outrider_Data_(NPC|Gear|Mobs|Nodes|Dungeons|Quests|Reagents|Paths|Travel|Crafting)$') {
      Write-Utf8NoBom (Join-Path $Staging "$f\LICENSE-DATA.txt") $note
      Write-Utf8NoBom (Join-Path $Staging "$f\gpl-3.0.md") $gpl
      # the generated TOC still carries the private-copy note: say what applies
      $tocPath = Join-Path $Staging "$f\$f.toc"
      if (Test-Path $tocPath) {
        $lines = Get-Content $tocPath | ForEach-Object {
          if ($_ -match '^##\s*Notes:') { '## Notes: Data converted from QuestieDB and ForeverDB, shared under GPLv3 (see LICENSE-DATA.txt).' } else { $_ } }
        Write-Utf8NoBom $tocPath (($lines -join "`n") + "`n")
      }
    }
  }
  # OI01-05: the MIT licence asks for its full notice with the data, not only a
  # credit line; ship AllTheThings' own LICENSE next to the Crafting data.
  if ($Folders -contains 'Outrider_Data_Crafting') {
    $att = Join-Path $Root 'private\att-source\LICENSE'
    if (-not (Test-Path $att)) { Write-Host "AllTheThings LICENSE not found in private\att-source: not packaging." -ForegroundColor Red; return $false }
    Write-Utf8NoBom (Join-Path $Staging 'Outrider_Data_Crafting\LICENSE-AllTheThings.txt') (Get-Content -Raw $att)
  }
  return $true
}
