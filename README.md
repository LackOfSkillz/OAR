# Outrider: one addon for WoW Forever

One character-aware addon instead of ten: rare alerts and hunter pet tools, map pins that appear as you approach, a macro library, crafting, auction and fishing helpers, a gear advisor, a cleaner interface and guild sharing. Built by Claude Code on your PC, tested by you in game.

## What's in this package

- `CLAUDE.md`: the rulebook Claude Code reads first (rules, the build-test loop, commands).
- `TASKS.md` and `phases/`: the full engineering plan, Phase 0 to Phase 9, broken into micro-tasks with acceptance checks.
- `docs/`: architecture, WoW Forever constraints, conventions, data formats, the test loop, decisions.
- `addon/Outrider/`: a working Phase 0/1 foundation (module loader, per-character settings, export/import, error catcher, debug log, API probe, hub window, minimap button, settings page, dormant AI-advisor groundwork).
- `tests/`: 71 automated tests that load the addon in a fake WoW client (syntax, stray globals, settings surviving a restart, export/import, modules, data packs, the log reader).
- `tools/`: PowerShell scripts that find WoW, deploy the addon, read the results back, back up settings, and grab your screenshots.

## Start (about 15 minutes, once)

1. **Put the folder** somewhere outside the WoW folder, for example `C:\Users\<you>\Dev\Outrider`.
2. **Double-click `Setup.cmd`.** It installs Git, the GitHub CLI, Python with lupa (a real Lua 5.1 for the tests) and Claude Code, runs the tests, finds your WoW folder, signs you in to GitHub in your browser and pushes the project to a new **private** repo. Approve the Windows installer prompts when they appear. It is safe to run again; finished steps are skipped. Everything is logged to `tools\setup-log.txt`.
3. **Recommended addons** for error capture: install **BugGrabber** and **BugSack** in WoW Forever.
4. **Open a terminal** in the Outrider folder and run `claude`.
5. **Say:** `Read CLAUDE.md, then start Phase 0.`

## What you'll be asked to do in game

- Log in, and the first time, open **AddOns** on the character screen, make sure **Outrider** is ticked (tick "Load out of date AddOns" if it shows).
- Type short commands it gives you, like `/ride status`, then `/reload`. A `/reload` is how results get written to disk where Claude Code can read them.
- Sometimes: press **Print Screen** so Claude Code can look at what you see.
- Sometimes: **fully exit and restart** the game (needed whenever new files were added).
- Make the calls that are yours: the addon's real name, whether it goes public, how the UI should look.

Claude Code never presses keys in your game. Every action in WoW is yours.

## Useful in-game commands

`/ride` opens the hub. `/ride help` lists everything. `/ride status` shows the character, whether settings saved, and the error count. `/ride errors` shows Outrider errors.
