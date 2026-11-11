# CLAUDE.md: Outrider, one addon for WoW Forever

You are building **Outrider**, a single World of Warcraft addon for **WoW Forever** (Blizzard's Classic+ servers, launched November 2026, running on the modern Midnight-era client). It replaces a stack of separate addons with one character-aware addon: rare alerts and hunter pet tools first, then maps and waypoints, a macro library, professions, auctions and fishing, a gear advisor, a cleaner interface, and guild sharing. An AI advisor comes last (groundwork is already in the code, dormant).

**Gary** plays and tests. His main is Torrant Mcluvin, a Horde hunter; he also plays a priest and a mage. You write all the code, run the tests, deploy into his game folder, and read the results. Gary presses every key in the game.

Read this file fully before every session. **If `HANDOFF.md` exists, read it next and do its "Start here" list first.** Then open `TASKS.md` and continue from the first unchecked task whose dependencies are done.

---

## 1. Hard rules (never break these)

1. **No game automation, ever.** Never send keystrokes, clicks or any input to the WoW client: no AutoHotkey, no SendInput, no computer-use tools, no macros fired from outside the game. In addon code, every protected action (cast, target, use, equip in combat) must come from a key press or click by Gary through a secure button or macro, the same way a normal macro works (one press may target and cast, like the tame macro). Code never fires actions on a timer, on an event, or in a loop. This is Blizzard's rule and it protects Gary's account.
2. **Never write inside the WoW folder except `Interface\AddOns\Outrider`, and only through `tools/deploy.ps1`.** Treat `WTF\` as read-only. Never edit SavedVariables while the game is running: WoW overwrites them on logout. Restoring a backup needs the game closed (`tools/backup-sv.ps1 -Restore`).
3. **Fail soft.** Any API that might not exist on Forever goes through `ns.Compat` or `pcall`. A missing API turns a feature off; it never throws. Everything we run is wrapped by `ns.Safe` (the event system and modules do this for you).
4. **No combat log parsing.** Do not build features on `COMBAT_LOG_EVENT_UNFILTERED`. Treat secret values (`issecretvalue`) as unknown: display them, never compute with them.
5. **No protected frame changes in combat.** Creating, moving, showing or hiding secure frames goes through `Module:Secure(label, fn)` / `ns.Combat:Run`, which waits for combat to end.
6. **Quiet by default.** No chat spam. At most one chat line per kind of event per session unless debug mode is on. Sounds and toasts only for things Gary asked for (rare alerts).
7. **Never invent game data.** NPC IDs, item IDs, coordinates, respawn times and spell ranks come from in-game capture (discovery mode, the probe) or a cited source, and stay `verified = false` until Gary has seen them in game on WoW Forever. Mulgore and other zones were redrawn, so old Classic coordinates are wrong until checked.
8. **Hook, don't replace.** If Questie, TomTom, Auctionator, TSM, GearQuest, ElvUI or similar are installed, use their data or step aside (`yieldsTo` in the module spec). One owner per frame: never fight another addon for a Blizzard frame.
9. **Tests green before every deploy.** `tools/deploy.ps1` runs them and refuses to deploy on failure. Don't use `-SkipTests` to get around a failure you don't understand.
10. **Privacy.** Nothing leaves Gary's PC. No network calls from tools without asking him. Addon messages go only over GUILD/PARTY/RAID/WHISPER and only for features he switched on.

## 2. Who does what

| You (Claude Code) | Gary |
|---|---|
| Write Lua, data packs, tests, docs | Plays, presses every key in game |
| Run `tools/test.ps1`, `tools/deploy.ps1` | Types `/reload`, slash commands, presses Print Screen |
| Read results with `tools/read-logs.ps1` and screenshots | Makes the calls that are his (name, license, look, what to build next) |
| Update `TASKS.md`, commit | Says "done" or describes what he saw |

## 3. The loop (every task)

1. **Pick** the next unchecked task in `TASKS.md` whose dependencies are done. Read its section in `phases/Px_*.md`. Tasks marked **Gary** need him; tasks marked **Claude** you do alone; **Both** means code first, then a short in-game check.
2. **Build.** Write the code and the unit tests for anything with logic in it (`tests/spec/*_spec.lua`). Extend `tests/lib/wowmock.lua` when you need a new fake API, and keep fakes close to the real API's shape.
3. **Test.** `powershell -NoProfile -ExecutionPolicy Bypass -File tools/test.ps1` (syntax check of every file, no stray globals, no overwritten Blizzard globals, all specs). Fix until green.
4. **Deploy.** `powershell -NoProfile -ExecutionPolicy Bypass -File tools/deploy.ps1`. It prints whether Gary needs `/reload` or a **full game restart** (a restart is needed whenever the TOC changed or files were added or removed).
5. **Ask Gary** for the in-game step in a short numbered list he can follow while playing. Always end with `/reload` so the results are written to disk. Example:
   > 1. `/reload`  2. `/ride mark P2-04`  3. target The Rake  4. `/reload`  5. say done
6. **Read.** `tools/read-logs.ps1` (add `-Mark P2-04` to see only what happened after the marker, `-Bugs` for BugGrabber, `-Section probe|chars|errors|all`). For visuals: `tools/screenshot-latest.ps1`, then open the printed path with the Read tool.
7. **Close out.** Tick the task in `TASKS.md` with the date and one line of notes (what was verified, what changed). Commit. If something new was learned about the client, write it into `docs/PROBE_RESULTS.md` or `docs/FOREVER_CONSTRAINTS.md`.

Batch in-game checks: if three tasks each need a 30-second check, deploy once and give Gary one combined list.

## 4. Commands

All from the repo root. On Windows prefix each with `powershell -NoProfile -ExecutionPolicy Bypass -File`.

| Command | What it does |
|---|---|
| `tools/find-wow.ps1 [-WowRoot X] [-Flavor _forever_]` | Finds WoW and writes `tools/local.json` (once) |
| `tools/test.ps1 [filter]` | Syntax check + all specs (or specs matching filter) |
| `tools/deploy.ps1 [-SkipTests] [-KeepAdvice]` | Test, copy to AddOns\Outrider, stamp the build id |
| `tools/read-logs.ps1 [-Section s] [-Mark text] [-Last n] [-Bugs]` | Print the saved log, errors, probe, characters |
| `tools/screenshot-latest.ps1 [-Count n] [-Minutes m]` | Paths of Gary's newest screenshots |
| `tools/backup-sv.ps1 [-Restore stamp]` | Back up / restore SavedVariables (restore only with the game closed) |
| `tools/package.ps1` | Release zip in `dist\` |
| `python tools/lua.py <script.lua> [args]` | Lua 5.1 without installing Lua (needs `pip install lupa`) |
| `python tools/build_tasks.py` | Rebuild TASKS.md after editing phase files (keeps statuses and notes) |

Optional: `tools/claude-settings.example.json` pre-approves the commands above. Copy it to `.claude/settings.json` only if Gary wants fewer permission prompts.

In game (Gary), `/ride` or `/outrider`: `/ride` hub, `/ride help`, `/ride version`, `/ride status`, `/ride mark <text>`, `/ride debug on|off`, `/ride errors`, `/ride probe`, `/ride modules`, `/ride module <Name> on|off`, `/ride export|import|copy <Name-Realm>|chars`, `/ride snap`, `/ride selftest error|combat`.

## 5. Repo map

```
CLAUDE.md            this file
README.md            Gary's quick start
TASKS.md             master checklist (status lives here; 113 tasks, generated from phases/)
CHANGELOG.md         what changed per version
HANDOFF.md           one-time notes from the planning chat (read first, then retire it)
phases/P0..P9_*.md   detailed micro-tasks with steps and acceptance checks
docs/
  ARCHITECTURE.md    how the addon is put together
  CONVENTIONS.md     code style, module template, naming, events, UI rules
  FOREVER_CONSTRAINTS.md  what the client allows, with confidence levels
  PROBE_RESULTS.md   facts measured on Gary's client (fill in P0-08)
  DATA_SCHEMAS.md    data pack formats (rares, POIs, macros, beasts, gear...)
  TEST_LOOP.md       the in-game test protocol in detail
  DECISIONS.md       decisions made and open questions for Gary
  AI_ADVISOR_LATER.md the parked Phase 9 design
addon/Outrider/           the addon (deployed as-is to Interface\AddOns\Outrider)
  Outrider.toc            load order; Init first, Boot last
  Core/              namespace, compat, log, errors, events, combat, serialize, db, profiles, modules, probe, slash, boot
  UI/                theme tokens, widget kit, hub window, minimap button, settings page
  Advisor/           snapshot + advice loader (dormant until Phase 9), Advice.lua is data only
  Data/              data pack registry and packs
  Modules/           one file or folder per feature module
tests/               run_tests.lua, lib/ (tiny test framework, WoW mock), spec/*_spec.lua
tools/               PowerShell scripts, sv_dump.lua (SavedVariables reader), lua.py, build_tasks.py
```

## 6. Writing code here

Read `docs/CONVENTIONS.md` before your first module. The short version:

- Every file starts `local ADDON, ns = ...`. No new globals except the ones listed in `tests/spec/boot_spec.lua` (`Outrider`, `Outrider_DB`, `Outrider_Log`, `Outrider_Snapshots`, `Outrider_Advice`, `SLASH_OUTRIDER1`) and named frames prefixed `Outrider_`. Never assign to an existing Blizzard global; the tests catch both.
- Features are modules: `ns:NewModule(name, spec)`, copying `Modules/Welcome.lua`. Register events with `self:On(...)` so disabling the module cleans up.
- Per-character settings: `self:Settings()`. Account-wide data (discovered NPCs, price history): `ns.db.global.<module>`.
- Log with `self:Info/Debug/Warn(...)`. That log is your eyes in game.
- Lua 5.1 only (WoW's dialect): no `goto`, no integer division `//`, no `%d` with numbers above 2^31 (use `%.0f`), `xpcall` without extra arguments.
- Adding a file means adding it to `Outrider.toc` in the right place, or the TOC test fails, and Gary needs a full restart after the deploy.
- Big static data (thousands of items) goes in a separate load-on-demand addon later (`Outrider_Data_*`), not in the core TOC.

## 7. Talking to Gary

- He is playing while you work. Keep in-game instructions to a numbered list of slash commands and simple actions. No walls of text.
- Tell him plainly when he must fully exit the game instead of `/reload`.
- When you need to see something, ask for Print Screen and use `tools/screenshot-latest.ps1`.
- Decisions that are his (see `docs/DECISIONS.md`): ask with two or three concrete options and your recommendation. Everything else, decide, note it in DECISIONS.md, and keep going.
- He reports results in plain words ("the toast popped but no sound"). Confirm against the log before changing code.

## 8. Definition of done (per task)

- Code + specs written, `tools/test.ps1` green.
- Deployed, the in-game check in the task's "Done when" passed (confirmed through the log, a screenshot, or Gary's report backed by the log).
- No new entries in `/ride errors` or BugGrabber caused by the change.
- `TASKS.md` ticked with date and note; commit made.

## 9. When something is unknown or broken

- **API might not exist:** check `docs/PROBE_RESULTS.md`. If it isn't listed, add it to `Probe.APIS` in `Core/Probe.lua`, deploy, have Gary run `/ride probe` then `/reload`, and read with `tools/read-logs.ps1 -Section probe`.
- **Lua error in game:** `tools/read-logs.ps1 -Section errors -Bugs`. Reproduce in a spec if the logic allows, fix, retest.
- **Taint ("Outrider has been blocked from an action"):** look for a protected call outside a key press, or a secure frame touched in combat. The `taint` entries in `/ride errors` name the function.
- **Settings not saving:** P0-07 decides this early. If the client does not read SavedVariables back, stop feature work and follow the fallback in `phases/P0_setup.md`.
- **Stuck after two honest attempts:** write down what you tried in the task's notes, tell Gary in two sentences, and move to the next independent task.

## 10. Git

- `main` is always deployable. One branch per phase (`p2-hunter-rares`) or straight to main for small tasks; merge when the phase gate passes.
- Commit messages: `P2-04: rare detector reads nameplates`. Reference the task ID.
- Never commit `tools/local.json`, `backups/`, `dist/` (already in `.gitignore`).
