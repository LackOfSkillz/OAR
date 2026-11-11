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
