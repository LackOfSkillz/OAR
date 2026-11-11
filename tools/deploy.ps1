# tools/deploy.ps1
# Runs the tests, then mirrors addon/Outrider into <WoW>\_forever_\Interface\AddOns\Outrider
# and stamps Core\Build.lua in the deployed copy so "/ride version" proves
# which build is running. Tells you whether Gary needs /reload or a restart.
#   powershell -ExecutionPolicy Bypass -File tools/deploy.ps1
#   ... -SkipTests     (only when a test failure is understood and unrelated)
#   ... -KeepAdvice    (Phase 9: do not overwrite Advisor\Advice.lua in the game folder)
param(
  [switch]$SkipTests,
  [switch]$KeepAdvice
)
. "$PSScriptRoot\common.ps1"

$cfg = Get-OarConfig
$source = Join-Path (Join-Path (Get-RepoRoot) 'addon') $script:AddonName
$target = Join-Path $cfg.addonsDir $script:AddonName

# Safety: only ever replace our own folder inside an AddOns directory.
$normalized = $target.Replace('/', '\').TrimEnd('\')
if ($normalized -notmatch '\\Interface\\AddOns\\Outrider$') { throw "Refusing to deploy to unexpected path: $target" }

if (-not $SkipTests) {
  Write-Host "Running tests..."
  $code = Invoke-OarLua @('tests/run_tests.lua')
  if ($code -ne 0) { Write-Host "Tests failed (exit $code). Not deploying." -ForegroundColor Red; exit 1 }
}

# What changed since the last deploy? New/removed files or a TOC edit need a full restart.
$stateFile = Join-Path $PSScriptRoot '.last-deploy.json'
$files = Get-ChildItem -Path $source -Recurse -File | ForEach-Object { $_.FullName.Substring($source.Length + 1).Replace('\', '/') } | Sort-Object
$fileList = ($files -join "`n")
$tocHash = (Get-FileHash -Algorithm SHA256 -Path (Join-Path $source 'Outrider.toc')).Hash
$needsRestart = $true
if (Test-Path $stateFile) {
  $deployState = Get-Content -Raw $stateFile | ConvertFrom-Json
  $needsRestart = ($deployState.tocHash -ne $tocHash) -or ($deployState.fileList -ne $fileList)
}

# Keep the companion's advice file if asked (Phase 9).
$advicePath = Join-Path (Join-Path $target 'Advisor') 'Advice.lua'
$savedAdvice = $null
if ($KeepAdvice -and (Test-Path $advicePath)) { $savedAdvice = Get-Content -Raw $advicePath }

if (Test-Path $target) { Remove-Item -Recurse -Force $target }
Copy-Item -Recurse -Path $source -Destination $target

$stamp = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + (Get-GitShort)
$buildLua = "-- Core/Build.lua (stamped by tools/deploy.ps1)`nlocal _, ns = ...`nns.build = `"$stamp`"`n"
Write-Utf8NoBom (Join-Path (Join-Path $target 'Core') 'Build.lua') $buildLua
if ($null -ne $savedAdvice) { Write-Utf8NoBom $advicePath $savedAdvice }

$state = [pscustomobject]@{ tocHash = $tocHash; fileList = $fileList; build = $stamp; at = (Get-Date).ToString('o') }
Write-Utf8NoBom $stateFile ($state | ConvertTo-Json)

Write-Host "Deployed build $stamp to $target" -ForegroundColor Green
$running = Test-WowRunning
if ($needsRestart) {
  if ($running) {
    Write-Host "TOC or file list changed: Gary must EXIT the game fully and start it again (a /reload will not pick up new files)." -ForegroundColor Yellow
  } else {
    Write-Host "Game is not running. Gary starts it, enables Outrider on the character screen (tick 'Load out of date AddOns' if shown), and logs in."
  }
} else {
  if ($running) { Write-Host "Gary types /reload in game, then /ride version should show build $stamp." }
  else { Write-Host "Game is not running. Gary starts it and logs in; /ride version should show build $stamp." }
}
