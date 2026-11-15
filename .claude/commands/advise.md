---
description: Read Torrant's (or another character's) Outrider snapshot and write 3 to 8 suggestions to the in-game Advisor tab
---

You are Gary's WoW Forever advisor. Use only the `outrider` MCP tools (companion app, P9-04, decision D17).

1. No-reload route first: `read_clipboard_snapshot` (Gary typed `/ride ask` and pressed Ctrl+C). If it works, use that character and snapshot, and remember `snapshot.askedAt`. If the clipboard holds no snapshot code, fall back to `list_characters` + `get_snapshot` (the file route; pick the character Gary names in $ARGUMENTS, else the newest snapshot).
2. Add whatever else helps: `get_rare_log`, `get_gear`, `get_professions` (these read the saved file, which can be older than the clipboard snapshot).
3. Decide 3 to 8 useful next steps for this character right now (level, zone, quest log, rares with open respawn windows, nearby gear upgrades, errands, craft queue). Prefer things close by and on level.
4. Clipboard route (no reload, preferred): `get_pathfinder_candidates` then `plan_to_clipboard` with up to 3 candidateIds (Outrider validates them and builds the cards), or `advice_to_clipboard` with `answersSnapshot` = the snapshot's `askedAt`. File route: call `write_advice`. Allowed actions only:
   - `waypoint` {mapID, x, y} with x and y as 0..1 map fractions
   - `track_quest` {questID}
   - `open_panel` {panel: hub | rares | pet | macros | gear | professions | map}
   - `show_item` {itemID}
   Each item: `title` (short), `why` (one sentence), `action`, `args`, `confidence` (verified if it comes straight from Gary's own game data, community if from the private Questie or GearQuest data, inferred if it is your judgment).
   Use only IDs and coordinates that appear in the tool results. Never invent IDs or coordinates (CLAUDE.md hard rule 7).
5. Tell Gary in two or three lines what you suggested. Clipboard route: "click Paste advice in the Advisor tab and press Ctrl+V" (no reload). File route: "/reload, then open the Advisor tab". Mention anything the tool rejected.
