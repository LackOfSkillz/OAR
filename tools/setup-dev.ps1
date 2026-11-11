# tools/setup-dev.ps1
# One-time setup of this PC for OAR development. Run it with Setup.cmd (double-click)
# or:  powershell -NoProfile -ExecutionPolicy Bypass -File tools\setup-dev.ps1
#
# What it does (each step is skipped if already done, so it is safe to run again):
#   1. Installs Git, GitHub CLI and Python 3.12 with winget (Windows asks you to approve installers)
#   2. Installs lupa for Python (a real Lua 5.1 for the test suite)
#   3. Installs Claude Code (official installer) unless -SkipClaudeCode
#   4. Runs the OAR tests and looks for your WoW folder
#   5. Signs you in to GitHub (in your browser), creates a PRIVATE repo and pushes the project
# Everything it does is written to tools\setup-log.txt (git-ignored).
#
# Options: -RepoName OAR   -SkipClaudeCode   -SkipGitHub   -DryRun (print the plan, change nothing)
param(
  [string]$RepoName = 'OAR',
  [switch]$SkipClaudeCode,
  [switch]$SkipGitHub,
  [switch]$DryRun
)
. "$PSScriptRoot\common.ps1"

$root = Get-RepoRoot
$logPath = Join-Path $PSScriptRoot 'setup-log.txt'
Write-Utf8NoBom $logPath ("OAR setup " + (Get-Date -Format 's') + $(if ($DryRun) { ' (dry run)' } else { '' }) + "`r`n")
$problems = New-Object System.Collections.Generic.List[string]

function Log([string]$Text, [string]$Color = 'Gray') {
  Write-Host $Text -ForegroundColor $Color
  [System.IO.File]::AppendAllText($logPath, $Text + "`r`n")
}
function Step([string]$Text) { Log ''; Log "== $Text" 'Cyan' }
function Problem([string]$Text) { $problems.Add($Text); Log "!! $Text" 'Yellow' }

function Update-SessionPath {
  $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  $user = [Environment]::GetEnvironmentVariable('Path', 'User')
  $env:Path = "$machine;$user;$env:USERPROFILE\.local\bin"
}

# A command counts as present only if it is a real program (the Microsoft Store
# "python" placeholder in WindowsApps does not count).
function Test-Tool([string]$Name) {
  $c = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $c) { return $false }
  if ($Name -match '^python' -and $c.Source -like '*\WindowsApps\*') { return $false }
  return $true
}

function First-Line([scriptblock]$Cmd) {
  # (not named $Block: Invoke-NativeQuiet's own parameter would shadow it and recurse)
  $out = Invoke-NativeQuiet { & $Cmd 2>&1 | Out-String }
  return ("$out" -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
}

function Install-WithWinget([string]$Id, [string]$Command, [string]$Label) {
  if (Test-Tool $Command) { Log "found $Label ($Command)"; return }
  if ($DryRun) { Log "would install $Label with: winget install --id $Id -e"; return }
  if (-not (Test-Tool 'winget')) {
    Problem "winget is missing. Install 'App Installer' from the Microsoft Store, then run Setup.cmd again."
    return
  }
  Log "installing $Label (approve the Windows prompt if one appears)..." 'White'
  $p = Start-Process -FilePath 'winget' -NoNewWindow -Wait -PassThru -ArgumentList @(
    'install', '--id', $Id, '-e', '--source', 'winget', '--accept-package-agreements', '--accept-source-agreements', '--silent')
  Log "winget exit code $($p.ExitCode)"
  Update-SessionPath
  if (Test-Tool $Command) { Log "installed $Label" 'Green' }
  else { Problem "$Label did not end up on PATH. Close this window and run Setup.cmd again." }
}

Push-Location $root
try {
  Step "1. Tools"
  Update-SessionPath
  Install-WithWinget 'Git.Git' 'git' 'Git for Windows'
  Install-WithWinget 'GitHub.cli' 'gh' 'GitHub CLI'
  if ((Test-Tool 'python') -or (Test-Tool 'py')) { Log "found Python" }
  else { Install-WithWinget 'Python.Python.3.12' 'py' 'Python 3.12' }

  Step "2. Lua for the tests (lupa)"
  $py = $null
  foreach ($cand in @('py', 'python', 'python3')) { if (Test-Tool $cand) { $py = $cand; break } }
  if (-not $py) { Problem "Python not found, skipping lupa." }
  else {
    $hasLupa = Invoke-NativeQuiet { & $py -c "import lupa" 2>$null; $LASTEXITCODE -eq 0 }
    if ($hasLupa) { Log "found lupa" }
    elseif ($DryRun) { Log "would run: $py -m pip install --user lupa" }
    else {
      Invoke-NativeQuiet { & $py -m pip install --user --disable-pip-version-check lupa | Out-Host }
      $hasLupa = Invoke-NativeQuiet { & $py -c "import lupa" 2>$null; $LASTEXITCODE -eq 0 }
      if ($hasLupa) { Log "installed lupa" 'Green' } else { Problem "pip install lupa failed (see the messages above)." }
    }
  }

  Step "3. Claude Code"
  if ($SkipClaudeCode) { Log "skipped (-SkipClaudeCode)" }
  elseif (Test-Tool 'claude') { Log "found Claude Code" }
  elseif ($DryRun) { Log "would run the official installer: irm https://claude.ai/install.ps1 | iex" }
  else {
    Log "installing Claude Code with the official installer..." 'White'
    Start-Process -FilePath 'powershell' -NoNewWindow -Wait -ArgumentList @(
      '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', '"irm https://claude.ai/install.ps1 | iex"') | Out-Null
    Update-SessionPath
    if (Test-Tool 'claude') { Log "installed Claude Code" 'Green' }
    else { Problem "Claude Code installer finished but 'claude' is not on PATH yet. Open a new terminal and try 'claude'." }
  }

  Step "4. Tests and WoW folder"
  if ($DryRun) { Log "would run tools\test.ps1 and tools\find-wow.ps1" }
  else {
    $code = Invoke-OarLua @('tests/run_tests.lua')
    if ($code -eq 0) { Log "tests: all green" 'Green' } else { Problem "tests failed or could not run (exit $code)." }
    try {
      & (Join-Path $PSScriptRoot 'find-wow.ps1')
      if (Test-Path (Join-Path $PSScriptRoot 'local.json')) { Log "WoW folder saved to tools\local.json" 'Green' }
      else { Problem "WoW folder not found automatically; Claude Code will ask where it is." }
    } catch { Problem "find-wow: $($_.Exception.Message)" }
  }

  Step "5. Git and GitHub"
  if ($SkipGitHub) { Log "skipped (-SkipGitHub)" }
  elseif (-not (Test-Tool 'git') -or -not (Test-Tool 'gh')) { Problem "git or gh missing, skipping GitHub." }
  elseif ($DryRun) {
    Log "would: git init -b main; gh auth login --web; set a GitHub no-reply commit email; commit; gh repo create $RepoName --private --push"
  }
  else { try {
    if (-not (Test-Path (Join-Path $root '.git'))) {
      Invoke-NativeQuiet { & git init -b main | Out-Host }
      Log "created git repository"
    }
    $authed = Invoke-NativeQuiet { & gh auth status *> $null; $LASTEXITCODE -eq 0 }
    if (-not $authed) {
      Log "Sign in to GitHub. Answer the questions below if asked (GitHub.com, HTTPS, Yes, Login with a web browser)," 'White'
      Log "copy the one-time code it shows, press Enter, paste the code in the browser and approve, then come back here." 'White'
      # Called directly (not through a helper) so gh gets this console window for its prompts.
      $old = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      try { & gh auth login --hostname github.com --git-protocol https --web } catch { Log "gh auth login error: $($_.Exception.Message)" }
      Log "gh auth login exit code $LASTEXITCODE"
      $ErrorActionPreference = $old
      $authed = Invoke-NativeQuiet { & gh auth status *> $null; $LASTEXITCODE -eq 0 }
    }
    if (-not $authed) {
      Problem "GitHub sign-in did not finish. Open a terminal in this folder, run: gh auth login   then run Setup.cmd again."
    }
    else {
      Invoke-NativeQuiet { & gh auth setup-git | Out-Null }
      $login = (Invoke-NativeQuiet { & gh api user --jq .login }) | Select-Object -First 1
      $ghId = (Invoke-NativeQuiet { & gh api user --jq .id }) | Select-Object -First 1
      $ghName = (Invoke-NativeQuiet { & gh api user --jq .name }) | Select-Object -First 1
      if (-not $ghName) { $ghName = $login }
      Log "signed in to GitHub as $login" 'Green'

      # Commit identity for this repo only. The no-reply address keeps your real email out of public history.
      $email = Invoke-NativeQuiet { & git config user.email }
      if (-not $email) {
        Invoke-NativeQuiet { & git config user.name "$ghName"; & git config user.email "$ghId+$login@users.noreply.github.com" }
        Log "commit identity: $ghName <$ghId+$login@users.noreply.github.com>"
      }

      Invoke-NativeQuiet { & git add -A }
      $pending = Invoke-NativeQuiet { & git status --porcelain }
      if ($pending) {
        $trailer = "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_0184WK5DzcAEndyqESt4z1eR"
        Invoke-NativeQuiet { & git commit -q -m "P0-04: initial build package (v0.1.1)" -m $trailer }
        Log "committed project files"
      }

      $remote = Invoke-NativeQuiet { & git remote get-url origin 2>$null }
      if (-not $remote) {
        $exists = Invoke-NativeQuiet { & gh repo view "$login/$RepoName" *> $null; $LASTEXITCODE -eq 0 }
        if ($exists) {
          Invoke-NativeQuiet { & git remote add origin "https://github.com/$login/$RepoName.git" }
          Log "repo $login/$RepoName already exists on GitHub; connected it as origin"
        } else {
          Invoke-NativeQuiet { & gh repo create $RepoName --private --source . --remote origin --description "OAR: one addon for WoW Forever (working name)" | Out-Host }
          Log "created private repo $login/$RepoName" 'Green'
        }
      }
      Invoke-NativeQuiet { & git push -u origin main 2>&1 | Out-Host }
      $pushed = Invoke-NativeQuiet { & git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null }
      if ($pushed) { Log "pushed main to GitHub" 'Green' } else { Problem "push did not complete (if the GitHub repo already had files, Claude Code can sort it out)." }
      $url = Invoke-NativeQuiet { & gh repo view --json url -q .url 2>$null }
      if ($url) { Log "repo: $url" }
    }
  } catch { Problem "GitHub step stopped: $($_.Exception.Message)" } }

  Step "Summary"
  Update-SessionPath
  $pyCmd = $null
  foreach ($cand in @('py', 'python', 'python3')) { if (Test-Tool $cand) { $pyCmd = $cand; break } }
  foreach ($t in @(
      @{ n = 'git'; c = 'git' }, @{ n = 'gh'; c = 'gh' }, @{ n = 'python'; c = $pyCmd }, @{ n = 'claude'; c = 'claude' })) {
    $exe = $t.c
    if ($exe -and (Test-Tool $exe)) {
      $ver = try { First-Line { & $exe --version } } catch { '(installed, version check failed)' }
      Log ("  {0,-7} {1}" -f $t.n, $ver)
    } else { Log ("  {0,-7} not installed" -f $t.n) }
  }
  if ($problems.Count -eq 0) {
    Log ''
    Log "All set. Open a terminal in $root and run: claude" 'Green'
    Log "Then say: Read CLAUDE.md, then start Phase 0." 'Green'
  } else {
    Log ''
    Log "Finished with $($problems.Count) thing(s) to look at:" 'Yellow'
    foreach ($p in $problems) { Log "  - $p" 'Yellow' }
  }
} finally {
  Pop-Location
}
