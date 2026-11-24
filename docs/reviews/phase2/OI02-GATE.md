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
- **Goals:** goals can only be created in code or tests for now. The Plan page's step 2 points to Next steps, where WhatNow's goal acts as the implicit goal. A goal editor UI is a candidate for Phase 3 or 4.
- **Unknown values:** the planner treats unknown step time as 900 s against a time budget and adds an uncertainty penalty; that choice is documented in Score.lua and Planner.lua.

### Rollback

Each task is one commit. The planner is off by default; switching it off restores the baseline. Reverting the Phase 2 commits removes the Intelligence files without touching saved data: goals live in `nexusGoals`, the planner settings in `char.modules.Nexus`, and both stay harmlessly unread.

## Independent review (ChatGPT fills)

| Finding ID | Severity | File/symbol and evidence | Requirement | Correction | Regression test | Status |
|---|---|---|---|---|---|---|
| | | | | | | |

Decision: `REVIEW_CHANGES` / `REVIEW_ACCEPTED` (scope stated) / `BLOCKED`.

## Product owner decision (Gary)

- Live slice approved / outstanding:
- Approve Phase 3 / request revisions:
