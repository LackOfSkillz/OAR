# tools/publish.ps1
# Publishes a family build to the public release repo (Gary chose this,
# 2026-11-14): builds dist\family (tests, shared knowledge without player
# names, installer with the updater), then creates release build-<stamp> on
# LackOfSkillz/outrider-releases with Install-Outrider.cmd and the zip. The
# "Update Outrider" shortcut on family PCs finds it there.
#   powershell -ExecutionPolicy Bypass -File tools/publish.ps1 [-Notes "what's new"]
param([string]$Notes = '', [switch]$SkipTests)
. "$PSScriptRoot\common.ps1"
$root = Get-RepoRoot
$repo = 'LackOfSkillz/outrider-releases'

$args2 = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'family.ps1'))
if ($SkipTests) { $args2 += '-SkipTests' }
& powershell @args2
if ($LASTEXITCODE -ne 0) { Write-Host "Build failed. Nothing published." -ForegroundColor Red; exit 1 }

$dist = Join-Path $root 'dist\family'
$stamp = (Get-Content -Raw (Join-Path $dist 'version.txt')).Trim()
$tag = "build-$stamp"
$date = [datetime]::ParseExact($stamp, 'yyyyMMdd-HHmm', $null).ToString('MMMM d, yyyy')
if (-not $Notes) { $Notes = 'Improvements and fixes.' }
$body = @"
Outrider for WoW Forever, build $stamp ($date).

$Notes

**New install:** close WoW, download Install-Outrider.cmd below and double-click it.
**Already installed:** double-click "Update Outrider" on your desktop (WoW closed).
If Windows warns about the file, click More info, then Run anyway.

Includes data converted from QuestieDB (https://github.com/Questie/Questie), shared under GPLv3 (gpl-3.0.md inside each data folder), and world knowledge collected by Outrider (no player names). Outrider is not made by or affiliated with the Questie team.
"@
$notesFile = Join-Path $dist 'release-notes.md'
Write-Utf8NoBom $notesFile $body
& gh release create $tag (Join-Path $dist 'Install-Outrider.cmd') (Join-Path $dist 'Outrider-family.zip') --repo $repo --title "Outrider $date" --notes-file $notesFile
if ($LASTEXITCODE -ne 0) { Write-Host "Release failed." -ForegroundColor Red; exit 1 }
Write-Host "Published $tag to https://github.com/$repo/releases" -ForegroundColor Green
