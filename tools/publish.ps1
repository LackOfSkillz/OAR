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

**New install (5 minutes):**
1. Close World of Warcraft.
2. Download **Install-Outrider.cmd** below. If the browser says it "isn't commonly downloaded", choose **Keep** (Edge: ..., Keep, Show more, Keep anyway).
3. Double-click it in your Downloads folder. If a blue box says "Windows protected your PC", click **More info**, then **Run anyway**.
4. When it says Outrider is installed, start the game. On the character screen click **AddOns** and make sure Outrider is ticked (and "Load out of date AddOns" if you see it).
5. Log in and type /ride.

Step by step with help for problems: https://github.com/LackOfSkillz/outrider-releases#how-to-install-5-minutes-windows

**Already installed:** close WoW and double-click "Update Outrider" on your desktop.

Includes data converted from QuestieDB (https://github.com/Questie/Questie), shared under GPLv3 (gpl-3.0.md inside each data folder), and world knowledge collected by Outrider (no player names). Outrider is not made by or affiliated with the Questie team.
"@
# checksum: the updater refuses an installer whose SHA-256 doesn't match the
# .sha256 file and the line in the notes (catches a corrupted or swapped download)
$installerPath = Join-Path $dist 'Install-Outrider.cmd'
$sha = (Get-FileHash -Algorithm SHA256 -Path $installerPath).Hash.ToLower()
$shaFile = Join-Path $dist 'Install-Outrider.cmd.sha256'
Write-Utf8NoBom $shaFile ("$sha  Install-Outrider.cmd`n")
$body = $body + "`n`nSHA256 (Install-Outrider.cmd): $sha`n"
$notesFile = Join-Path $dist 'release-notes.md'
Write-Utf8NoBom $notesFile $body
& gh release create $tag $installerPath $shaFile (Join-Path $dist 'Outrider-family.zip') --repo $repo --title "Outrider $date" --notes-file $notesFile
if ($LASTEXITCODE -ne 0) { Write-Host "Release failed." -ForegroundColor Red; exit 1 }
Write-Host "Published $tag to https://github.com/$repo/releases" -ForegroundColor Green
