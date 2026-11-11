# Phase 0: Setup and ground truth

**Goal:** the deploy, reload, read loop works on Gary's PC, and we know (not guess) what the WoW Forever client allows: interface number, SavedVariables behavior, which APIs and events exist.

**Gate G0:** a code change goes from Claude's edit to Gary's screen and back into Claude's log reader in under two minutes; SavedVariables round trip is confirmed (or the fallback is chosen); `docs/PROBE_RESULTS.md` is filled in and committed.

Task format: **owner** (Claude / Gary / Both) · **deps** · steps · files · done when.

---

### P0-01 · Prepare the PC · Gary · deps: none
1. Project folder outside the WoW folder (e.g. `~\Dev\OAR`).
2. Double-click `Setup.cmd`: Git, GitHub CLI, Python + lupa, Claude Code, tests, WoW folder, GitHub sign-in, private repo push. Log: `tools\setup-log.txt`.
3. Install BugGrabber and BugSack in WoW Forever (CurseForge app or manual).
4. Open a terminal in the folder, run `claude`, say "Read CLAUDE.md, then start Phase 0."

**Done when:** setup-log.txt ends with "All set" (or Claude Code fixes what it lists) and Claude Code has read CLAUDE.md.

### P0-02 · Find WoW · Claude · deps: P0-01
1. `tools/find-wow.ps1`. If it fails, ask Gary where WoW is installed and pass `-WowRoot`.
2. Confirm the client folder (`_forever_` expected; `_classic_beta_` on older installs). If several client folders exist, ask Gary which one he plays.
3. Record the folder in `docs/PROBE_RESULTS.md` (Client folder row).

**Files:** `tools/local.json` (generated, git-ignored).
**Done when:** local.json has `addonsDir` and the folder exists.

### P0-03 · Tests green on Gary's PC · Claude · deps: P0-01
1. `tools/test.ps1`.
2. If no Lua is found, install lupa (P0-01) or a Lua 5.1 build. Do not switch the test runner to Lua 5.3/5.4 (the sandbox uses `setfenv`, which only 5.1 has, and WoW is 5.1).

**Done when:** the summary line shows 0 failed and 0 syntax errors (71 tests at handoff; more as phases add specs).

### P0-04 · Git repository · Claude · deps: P0-03
1. `git init`, `git add -A`, first commit `P0-04: initial build package`.
2. Set `git config user.name` / `user.email` only if Gary gives them; otherwise use a local placeholder and tell him.
3. If Gary wants a GitHub remote, ask for the repo name; create it private.

**Done when:** `git log` shows the first commit and `git status` is clean.

### P0-05 · First deploy and login · Both · deps: P0-02, P0-03
1. Claude: `tools/deploy.ps1`. Note the build stamp.
2. Gary: start the game (fully restart if it was running), on the character screen open **AddOns**, make sure **OAR** is ticked; tick **Load out of date AddOns** if OAR shows as out of date. Log in on Torrant.
3. Gary: `/oar version`, then `/reload`.
4. Claude: `tools/read-logs.ps1`.

**Done when:** the log shows `version v0.1.0 build <stamp>` with the stamp deploy printed, and `login complete` with no errors. Gary saw the one-time greeting.

### P0-06 · Real interface number · Both · deps: P0-05
1. Gary: `/dump select(4, GetBuildInfo())` and `/dump GetBuildInfo()`; tell Claude the numbers (or Claude reads them from the P0-05 version log line).
2. Claude: set `## Interface:` in `addon/OAR/OAR.toc` to the real number. Several builds can be listed comma separated if Forever and its PTR differ (`## Interface: 16001, 16002`).
3. Deploy; Gary restarts the game (TOC change).

**Done when:** OAR no longer shows "out of date" on the AddOns screen without the checkbox; C1 in FOREVER_CONSTRAINTS.md is marked Confirmed with the value.

### P0-07 · SavedVariables round trip (critical) · Both · deps: P0-05
The early-beta bug (settings written but not read back) decides how everything else stores data.
1. Claude: `tools/backup-sv.ps1` (if a file exists yet).
2. Gary: `/oar mark P0-07 start`, `/oar debug on`, `/reload`, `/oar status`, `/reload`, `/oar status`.
3. Gary: exit the game fully, start it, log in on Torrant, `/oar status`, `/reload`.
4. Claude: `tools/read-logs.ps1 -Section all`. Expect `loads` to have risen by one per load, `saved settings read back: yes`, and `debug true` kept.

**Done when (pass):** loads counter rose across both /reload and a full restart; PROBE_RESULTS round-trip table filled; C4 marked Confirmed fixed.
**If it fails:** stop feature work. (a) Check whether `WTF\...\SavedVariables\OAR.lua` exists and has the data (written but not read back) or not (not written). (b) Read how the community workarounds (Forever Data Protect, ForeverSVBridge) solve it and pick the approach with Gary; implement it in `Core/DB.lua` behind a flag; add a spec. (c) Rerun P0-07.

### P0-08 · API probe · Both · deps: P0-05
1. Gary, out of combat in a town with NPCs around: target an NPC, `/oar probe`.
2. Gary, near hostile mobs (nameplates visible), target one: `/oar probe`.
3. Gary, in combat with a low-level mob, target it: `/oar probe` (read-only, safe). A "blocked action" popup about the combat log is possible and harmless.
4. Gary: `/reload`.
5. Claude: `tools/read-logs.ps1 -Section probe`. API and event results come from the latest run; unit readability is kept for the last six runs, labeled in or out of combat.
6. Claude: fill `docs/PROBE_RESULTS.md` (client, APIs missing/present that matter, events, units in and out of combat). Update FOREVER_CONSTRAINTS statuses (C3, C5, C6, C9, C16). Simplify `Core/Compat.lua` where an API is confirmed (keep fallbacks only where both styles might exist).

**Done when:** PROBE_RESULTS.md has real values; every row in FOREVER_CONSTRAINTS that the probe can answer has a status other than Reported; commit `P0-08: probe results`.

### P0-09 · Error pipeline check · Both · deps: P0-05
1. Gary: `/oar selftest error`, `/oar selftest combat` (once out of combat; once while in combat with a mob, then leave combat), `/reload`.
2. Claude: `tools/read-logs.ps1 -Section errors -Bugs`.

**Done when:** the deliberate error appears once in OAR's error list with a stack, BugGrabber shows it too (if installed), and the log shows "combat queue ran" after combat ended. Then Gary types `/oar errors clear`.

### P0-10 · Name and rename · Gary decides, Claude renames · deps: none (do before the P1 gate)
1. Gary picks the addon's name (Q1 in DECISIONS.md). Claude checks CurseForge/Wago for a collision by web search.
2. Claude renames: folder `addon/OAR` → `addon/<Name>`, TOC file name, `## Title`, `M.ADDON` in tests, `AddonName` in tools/common.ps1, deploy path check, global prefix `OAR_` → `<PREFIX>_` (SavedVariables names, frames, slash `SLASH_OAR1`), slash command `/oar` → Gary's choice (keep `/oar` as an alias if he likes).
3. A rename changes SavedVariables names: write a one-time migration that copies `OAR_DB` into the new name if the old one exists (it will only exist if the old folder is still installed; otherwise accept a fresh start and say so).
4. Tests green, deploy, Gary removes the old `Interface\AddOns\OAR` folder and restarts.

**Done when:** game shows the new name, `/newcmd version` works, tests green, DECISIONS D8 updated.

### P0-11 · Screenshot loop · Both · deps: P0-05
1. Gary: open the OAR hub (`/oar`), press Print Screen.
2. Claude: `tools/screenshot-latest.ps1`, open the path with the Read tool, describe what the hub shows.

**Done when:** Claude correctly reads the character name and build line off the screenshot. Note the screenshot resolution and format in PROBE_RESULTS.md (helps later UI work).
