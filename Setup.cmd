@echo off
title Outrider setup
echo Outrider setup: installs Git, GitHub CLI, Python + lupa and Claude Code, then connects GitHub.
echo Every step is logged to tools\setup-log.txt
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\setup-dev.ps1" %*
echo.
pause
