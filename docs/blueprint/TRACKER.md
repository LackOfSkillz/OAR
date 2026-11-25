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
| OI02-13 Confidence and Troubleshooter core | MOCK_GREEN | af8b571 | [OI02-13](../reviews/phase2/OI02-13.md) | reason codes; error vs nothing to do; no private details |
| OI02-14 Cross-language contract tests | MOCK_GREEN | fc14801 (+ CRLF fixes) | [OI02-14](../reviews/phase2/OI02-14.md) | OTR1 both directions, fuzz, no actions via records |
| OI02-15 Planner benchmark | MOCK_GREEN (live LIVE_PENDING) | 252d775 (+ widened in resubmission) | [OI02-15](../reviews/phase2/OI02-15.md) | 12/12 scenarios plus the real producers; WhatNow 6/12; ~0.1 ms mock; live p95/memory pending |
| OI02-R01..R09 Review corrections | MOCK_GREEN | 6fd4864 (+ benchmark commit) | [packet, Resubmission 1](../reviews/phase2/OI02-GATE.md) | ChatGPT REVIEW_CHANGES on 2f6e376; 9 findings corrected, 20 regression tests |
| OI02-R10..R14 Resubmission 1 findings | MOCK_GREEN | d023478 | [packet, Resubmission 2](../reviews/phase2/OI02-GATE.md) | ChatGPT REVIEW_CHANGES (limited scope) on 420a9a8; 5 findings corrected, 21 regression tests; R14 cycle debt closed by R15 |
| OI02-R15..R17 Resubmission 2 findings | MOCK_GREEN | f25a5ba | [packet, Resubmission 3](../reviews/phase2/OI02-GATE.md) | ChatGPT REVIEW_CHANGES (narrow scope) on d023478; guarded prerequisite walk (old code overflowed the stack), expiry-aware caches, 10 more invalidation events; 19 regression tests |
| OI02-GATE Phase 2 review gate | REVIEW_ACCEPTED (automated scope) | f25a5ba | [packet](../reviews/phase2/OI02-GATE.md) | ChatGPT 2026-11-24, CI 45480417779; all 17 findings accepted; owner forwarded the acceptance (authorizes Phase 3); live and release approval pending |

### Phase 2 items still open (do not block Phase 3; must close before the applicable release approval)

1. In-game p95 frame cost and memory with the planner on.
2. Route finder live performance (carried from Phase 1, item 5).
3. The Phase 1 live data-preservation checks and backup restoration (Phase 1 items 2 and 3).
4. Real client event compatibility: the State.lua events added for R17 (quest, talent, specialization, trait and auction events) fire as expected on Forever.
5. Worst-case cumulative prerequisite traversal cost: DEP_WORK limits each check, not a whole frame. Measure a full re-plan with the real quest pack in game.
6. Dependent steps are reconsidered when their prerequisites expire or become unavailable (live check).

## Phase 3: AfterAction (personal learning)

Owner authorization: Gary forwarded ChatGPT's Phase 2 final acceptance (2026-11-24), which says "Upon owner approval, proceed with Phase 3", in the same way he authorized Phase 2. Phase 3 base: the commit that records this.

ChatGPT's conditions for Phase 3:
- Reuse XP60, session history, evidence, the archive and Nexus; no duplicate history stores.
- Observed outcomes are kept apart from inferred ones, and correlation is never shown as proof that a recommendation caused an outcome.
- Learning is bounded, explainable, reversible and needs enough evidence.
- No fabricated observations, and derived estimates never overwrite original history.
- The data preservation override applies throughout.

| Task | Status | SHA | Evidence | Notes |
|---|---|---|---|---|
| OI03-01 Session recorder reconciliation | MOCK_GREEN (live partly confirmed) | cfea4d3 | [OI03-01](../reviews/phase3/OI03-01.md) | shared PlaySession marker (reload / logout / interrupted); SessionXP and Ledger segments merge; reload no longer a completed session; xp60 clear archives first |
| OI03-02 Outcome event schema | MOCK_GREEN | 89885ea | [OI03-02](../reviews/phase3/OI03-02.md) | v4 OutcomeEvent; opt-in recorder of 12 observed kinds; dedup by meaning, unknown fields named, other character refused, late marked; attribution likely or unknown, never direct |
| OI03-03 Activity timing | MOCK_GREEN | 2057aee | [OI03-03](../reviews/phase3/OI03-03.md) | contiguous observable labels (recovery, dungeon, crafting, travel, quest, inactive, unclassified); add up to wall time; no combat log |
| OI03-04 Quest time observations | MOCK_GREEN | b375fdf | [OI03-04](../reviews/phase3/OI03-04.md) | derived from the existing quest diary (adds session, group, build to new rows); complete / multi / abandoned / open / censored; strata; Journey 300 s comparison only with enough samples |
| OI03-05 Travel time observations | MOCK_GREEN | b9a9515 | [OI03-05](../reviews/phase3/OI03-05.md) | planned trip (estimate) to arrival (actual); modes interrupted / unknown_map / teleport / flight / transport / ground; only clean ground trips are walking samples |
| OI03-06 Economy outcome capture | MOCK_GREEN | 0614edb | [OI03-06](../reviews/phase3/OI03-06.md) | money changes categorized (confirmed sale, transfer, deposit, purchase, vendor...); invoices kept with fee or feeUnknown; disappeared auctions unverified; estimates apart. Also fixed Compat.Call 5-value cap (4 modules) |
| OI03-07 Performance and survival | MOCK_GREEN | 9f75e3f | [OI03-07](../reviews/phase3/OI03-07.md) | FightMeter rows gain context (level, talents, build, group, session) and exclusion reasons; derived DPS strata, build-matched comparison, survival stats |
| OI03-08 Chronicle timeline | MOCK_GREEN | 2c03436 | [OI03-08](../reviews/phase3/OI03-08.md) | milestones and decisions only, keyed (no duplicates on replay or reload), in time order; hide, clear (archived first) and export as text |
| OI03-09 Estimator and calibration | MOCK_GREEN | 2dfaf14 | [OI03-09](../reviews/phase3/OI03-09.md) | median with shrinkage to a prior, p10-p90; current build first (older build widens), recency, MAD outliers widen, sparse falls back with a reason; time-ordered held-out calibration (error, coverage) |
| OI03-10 Preference and feedback model | MOCK_GREEN | ad495ca | [OI03-10](../reviews/phase3/OI03-10.md) | reads existing feedback, one vote per suggestion; ignored and not-now count for nothing; per-kind nudge bounded to 0.05 in the score trace; opt-out, reset (from now) and undo |
| OI03-11 AfterAction report | MOCK_GREEN | e85aec1 | [OI03-11](../reviews/phase3/OI03-11.md) | Home > After action: wall-clock XP/h, realized gold (transfers and estimates apart), time breakdown, milestones, estimates with ranges, own-history numbers (no claims), ideas; partial sessions labelled; example data labelled |
| OI03-12 Next-session planner reuse | MOCK_GREEN | 6e9ef79 | [OI03-12](../reviews/phase3/OI03-12.md) | offline XP60 plan bound to the merged play session; quest dedup across ids; planner-blocked steps removed with reason; personal-estimate note; local ideas fallback; suppression list archived |
| OI03-13 Recovery capability | MOCK_GREEN | 7536103 | [OI03-13](../reviews/phase3/OI03-13.md) | plan summary at logout (old one archived); at the next fresh login what changed is listed (done, gone, worn, place, level, goals, build, long absence); never reapplied, the player resumes or starts anew |
| OI03-14 Benchmark and measurement harness | MOCK_GREEN | bd0096e | [OI03-14](../reviews/phase3/OI03-14.md) | sanitized AfterAction.Evidence (held-out fixed vs personal, paired routes, outcomes, matched-only session comparison); seeded fixture, byte-identical report; Export evidence button |
| OI03-15 Retention and privacy controls | MOCK_GREEN | see commit | [OI03-15](../reviews/phase3/OI03-15.md) | opt-in, nothing recorded when off; per-character caps within bounds (overflow archived); Start fresh archives everything (two clicks); export as data code; works with no provider |
| OI03-GATE Phase 3 review gate | SUBMITTED | see commit | [packet](../reviews/phase3/OI03-GATE.md) | STOPPED for ChatGPT review and Gary's approval; owner asked for a CurseForge upload of this pass before the review |

## Phase 4: Intelligent planning (Horizon, GearROI, Foresight)

Owner authorization: on 2026-11-24 Gary chose "Start Phase 4 now" while the Phase 3 review (OI03-GATE) is still pending with ChatGPT. Phase 3 findings get fixed when they come in. Phase 4 base: 6bd48d5.

| Task | Status | SHA | Evidence | Notes |
|---|---|---|---|---|
| OI04-01 Horizon session inputs | MOCK_GREEN | 43f031a | [OI04-01](../reviews/phase4/OI04-01.md) | 15/30/60/120 min or custom 5..480, solo/group/either, end at a rest point; solo leaves out group steps and what needs them; migrates askMinutes or a changed Radar budget (old values kept) |
| OI04-02 Multi-objective planning | MOCK_GREEN | 891ea57 | [OI04-02](../reviews/phase4/OI04-02.md) | step time = trip + activity; same-map travel shared once; estimate with 20% margin, budget checked on the margin |
| OI04-03 Session ending strategy | MOCK_GREEN | d83ec8f | [OI04-03](../reviews/phase4/OI04-03.md) | time left minus a closing reserve (repair, hand-ins, inn); closing steps only near the end, never a step that can't finish; no automatic logout or action |
| OI04-04 Horizon live adaptation | MOCK_GREEN | 9a99d0f | [OI04-04](../reviews/phase4/OI04-04.md) | automatic re-plans 20 s apart and keep the current first step unless clearly better (10%); your presses re-plan at once; Try another start |
| OI04-05 GearROI baseline | MOCK_GREEN | 23db9e1 | [OI04-05_08](../reviews/phase4/OI04-05_08.md) | guaranteed vs chance sources; eligibility, slot, bind; role score, no DPS claim |
| OI04-06 Acquisition time and risk | MOCK_GREEN | 23db9e1 | [OI04-05_08](../reviews/phase4/OI04-05_08.md) | trip + activity; drops: unknown without a chance, expected tries with stated assumptions, never guaranteed |
| OI04-07 Replacement horizon | MOCK_GREEN | 23db9e1 | [OI04-05_08](../reviews/phase4/OI04-05_08.md) | next same-slot upgrade and hours at your pace; range or unknown; never self or circular |
| OI04-08 Gear acquisition utility | MOCK_GREEN | 23db9e1 | [OI04-05_08](../reviews/phase4/OI04-05_08.md) | upgrade-hours per hour spent; reserve respected; unknowns ranked after known with reasons |
| OI04-09 Gear comparison UX | MOCK_GREEN | 77b3667 | [OI04-09](../reviews/phase4/OI04-09.md) | Gear page "Worth getting?": gain, cost (or price unknown), chance, time, life, alternatives, evidence; keep on top / hide; no buy button |
| OI04-10 Foresight triggers | MOCK_GREEN | 646840f | [OI04-10](../reviews/phase4/OI04-10.md) | trainer (on-route saving), quests at next levels, riding at 40, craft materials, dungeons soon, alts' upgrades; unknown facts withheld; never acts |
| OI04-11 Quartermaster early reservations | MOCK_GREEN | 9ab8ffd | [OI04-11](../reviews/phase4/OI04-11.md) | item and gold holds (explicit, craft queue, goal reserve); each unit counted once, own stock first, stale alts flagged; tooltip line; nothing blocked |
| OI04-12 Guardian travel advice | MOCK_GREEN | a9190b9 | [OI04-12](../reviews/phase4/OI04-12.md) | safe / fair / risky / dangerous from zone level ranges (source named) and your deaths there; unknown without data; safer alternative named; plan never changed |
| OI04-13 Pathfinder measured routes | MOCK_GREEN | 0cf5efe | [OI04-13](../reviews/phase4/OI04-13.md) | Travel:TimeTo corrected by your walking (route, then general, current build only), source named; long unwalked straight legs marked; slow mode; unknown stays unknown |
| OI04-14 Dungeon decision improvements | MOCK_GREEN | see commit | [OI04-14](../reviews/phase4/OI04-14.md) | ranks fitting dungeons by quests to do, possible (not guaranteed) gear and level fit; solo last; group and reputation unknown said so; existing UI intact |

Phases 5-8 (OI05-OI08): NOT_STARTED.
