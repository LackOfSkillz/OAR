# Personal Warcraft Intelligence: task tracker

Tracks `docs/blueprint/OUTRIDER_MICROTASKS.md` (124 tasks, 8 phases). Status words are the blueprint's:
`NOT_STARTED`, `IN_PROGRESS`, `IMPLEMENTED`, `MOCK_GREEN`, `LIVE_PENDING`, `BLOCKED`, `REVIEW_CHANGES`,
`REVIEW_ACCEPTED`, `RELEASE_APPROVED`. MOCK_GREEN means the full automated suite passed at the named SHA;
it is never live or review acceptance.

- Branch: `ai/outrider-personal-intelligence`, created 2026-11-24 from `p1-foundation` at
  `22c76ca4dee229306dc98c82b4543230f4cb4a55` (owner approved in chat, 2026-11-24).
- Phase 1 base SHA: `22c76ca4dee229306dc98c82b4543230f4cb4a55`.
- Owner decision 2026-11-24: tasks that need no live client continue while live-evidence tasks
  (OI01-04) wait; the wait stays visible here and blocks the Phase 1 gate.
- **Owner directive 2026-11-24: [data preservation override](OWNER_DIRECTIVE_DATA_PRESERVATION.md)** overrides every
  data-provenance instruction (OI01-05, OI03-15, OI06-02, OI08-13, sections 4.3 and 4.4). No data is ever deleted, moved or redacted.
- Evidence per task: `docs/reviews/phase1/<taskId>.md`.
- Old IDs (TASKS.md P0-P9, I2-xx, XP60-xx) are cross-referenced, never ticked by this tracker.

## Phase 1: Production stabilization

| Task | Status | SHA | Evidence | Notes |
|---|---|---|---|---|
| OI01-01 Baseline inventory | MOCK_GREEN | 698fa7f | [OI01-01](../reviews/phase1/OI01-01.md) | |
| OI01-02 Rules and policy register | MOCK_GREEN | 442d720 | [OI01-02](../reviews/phase1/OI01-02.md) | 2 owner decisions queued for the gate (D25 hidden channel, XP60 watcher) |
| OI01-03 Branch and reproducible baseline | MOCK_GREEN | dbb5e19 | [OI01-03](../reviews/phase1/OI01-03.md) | 1010 Lua + companion green; no CI until the branch is pushed |
| OI01-04 Runtime and UX baseline | LIVE_PENDING | 167a435 | [OI01-04](../reviews/phase1/OI01-04.md) | capture built and deployed; needs Gary's play session and logout |
| OI01-05 Source and license inventory | MOCK_GREEN | e013761 | [OI01-05](../reviews/phase1/OI01-05.md) | record only (owner directive); nothing removed; ATT licence text added to the zip (additive) |
| OI01-06 Code health toolchain | MOCK_GREEN | bf3fe83 | [OI01-06](../reviews/phase1/OI01-06.md) | quality gate + 90.7% measured Lua line coverage; Luacheck/Ruff wait on Gary's OK to download |
| OI01-07 Technical comments cleanup | MOCK_GREEN | d4bcaa7 | [OI01-07](../reviews/phase1/OI01-07.md) | 120 files comment-only, proven by tools/comment_only.py |
| OI01-08 UI Pages decomposition | MOCK_GREEN | 40ef15b | [OI01-08](../reviews/phase1/OI01-08.md) | 8 files; tab ids/order byte-identical; in-game look pending |
| OI01-09 MacroTree decomposition | MOCK_GREEN | bc0c647 | [OI01-09](../reviews/phase1/OI01-09.md) | model and page split from module; page builder still one big function |
| OI01-10 GearShop decomposition | MOCK_GREEN | 29464cb | [OI01-10](../reviews/phase1/OI01-10.md) | query / rank / view split; buy confirm path unchanged |
| OI01-11 Error and event semantics | MOCK_GREEN | 6336abb | [OI01-11](../reviews/phase1/OI01-11.md) | refused events report unavailable; module-owned timers cancelled on disable |
| OI01-12 Dependency and duplication audit | MOCK_GREEN | ad8b16b | [OI01-12](../reviews/phase1/OI01-12.md) | deps map + gate; 32 pairs, 48 private reads baselined; nothing removed |
| OI01-13 Security checks upgrade | MOCK_GREEN | dc6f373 | [OI01-13](../reviews/phase1/OI01-13.md) | token/AST/secret gate; fixed FishBook chat bypass; PartyQuests auto party lines noted for owner |
| OI01-14 Migration and recovery foundation | MOCK_GREEN | 81d14ac | [OI01-14](../reviews/phase1/OI01-14.md) | Core/Archive: 27 collected-data drops now archive; log caps kept; SV backup taken |
| OI01-15 Release regression baseline | MOCK_GREEN | 8de1ffa | [OI01-15](../reviews/phase1/OI01-15.md) | journeys green in mock; live list for Gary; fishing ring now yields to fishing addons |
| OI01-GATE Phase 1 review gate | REVIEW_ACCEPTED (automated scope) | 24c2e1d | [packet](../reviews/phase1/OI01-GATE.md) | ChatGPT 2026-11-24, CI 45425888539; owner authorized Phase 2; live and release approval pending |

### Phase 1 items still open (do not block Phase 2; must close before the applicable release approval)

1. Live-client performance and regression check (OI01-04 runtime row, OI01-15 list, Path stutter in game).
2. Live data-preservation checks for auctionPosts, radarFeedback, trainingOldFormat, macroPrevBodies.
3. Backup restoration check (`tools/backup-sv.ps1 -Restore`, game closed).
4. Route finder: a destination change during an unfinished search must schedule the replacement. **Fixed after acceptance** (path_spec "a destination change during an unfinished search still finishes the new search"); in the Phase 2 packet for review.
5. Measure synchronous graph initialisation and the real maximum frame time in game.

## Phase 2: Unified intelligence (Nexus)

Owner authorization: Gary forwarded ChatGPT's Phase 1 acceptance (2026-11-24), which is addressed "assuming you're ready to authorize Phase 2". Phase 2 base: the commit after the Phase 1 acceptance.

| Task | Status | SHA | Evidence | Notes |
|---|---|---|---|---|
| OI02-01 Schema reconciliation | MOCK_GREEN | 5e92959 | [OI02-01](../reviews/phase2/OI02-01.md) | v4 spec shared by Lua and Python; 18 golden fixtures agree; v1-v3 unchanged |
| OI02-02 Evidence registry | MOCK_GREEN | 1774bd5 | [OI02-02](../reviews/phase2/OI02-02.md) | provenance, canVerify, refusal reasons, v4 view |
| OI02-03 Class and role profiles | MOCK_GREEN | 8f11a9e | [OI02-03](../reviews/phase2/OI02-03.md) | v4 CharacterState, opaque key, no role inference |
| OI02-04 Character and account state | MOCK_GREEN | f5f5308 | [OI02-04](../reviews/phase2/OI02-04.md) | per-field event invalidation; alts never live |
| OI02-05 Goal model | MOCK_GREEN | 579a16a | [OI02-05](../reviews/phase2/OI02-05.md) | multi-goal, scopes, archive not delete, explained conflicts |
| OI02-06 Candidate adapters: progression | MOCK_GREEN | e95b785 | [OI02-06](../reviews/phase2/OI02-06.md) | deterministic ids, reasons, quest de-dup |
| OI02-07 Candidate adapters: resources | MOCK_GREEN | a2804db | [OI02-07](../reviews/phase2/OI02-07.md) | units and evidence, no scans, independent producers |
| OI02-08 Dependency graph | MOCK_GREEN | 0a60f76 | [OI02-08](../reviews/phase2/OI02-08.md) | cycles, prerequisites, faction, budget, overlap, travel unknown |
| OI02-09 Scoring and trade-offs | MOCK_GREEN | 6b37b3f | [OI02-09](../reviews/phase2/OI02-09.md) | versioned utility, hard constraints, reconstructing trace |
| OI02-10 Bounded sequence planner | MOCK_GREEN | 119b304 | [OI02-10](../reviews/phase2/OI02-10.md) | beam search, work cap, oracle-checked, no fabricated plans |
| OI02-11 Invalidation and execution boundary | MOCK_GREEN | 7261b9c | [OI02-11](../reviews/phase2/OI02-11.md) | off by default; debounce, combat deferral, stale plans, Act only on click |
| OI02-12 Radar and WhatNow integration | MOCK_GREEN | 271469a | [OI02-12](../reviews/phase2/OI02-12.md) | Plan (preview) page; off = baseline; progressive Why |
| OI02-13 Confidence and Troubleshooter core | MOCK_GREEN | see commit | [OI02-13](../reviews/phase2/OI02-13.md) | reason codes; error vs nothing to do; no private details |
| OI02-14 Cross-language contract tests | NOT_STARTED | | | |
| OI02-15 Planner benchmark | NOT_STARTED | | | |
| OI02-GATE Phase 2 review gate | NOT_STARTED | | | stops for ChatGPT review and Gary's approval |

Phases 3-8 (OI03-OI08): NOT_STARTED.
