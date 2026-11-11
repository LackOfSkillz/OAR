# The in-game test loop

Claude Code cannot see the game. It sees three things: the files it deploys, the SavedVariables WoW writes on `/reload`/logout, and screenshots Gary takes. Every in-game test is designed around that.

## One cycle

1. Claude: `tools/test.ps1` green, then `tools/deploy.ps1`. Note the build stamp it prints.
2. Claude to Gary, as a numbered list, e.g.:
   1. `/reload` (or "exit the game fully and start it again" if deploy said so)
   2. `/oar version`: should say build `20261111-1530-abc123`
   3. `/oar mark P2-04 start`
   4. do the thing (target The Rake, open a trainer, fish for 2 minutes...)
   5. `/reload`
   6. say "done" (and anything you noticed)
3. Claude: `tools/read-logs.ps1 -Mark P2-04` (plus `-Section errors -Bugs` if anything looks off).
4. If the read-logs header warns the file is older than the deploy, Gary hasn't reloaded yet. Ask again; don't diagnose stale data.

## Screenshots

Gary presses Print Screen (WoW saves to `_forever_\Screenshots`). Claude runs `tools/screenshot-latest.ps1` and opens the path with the Read tool. For UI work ask for two shots: before and after. Ask Gary to hide anything private on screen (chat with real names) if it matters to him.

## What to log for a test

Each task's "Done when" names the log lines to look for. Add `self:Info(...)` lines that make the check unambiguous: include IDs and counts (`rare seen npcID=5807 layer=12 source=nameplate`).

## Quick commands Gary may be asked to type

| Command | Use |
|---|---|
| `/reload` | write results to disk, reload code |
| `/oar version` | prove which build is running |
| `/oar status` | character, saved-settings check, module count, errors |
| `/oar mark <text>` | marker so read-logs shows only what follows |
| `/oar debug on` | store debug lines (turn off after the test) |
| `/oar errors` | errors in chat |
| `/oar probe` | API facts (then /reload) |
| `/dump <expression>` | Blizzard's own inspector, e.g. `/dump C_Map.GetBestMapForUnit("player")` |
| `/framestack` | name of the frame under the mouse (UI work) |
| `/console scriptErrors 1` | show Lua errors on screen (if BugSack is not installed) |
| `/etrace` | event trace window (debugging events) |

## Headless tests vs in-game tests

Everything that is logic (parsing GUIDs, scoring gear, validating macros, merging prices, respawn math, serialization, settings persistence) is tested headless in `tests/spec`. In-game checks are for what the mock cannot prove: real API shapes, real event timing, how it looks, taint, and that Gary finds it useful. Keep in-game checks short and batch them.

## Safety

- Back up SavedVariables (`tools/backup-sv.ps1`) before a schema migration or a test that wipes settings.
- Never edit SavedVariables while the game is running.
- Never send input to the game.
