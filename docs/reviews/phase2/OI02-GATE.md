# Outrider independent phase review packet: Phase 2 (Unified intelligence, Nexus)

## Implementation submission (Claude)

- **Phase / task IDs:** OI02-01 to OI02-15, gate OI02-GATE.
- **Repository and branch:** LackOfSkillz/OAR, `ai/outrider-personal-intelligence` (pushed).
- **Phase base SHA:** `1b94964` (Phase 1 accepted, automated scope; owner authorized Phase 2).
- **Candidate SHA:** the commit that adds this packet. Take the exact SHA from `git log -1` on the branch; CI runs on every push.
- **Diff:** `git diff 1b94964..<candidate>`: about 64 files, +3800 lines, almost all new Intelligence files, specs and docs.
- **Also in this range (not Phase 2 scope, owner-reported bug):** `ed6b5db` "Fix: AH skill-ups know every profession". The auction house Training page now has chips for gathering professions with their supplies, and a plain Herbalism note. A helper agent worked in an isolated worktree; the fix was cherry-picked and re-tested with all gates.
- **Client:** WoW Forever 1.60.1 (TOC 16001). **No live evidence collected in Phase 2.**
- **Feature flag:** the planner module `Nexus` is **off by default**. With it off the only change a player sees is a new Home sub-tab offering the switch; What now?, Radar and the rest of the addon behave as before.

### Architecture (all under `addon/Outrider/Intelligence/`, additive)

```
State.lua (read-only character/account view) ─┐
Goals.lua (multi-goal model)                   ├─> NexusCore.lua (debounce, combat deferral, stale plans,
Adapters.lua (WhatNow producers, LevelRoutes,  │     pin/skip/pause, Act on click, Diagnose)
  DealDesk, Handoffs -> v4 Opportunities)      │        │
Graph.lua (prerequisites, cycles, faction,     │        └─> NexusPage.lua (Home > Plan (preview))
  budget, overlap, travel)                     │
Score.lua (versioned utility + trace)          │
Planner.lua (bounded beam search)  ────────────┘
Contracts.lua (v4 spec shared with Python schemas_v4.py; Evidence.lua and Profiles.lua extended)
```

### Acceptance evidence table

| Task | Acceptance criterion | Files | Tests | Status |
|---|---|---|---|---|
| OI02-01 | Lua/Python schema maps and golden fixtures agree; v1-v3 kept | Contracts.lua, schemas_v4.py, docs/contracts/*, NEXUS_SCHEMA_MAP.md | nexus_contracts_spec (4), test_nexus_v4 (3) | MOCK_GREEN |
| OI02-02 | malformed, stale, cross-char, cross-build and secret data rejected; no verified-by-name | Evidence.lua | nexus_evidence_spec (5) | MOCK_GREEN |
| OI02-03 | 54 class-goal cases plus hybrid, respec, no talents, unknown token; no role inference | Profiles.lua (StateV4) | nexus_profiles_spec (6); intelligence2_spec 9x6 | MOCK_GREEN |
| OI02-04 | events invalidate only their fields; no private coupling; stale alts not current | State.lua | nexus_state_spec (4); deps gate 0 new | MOCK_GREEN |
| OI02-05 | CRUD persists per scope; conflicts explained | Goals.lua | nexus_goals_spec (4) | MOCK_GREEN |
| OI02-06 | deterministic ids; missing data excluded with a reason; no duplicate quests | Adapters.lua | nexus_adapters_spec (5) | MOCK_GREEN |
| OI02-07 | independent adapters; units and evidence; no new scans | Adapters.lua | nexus_resources_spec (4) | MOCK_GREEN |
| OI02-08 | cycle, prerequisite, faction, double-count, travel and resource conflict cases | Graph.lua | nexus_graph_spec (5) | MOCK_GREEN |
| OI02-09 | determinism, bounds, monotonicity, reserve, low confidence, cross-unit, trace | Score.lua | nexus_score_spec (5) | MOCK_GREEN |
| OI02-10 | small graph equals exhaustive oracle; big graph terminates; infeasible gives no plan | Planner.lua | nexus_planner_spec (4) | MOCK_GREEN |
| OI02-11 | combat, stale plan, late event, logout, disable, gear change; no actions from evaluation | NexusCore.lua, State.lua | nexus_core_spec (7) | MOCK_GREEN |
| OI02-12 | flag off keeps the baseline; no duplicates; labelled controls; no combat overlay | NexusPage.lua, Hub.lua, Tips.lua, HelpData.lua | nexus_page_spec (4); tips spec | MOCK_GREEN |
| OI02-13 | every rejection has a reason code; error vs nothing to do; no private details | NexusCore.lua (Diagnose), Planner.lua | nexus_troubleshoot_spec (4) | MOCK_GREEN |
| OI02-14 | Lua to Python round trips; fuzz; malformed data can't act | tools/nexus_fixtures.lua, fixtures, specs | nexus_transport_spec (4), test_nexus_transport (3) | MOCK_GREEN |
| OI02-15 | latency and accuracy report; work limits; live p95 and memory verified or blocked | tools/nexus_bench.lua, tests/lib/nexus_scenarios.lua, docs/quality/nexus_bench.md | nexus_bench_spec (2) | MOCK_GREEN; live **LIVE_PENDING** |

Per-task evidence: `docs/reviews/phase2/OI02-xx.md`.

### Results at the candidate

Full suite (`tools/test.ps1 -RequirePython`):
- Lua: 1130 passed, 0 failed, 0 syntax errors.
- Companion: all Python suites passed, including the 6 new Nexus tests.
- Quality: 22 baselined findings, 0 new.
- Deps: 0 new.
- Security: 0 violations.

### Benchmark summary (mock client, not live)

- **Accuracy:** Nexus met 6 of 6 curated scenarios. WhatNow met 4: it ranks an unaffordable item first and lists one quest twice.
- **Cost:** about 0.1 ms mean per plan, 4-12 work units against a cap of 20000, and about 20-30 KB of garbage per plan.

### Known limits and open items

- **Live:** an in-game session with the planner on, measuring p95 frame cost and memory, plus the Phase 1 live list. Nine-class live validation is still tracked.
- **Travel:** travel time comes only from producers that already estimate it. Otherwise the step is marked `travelUnknown` and costs uncertainty; there is no separate travel planner yet (Phase 4: Pathfinder).
- **Goals:** ~~goals can only be created in code or tests~~. Resolved in the resubmission (OI02-R07): the Plan page now has a "My goals" editor.
- **Unknown values:** the planner treats unknown step time as 900 s against a time budget and adds an uncertainty penalty; that choice is documented in Score.lua and Planner.lua.

### Rollback

Each task is one commit. The planner is off by default; switching it off restores the baseline. Reverting the Phase 2 commits removes the Intelligence files without touching saved data: goals live in `nexusGoals`, the planner settings in `char.modules.Nexus`, and both stay harmlessly unread.

## Resubmission 1 (after ChatGPT REVIEW_CHANGES on 2f6e376)

- **Reviewed SHA:** `2f6e376`.
- **Candidate SHA:** the commit that adds this section. Take it from `git log -1`; the CI link is in the tracker row.
- **Scope:** targeted corrections, no rewrite.
  - Code: commit `6fd4864` (all nine findings with their regression tests), plus the benchmark and scoring commit.
  - Phase 3 not started; nothing merged into main; nothing published.
- **Regression tests:** `tests/spec/nexus_review_spec.lua`, 20 tests, one group per finding.
  - Run against the old planner (Planner.lua stashed alone), 10 of them fail.
  - With the corrections, all pass.

| Finding | Correction | Files | Regression test |
|---|---|---|---|
| OI02-R01 pin bypasses constraints | The pin is now a planner input (`opts.pin`). It must pass every constraint as the first step: valid in the graph, scored, prerequisites done, affordable, within the time budget. Otherwise the plan is made without it, and `result.pin` gives the code `pin_infeasible` (or `pin_gone`) and the reason. Diagnose shows it. The old reorder after planning is removed. | Planner.lua, NexusCore.lua | R01: a low-score pin goes first; an over-budget pin is refused; a pin with an unmet prerequisite is refused and the order is kept; NexusCore and Diagnose |
| OI02-R02 metadata not from production | `NexusAdapters.Meta/MetaAll` build graph metadata from the producers' own candidates. **Built:** map, trip seconds, quest faction, overlap, and unfinished `preAll`/`preAny` prerequisites (opportunity ids when in the pool, else `quest:q<id>` so the graph names what's missing). **Threaded:** the quest pack's faction and prerequisites now ride along NPCPack, Journey and WhatNow. **Unknown:** what no producer reports goes in `meta.unknown` (map, travel, faction, prerequisites, excludes), and Diagnose summarizes it (`metadata_unknown`). **Also fixed:** Journey's XP list never carried the quest id. | Adapters.lua, NexusCore.lua, NPCPack.lua, Journey.lua, WhatNow.lua | R02: Meta from pack fields; a real Replan leaves out the other faction's quest and one with an unmet prerequisite |
| OI02-R03 unknown cost as 0 | New optional v4 flag `costUnknown`; Lua and Python share the spec. **Known zero:** kinds that never spend (quest, dungeon, rare, gather, explore); gear from a drop or quest; producers that say 0 (crafting from bags, selling). **Unknown:** vendor gear, repairs, ammo, training. With a gold reserve, an unknown cost is invalid (`cost_unknown`, with a remedy). Without one, it adds uncertainty. | Adapters.lua, Graph.lua, Score.lua, NexusCore.lua, Contracts.lua, nexus_v4.lua, Journey.lua, WhatNow.lua | R03: cost meaning per kind; a reserve excludes; an unknown cost scores below an equal known-zero step |
| OI02-R04 synthetic evidence ids | Every opportunity cites a real `IntelEvidence` record made from its candidate, registered per producer (`nx_<source>`, sourceType module, cannot verify). `Record` takes the observation time and keeps it, and expiry counts from it. A fact already past expiry is refused, so its opportunity is excluded ("no usable evidence"). The opportunity's `expiresAt` is the evidence's. `Clear(source)` clears one source, so Radar's rebuild no longer wipes the planner's facts. Evidence cap raised from 100 to 500. | Adapters.lua, Evidence.lua, Radar.lua | R04: evidence resolves and converts to v4; an old observation keeps its time; a stale one is excluded; Radar's clear keeps the planner's facts |
| OI02-R05 weak Act boundary | `CheckAct` runs before any action. It requires: planner on; not in combat; plan current; the step in the plan's steps; not skipped; not rejected; opportunity not expired; every evidence id resolves (same character and build, not stale). Only the declared intent runs: waypoint needs the producer's go(), panel needs a page, none does nothing. | NexusCore.lua | R05: combat, skipped, not in plan, stale evidence on a young plan, intent none; go() runs once when all pass |
| OI02-R06 not order-aware | States are keyed by the step set plus the map the sequence ends on; when two states share a key, the better one is kept. Each move to another map costs `MAP_CHANGE` (0.05), counted from where the player is. | Planner.lua | R06: four steps whose ids alternate maps are planned with one map change, starting on the current map |
| OI02-R07 no goal editor | Plan page "My goals": add buttons for the six objectives. Per goal: Higher, Lower, Pause/Resume, Keep 1g more, No reserve, Archive (kept, never deleted). Every button has a tooltip. | NexusPage.lua, Tips.lua | R07: add, reprioritize, reserve, pause, archive; nothing deleted; tooltips present |
| OI02-R08 two recommendation owners | With the planner on, `WhatNow:List` (so What now? and Home) and Radar show `NexusCore:Picks()`, the plan's steps in plan order. The producers are not run twice. Skipping a pick also skips it in the planner. Off, each page keeps its baseline. | NexusCore.lua, WhatNow.lua, Radar.lua | R08: the provider is nexus and the top pick is the plan's first step; off returns to whatnow |
| OI02-R09 negative-value prerequisites dropped | Candidates are the steps scoring above zero plus the prerequisites they need, whatever those score. A step whose prerequisite can't be planned is left out. A plan's value must be above zero, unless the player pinned a step. Skipping no longer counts as done: a step that needs a skipped step is left out, with its reason. | Planner.lua, NexusCore.lua | R09: a negative-score prerequisite is planned before what it unlocks; skipping a prerequisite leaves its dependent out |

**Additional requirements**

- **Wider benchmark** (`tests/lib/nexus_scenarios.lua`, `docs/quality/nexus_bench.md`): 12 scenarios.
  - The six new ones: conflicting goals; insufficient resources (a reserve plus an unknown price); stale observations; unavailable metadata; overlapping objectives across two producers; adverse conditions (two producers failing).
  - It also runs the addon's own producers on the mock client: 4 opportunities, 4 steps, every one citing evidence that resolves, none twice.
  - Nexus met 12 of 12; WhatNow met 6 of 12.
- **Found by the benchmark and fixed:** a step with unknown time scored as cheaper than a known ten-minute step (time cost 0 plus a small uncertainty). Unknown time now counts as `UNKNOWN_SECONDS` (900 s, the planner's figure) in the time cost, and still adds uncertainty (Score.lua).
- **Data lifetime:** `docs/intelligence/DATA_LIFETIME.md` separates permanent collected observations (data preservation directive, archive) from disposable runtime caches (evidence facts, plan, What now? list, Radar cards, route search), with their bounds.
- **Still open, unchanged:** this resubmission closed none of these.
  - Phase 1 live items: the OI01-04 runtime row, the OI01-15 in-game checks, the Path stutter re-check, 4 `live_pending` datasets, and backup restore verification.
  - Phase 2: the live p95 frame cost and memory with the planner on.

### Results at the resubmission candidate

Full suite (`tools/test.ps1 -RequirePython`):
- Lua: 1151 passed, 0 failed, 0 syntax errors.
- Python: all suites pass.
- Quality: 22 baselined, 0 new. One baseline key moved from Journey.lua:442 to :443: the same function, one line lower.
- Deps: 0 new.
- Security: 0 violations.

## Independent review (ChatGPT fills)

| Finding ID | Severity | File/symbol and evidence | Requirement | Correction | Regression test | Status |
|---|---|---|---|---|---|---|
| | | | | | | |

Decision: `REVIEW_CHANGES` / `REVIEW_ACCEPTED` (scope stated) / `BLOCKED`.

## Product owner decision (Gary)

- Live slice approved / outstanding:
- Approve Phase 3 / request revisions:
