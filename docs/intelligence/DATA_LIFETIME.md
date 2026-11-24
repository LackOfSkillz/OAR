# What Outrider keeps, and what it throws away

Written for the Phase 2 review (OI02-GATE resubmission). It separates two
kinds of data that look alike in code but follow opposite rules.

## 1. Collected observations (permanent)

Facts the player's own play produced and Outrider saved in SavedVariables
(`Outrider_DB`, `Outrider_Log`, `Outrider_Snapshots`). Examples: sightings,
price history, the loot and node log, quest diary, fish book, dungeon runs,
the trail, census, XP sessions, gold and sales ledgers.

The owner's data preservation directive
(`docs/blueprint/OWNER_DIRECTIVE_DATA_PRESERVATION.md`) governs them:

- Never deleted, purged, truncated, overwritten, stripped or redacted.
- Anything that leaves the live store is archived first (`Core/Archive.lua`:
  copy, confirm, then remove). The one exception is newer or better data
  replacing outdated data, which the owner allowed (retention option 3).
- Log and debug buffers keep their caps (they are diagnostics, not collected
  data).
- Every dataset, its store, cap and archive path is listed in
  `docs/quality/data_preservation_audit.json` (47 datasets).

The Nexus adds two small saved stores, and both follow the same rules:

| Store | What | Removal |
|---|---|---|
| `ns.db.char.nexusGoals`, `ns.db.global.nexusGoals` | the player's goals (v4 Goal records) | "Archive" sets `status = "archived"`; the record stays |
| `ns.db.char.modules.Nexus` | planner switch, pinned step, skipped steps, paused | settings: the player's own choices |

## 2. Runtime caches (disposable)

Working copies the addon builds from collected data and live game state
while it runs. They live only in memory (never in SavedVariables), are rebuilt
on demand, and are dropped at `/reload`, logout or expiry. Dropping one never
loses an observation: the source it was computed from is still there.

| Cache | Where | Lifetime and bound |
|---|---|---|
| Evidence facts (`IntelEvidence.observations`) | Intelligence/Evidence.lua | expire with their TTL (planner facts 180 s from the time the fact was observed), at most 500, oldest evicted; `Clear(source)` drops one source's facts only (Radar never clears the planner's) |
| Character state fields | Intelligence/State.lua | until an event invalidates that field |
| Current plan, graph, scores, runtime candidates | Intelligence/NexusCore.lua (`current`) | replaced on each re-plan; dropped on disable and logout |
| v4 opportunities | Intelligence/Adapters.lua | rebuilt each re-plan from the producers; expire with their evidence |
| What now? list | Modules/WhatNow.lua (`cache`) | 30 s |
| Radar cards | Intelligence/Radar.lua (`cards`) | 30 s, or when a card expires |
| Route search and graph | Modules/Path.lua | rebuilt when the trail revision or destination changes |

A runtime cache is never written back over collected data, and nothing in a
cache is exported: Evidence facts are marked `privacy = "local"`, and only
sanitized ids, kinds, times and labels reach an explanation (`E:Exportable`).

## 3. How to tell them apart in code

- Saved data is reached through `ns.db.*` and guarded by `ns.KeepTable` /
  `ns.KeepBad`; removing any of it must go through `ns.Archive`.
- Runtime caches are plain module fields (`self.current`, `self.cache`,
  `E.observations`). Expiring or clearing them is expected.
- A new store that holds something the player did or saw is collected data,
  even if it starts as a cache: give it a row in the audit file and an archive
  path before it ships.
