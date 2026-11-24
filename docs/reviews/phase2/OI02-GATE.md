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

ChatGPT's review of resubmission 1 (candidate `420a9a8`): REVIEW_CHANGES, limited scope. Findings OI02-R10 to R14 below.

## Resubmission 2 (after ChatGPT REVIEW_CHANGES, limited scope, on 420a9a8)

- **Reviewed SHA:** `420a9a8`.
- **Candidate SHA:** the commit that adds this section. Take it from `git log -1`; the CI link is in the tracker row.
- **Scope:** targeted integration fixes only. The planner design is unchanged. No other refactoring. Phase 3 not started; nothing merged into main; nothing published.
- **Regression tests:** `tests/spec/nexus_review2_spec.lua`, 21 tests. Run against the resubmission-1 addon code (addon and contract stashed), all 21 fail; with the fixes, all pass. Three existing tests were updated to the new behaviour (named in the table).

| Finding | Correction | Files | Regression test |
|---|---|---|---|
| OI02-R10 WhatNow and Radar bypass Act | **Picks:** a plan pick no longer carries the producer's callbacks. Its `go` is a closure over `NexusCore:Act(id)`, and producer alternatives (`alt`) are dropped. What now?, Home's Go button, Radar's Go and the next-step key all call that `go`, so every route runs the full `CheckAct`. A refusal prints the reason. **Shown steps:** picks keep only steps that still pass the display checks (planner on, plan current, in the plan, not skipped, not rejected, not expired, evidence resolves). | NexusCore.lua, WhatNow.lua | R10: no producer callback or alternative on a pick; for combat, skipped, expired, disabled, rejected and stale steps, What now?/Home and Radar never run the producer's go() and Act refuses; the next-step key runs through Act and skips a skipped step |
| OI02-R11 historical facts get fresh times | **Three times per fact:** observedAt (the producer's own time), calculatedAt (now) and expiresAt (the earlier of observedAt plus the kind's maximum age, and calculatedAt plus 180 s). **Times threaded through:** rare sightings (`last.t`), gathering nodes (now minus the age the node log reports), alt inventories (the saved `inv.at`), auction lots (the listing's `observedAt`). **Live producers** (errands, quests, gear, dungeons, dungeon quests, training, gold, route) read the game now, so their facts are observed now. **History with no time** gets `freshness = "unknown"` on the evidence and `freshnessUnknown` on the opportunity (new optional v4 flag), plus an uncertainty charge. It is never claimed as fresh. Saved history is untouched: expiry only decides use. | Evidence.lua, Adapters.lua, WhatNow.lua, Handoffs.lua, Score.lua, Contracts.lua, nexus_v4.lua | R11: the real rares, gather, Handoffs and DealDesk producers keep their own times; history without a time is unknown freshness and scores lower. Updated: review_spec R04 (expiry is now the earlier of the two limits) |
| OI02-R12 goal changes don't invalidate plans | **Context key:** `NexusCore:ContextKey()` is computed from the data each time: state revision, planner switch, every goal (status, priority, objective, reserve, target, deadline), the pin and the skipped steps. A plan made under another key is stale at once: before the debounced re-plan, and even while paused. **Caches:** What now?'s and Radar's caches are keyed by provider plus this key, so switching the planner or changing a goal never serves the old list. **Switch:** `SetOn` drops the current plan and both caches. | NexusCore.lua, WhatNow.lua, Radar.lua, NexusPage.lua | R12: goal added, reserve raised, skip, pin each make the plan stale while paused; switching off drops it; What now? and Radar change provider within the cache time; an expired step leaves the picks before any re-plan. Updated: transport_spec boundary test (its hand-made plan now has a context key), review_spec R05 (a skip now also reads as "changed") |
| OI02-R13 unknown expenditure | **Planning:** an unknown-price step is "check the price first", never a confirmed purchase. The plan result says `financial = "unconfirmed"` and lists those steps; the reason code is `cost_unconfirmed`. **Display:** the pick's caveat and the Plan card both say "price unknown", and that the plan doesn't count it as gold spent. **With a reserve** it stays excluded (resubmission 1). | Planner.lua, NexusCore.lua, NexusPage.lua | R13: no reserve gives unconfirmed with the reason code; a reserve excludes it and the plan is confirmed; pick caveat and card tag |
| OI02-R14 alternative prerequisites | **Data:** `preAny` becomes `requiresAny`, which lists every alternative. **Graph:** a node with requiresAny is valid if any alternative is done or valid, and invalid only when none can be ("needs one of ..."). **Planner:** every plannable alternative is a candidate; a step is addable once any one of them is earlier in the plan or done. This is a targeted change (no general AND/OR graph). Prerequisite cycles through requiresAny are not detected; that is documented as remaining technical debt. | Adapters.lua, Graph.lua, Planner.lua | R14: an unaffordable first alternative doesn't block the quest when the second works; with no possible alternative the reason says so; a real Replan turns the pack's preAny into requiresAny. Updated: review_spec R02 (expects requiresAny) |

**Data preservation:** no data removed or rewritten. The new times are read from records that already exist (sightings, the node log, saved inventories, auction lots), and nothing is written back to them. `DATA_LIFETIME.md` is updated for the three evidence times.

**Still open, unchanged:** the Phase 1 live items (OI01-04 runtime row, OI01-15 in-game checks, the Path stutter re-check, 4 `live_pending` datasets, backup restore verification) and the Phase 2 live p95 frame cost and memory with the planner on.

### Results at the resubmission 2 candidate

Full suite (`tools/test.ps1 -RequirePython`):
- Lua: 1172 passed, 0 failed, 0 syntax errors.
- Python: all suites pass.
- Quality: 22 baselined, 0 new. Candidate selection moved out of `Planner.Plan` into `Planner.Candidates`, so the function stays under the size limit; behaviour is unchanged.
- Deps: 0 new. NexusCore reads no WhatNow internals: the implicit goal comes through NexusGoals, and the switch relies on What now?'s provider-keyed cache.
- Security: 0 violations.
- Benchmark: Nexus still meets 12 of 12 scenarios. The real-producer run gives 4 steps, each with evidence that resolves.

## Independent review (ChatGPT fills)

| Finding ID | Severity | File/symbol and evidence | Requirement | Correction | Regression test | Status |
|---|---|---|---|---|---|---|
| | | | | | | |

Decision: `REVIEW_CHANGES` / `REVIEW_ACCEPTED` (scope stated) / `BLOCKED`.

## Product owner decision (Gary)

- Live slice approved / outstanding:
- Approve Phase 3 / request revisions:
