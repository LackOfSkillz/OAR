# XP60 AfterAction — Windows setup and beta acceptance

**Status: developer beta code, NOT real-client approved.** The desktop app is
currently a Python CLI/polling companion, not a system-tray installer. The
feature is opt-in and the external companion never observes the live WoW
process or gameplay stream.

## 1. Enable recording on the character

Install the AI branch's updated Outrider addon with WoW fully closed.
Launch Forever and enter:

```
/ride xp60 on
/ride xp60 status
```

The recorder stores bounded XP, level, quest turn-in and zone-time samples in
the normal account-wide `Outrider_DB` SavedVariables. It is OFF by default
until you enable it. Existing `/ride ask` and manual companion workflows
remain available. To stop, use `/ride xp60 off`; to erase this character's
XP60 history, use `/ride xp60 clear`.

Let WoW fully exit to write SavedVariables. `/reload` also writes a
checkpoint, but it must not be treated as a completed offline delivery while
the client remains active.

## 2. Preview analysis without modifying game files

Open PowerShell in the repository's `companion` folder (Python required):

```powershell
python -m outrider_companion.intelligence.xp60_cli --savedvariables "C:\\Path\\To\\WTF\\Account\\ACCOUNT\\SavedVariables\\Outrider.lua"
```

The `Outrider.lua` name is correct even though its main Lua global is
`Outrider_DB`. The tool chooses the most recently completed character by
default. Optionally pass `--character Name-Realm` to pin one.

The preview prints only summary status, a local source session ID,
observed XP/hour if sufficient, and whether advice was installed. It
does not execute Lua from the saved file or contact an AI service.

## 3. Opt in to automatic next-session delivery

Point `--addon-dir` at the actual folder that contains
`Advisor\Advice.lua`:

```powershell
python -m outrider_companion.intelligence.xp60_cli --savedvariables "C:\\Path\\To\\WTF\\Account\\ACCOUNT\\SavedVariables\\Outrider.lua" --addon-dir "C:\\Path\\To\\Interface\\AddOns\\Outrider" --watch --install
```

This command stays running in that console while enabled. It polls at
five-second intervals, waits for complete/stable SavedVariables writes,
deduplicates by file digest, and **defers installation while WoW is running**
or the process status cannot be verified. On Windows it checks the process
list before and immediately before writing. Nothing writes to the WTF folder.
If the client reopens before delivery, the write is rejected and retried.

It replaces only the preexisting `Outrider/Advisor/Advice.lua` with a
validated, nonexecutable `Outrider_Advice` table. No new Lua modules, macros,
waypoints or executable scripts are installed at runtime.

For this initial beta, starting this command is manual; it is not registered
as a Windows startup service or task without the player's permission.

## 4. On the next login

Outrider may print one quiet status line, but never forces an overlay.
Open:

```
/ride nextsession
```

The window shows a 60-minute XP focus, the previous observed wall-clock
XP/hour when available, tentative source-grounded quest options or a
supported next-step sequence, and caveats about estimated travel/Classic
quest rewards. Use Dismiss, Already know, Not interested or Useful to
record local feedback.

The report is rejected if it belongs to another character, names an
unexpected source session, has expired, or includes executable actions.
A change in the character's level or game build also invalidates the
report. The default fallback is to keep the current route.

## What the numerical figures do and do not mean

- **Observed XP/hour** means verified XP earned / measured elapsed wall time
  (including travel, loading, downtime and hand-ins).
- **Tentative route steps** may use Journey's Classic-derived quest XP
  formula, travel graph and five-minute objective assumption; those are
  not verified rewards or assured finish times.
- In tentative mode the coach explicitly withholds a predicted XP gain,
  uplift percentage and claim that a new route is objectively superior.
- Verified quest reward XP can be recorded from supported
  `QUEST_TURNED_IN` event arguments; an absent/secret XP value is unknown.
- On level changes, unavailable caps, rest/boost differences, unknown travel
  or incomplete writes, comparisons lose certainty rather than invent data.
- No real-time model connection, gameplay control, combat-log listener, input
  simulation, AH purchase, or client-memory reader exists in XP60.

## Mandatory owner beta checklist

1. Measure starting/ending XP and session wall time by hand; compare with
   `Outrider_DB.chars[character].xp60.history`.
2. Repeat across a level-up and an unknown XP event; ensure no overcount.
3. Leave a long play session and then close WoW; confirm quest snapshots and
   a new history record exist in `Outrider.lua`.
4. Launch the watcher **while WoW is running**, /reload, then exit; verify
   that `Advisor/Advice.lua` is never modified until after full exit.
5. Reopen the game and use `/ride nextsession`; verify correct character,
   session binding, quest/source ages and no modal takeover.
6. Switch characters; verify no cross-character report, plus saved settings
   and expected behavior after full restart.
7. Trigger stale/unknown-map or already-completed quests; no false
   "verified" destination or improvement percentage.
8. Monitor addon memory, event timings, screen/taint warnings and performance
   against the I2 project budget. Test Warrior, Hunter and Druid first,
   then all nine original classes.
9. Validate 25 real suggestions for usefulness, relevance, minimal clicks,
   avoided lecturing, and outperforming continued gameplay.
10. Finish owner policy/security/licensing review before calling it a beta
    release. D18's live transport research remains blocked.

## Developer regression path

Run `tools/test.ps1 -RequirePython` on the AI branch or review the
GitHub Actions workflow. Both Lua addon tests and isolated Python
`companion/tests/test_xp60*.py` must pass. CI is necessary but cannot
substitute for Windows process/watcher and real-game acceptance.

See `AFTERACTION_XP60_ENGINEERING_DESIGN.md` for contracts and
`OUTRIDER_INTELLIGENCE_2_0_IMPLEMENTATION_BACKLOG.md` for open gates.
