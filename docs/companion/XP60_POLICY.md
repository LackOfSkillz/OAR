# XP60 delivery policy (OI08-05)

**Status: automatic install is OFF.** It stays off until the owner approves it in writing.

**Why.** CLAUDE.md hard rule 2 says Outrider writes to the WoW folder only through `tools/deploy.ps1`. Decisions D16 and D18 allow one exception in principle: a data-only `Advisor/Advice.lua`, shown after a reload. The XP60 watcher can write that file after the game exits, so it needs an explicit owner decision before it may.

**What runs without approval:**
- `xp60_cli` reads SavedVariables and prints the plan (preview).
- The Advisor tab shows a plan only when the player pastes a code.

**What needs approval:** `--install`, alone or with `--watch`. `write_after_exit` refuses unless `companion/policy.json` contains:

```json
{ "xp60AutoInstall": { "approved": true, "by": "Gary", "date": "YYYY-MM-DD" } }
```

**When approved, every install still:**
- verifies by process list (read-only) that the game is closed, before and right before writing; an unknown process status counts as running;
- writes only `Interface\AddOns\Outrider\Advisor\Advice.lua`, which must already exist;
- writes data only, validated by `advice.py` (schema, 12 items, 64 KB, 4 actions);
- never touches `WTF\`.

**Tests** (`companion/tests/test_xp60_delivery.py`):
- no policy file means refused;
- `approved` not exactly `true` means refused;
- an approved policy with the game running means refused;
- the approved path with the game closed writes only Advice.lua.

The real Windows trial is pending the owner's approval.
