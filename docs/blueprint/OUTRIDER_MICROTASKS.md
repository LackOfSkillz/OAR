# Outrider - Atomic engineering microtasks

**124 tasks across 8 phases (including 8 review gates).**

Use with `OUTRIDER_ENGINEERING_BLUEPRINT.md`. Default dependency is the immediately preceding task, including the previous phase gate. All start NOT_STARTED; reconcile existing source and retain independent verification requirements. Every task requires the common test, documentation, safety and commit protocol from the blueprint. Acceptance below is additional, not a substitute. An explicit owner/reviewer decision may allow parallel independent work.

## Phase 1 - Production stabilization (16 tasks)

### [ ] OI01-01: Baseline inventory
**Depends on:** None.
**Implementation:** Record HEAD, branch, TOC, build, module ownership, existing I2/XP60 tests, open tasks and status inconsistencies; map existing IDs to this backlog.
**Acceptance:** Exact SHA and CI link recorded; every reused capability has source and status; stale claims corrected without marking live gates complete.

### [ ] OI01-02: Rules and policy register
**Depends on:** OI01-01.
**Implementation:** Reconcile D18/D19, deploy/write permissions, I2-09 block, data and network rules; identify conflicts and owner decisions.
**Acceptance:** Policy table cites repo decisions; offline Advice.lua delivery remains disabled if unresolved; no new external bridge.

### [ ] OI01-03: Branch and reproducible baseline
**Depends on:** OI01-02.
**Implementation:** Create approved development branch; run full test suite, capture clean tree, runtime versions, counts, CI and baseline fixture hashes.
**Acceptance:** Fresh baseline commands pass or failures are listed and blocked; main unchanged.

### [ ] OI01-04: Runtime and UX baseline
**Depends on:** OI01-03.
**Implementation:** Collect owner-approved actual-client CPU/memory/timers/frame count/startup, errors/taint, common workflow clicks and client build.
**Acceptance:** Raw sanitized measurements and repeatable protocol retained; mock numbers not substituted for live evidence.

### [ ] OI01-05: Source and license inventory
**Depends on:** OI01-04.
**Implementation:** Audit each data pack, library, bridge and generated asset for origin, rights, revision, notices and source availability; quarantine unclear extracts.
**Acceptance:** Every redistributed input has a reviewed provenance manifest; no extracted GearQuest database without permission; name conflict recorded for review.

### [ ] OI01-06: Code health toolchain
**Depends on:** OI01-05.
**Implementation:** Introduce pinned Lua 5.1-compatible Luacheck and Python Ruff, type/static checks where useful, coverage and complexity reports; baseline existing violations.
**Acceptance:** Reproducible tools in CI; no new violations outside documented baseline; report actual coverage, no arbitrary fabricated percentages.

### [ ] OI01-07: Technical comments and documentation cleanup
**Depends on:** OI01-06.
**Implementation:** Replace conversational prompt quotes in production source with rationale, links to requirements and version limitations; retain useful probe evidence.
**Acceptance:** Sample and scan changed files; no removed technical facts; tests and diff show comment-only changes where intended.

### [ ] OI01-08: UI Pages decomposition
**Depends on:** OI01-07.
**Implementation:** Split Pages.lua into cohesive page builders using existing Hub/Theme/widgets; preserve public page IDs and navigation.
**Acceptance:** Existing page tests pass; owner-approved comparison confirms same functionality and accessibility; TOC order correct.

### [ ] OI01-09: MacroTree decomposition
**Depends on:** OI01-08.
**Implementation:** Separate macro eligibility, explanation, grid model and rendering without changing protected actions.
**Acceptance:** Golden macro output and drag/disable/combat tests pass; behavior matches baseline; no new secure calls.

### [ ] OI01-10: GearShop decomposition
**Depends on:** OI01-09.
**Implementation:** Separate query, ranking/cart and rendering ownership; preserve existing action confirmation path.
**Acceptance:** Auction query, stale result, click confirmation and close tests pass; no background purchase or scan introduced.

### [ ] OI01-11: Error and event semantics
**Depends on:** OI01-10.
**Implementation:** Fix failed event registration bookkeeping; audit Safe/pcall paths and module timer/event ownership; distinguish degraded capability from success.
**Acceptance:** Mock registration exception returns explicit unavailable; disabling cleans handlers/timers; no retry storm or fabricated capability.

### [ ] OI01-12: Dependency and duplication audit
**Depends on:** OI01-11.
**Implementation:** Map module public APIs, OTR_ events, duplicate scoring/helpers and dead code; remove only verified unreachable code with adapters as needed.
**Acceptance:** Dependency check rejects new cycles/private coupling; fixture outputs unchanged except documented fixes.

### [ ] OI01-13: Security checks upgrade
**Depends on:** OI01-12.
**Implementation:** Augment regex checks with Python AST and Lua token/static checks where feasible; threat cases for unsafe execution, secrets, redirects, paths and protected actions.
**Acceptance:** Negative fixtures catch prohibited behaviors; explicitly document static-analysis limits; no tests weakened to pass.

### [ ] OI01-14: Migration and recovery foundation
**Depends on:** OI01-13.
**Implementation:** Test old/new SavedVariables, bad types, partial data, backups, restoration and feature disable; enforce bounded retention contract.
**Acceptance:** Roundtrip preserves user data and other modules; rollback documented and tested on fixtures; live backup before migration.

### [ ] OI01-15: Release regression baseline
**Depends on:** OI01-14.
**Implementation:** Exercise existing quest, gear, AH, macro, navigation, party, rare, profession, character and advisor flows; build competing-addon matrix.
**Acceptance:** Critical existing journeys pass; real-client blockers listed; prior features remain usable when new flags off.

### [ ] OI01-GATE: Phase 1 review gate
**Depends on:** OI01-15.
**Implementation:** Deliver phase diff, evidence pack, licensing findings, baseline metrics, refactor regression results and unresolved policy questions.
**Acceptance:** Reviewer checks exact SHA; owner approves live baseline and policy items or explicitly keeps blocked features off; no P0/P1 open without safe approved mitigation.

## Phase 2 - Unified intelligence - Nexus (16 tasks)

### [ ] OI02-01: Schema reconciliation
**Depends on:** OI01-GATE.
**Implementation:** Inspect actual I2 and legacy contracts; freeze additive Evidence, Opportunity, CharacterState, Goal, Plan, Outcome and schema versions.
**Acceptance:** Lua/Python schema maps and golden fixtures agree; v1-v4 existing advice/import compatibility preserved.

### [ ] OI02-02: Evidence registry
**Depends on:** OI02-01.
**Implementation:** Extend existing Evidence service for per-kind TTL, revision, source provenance, confidence, validation and local/export privacy.
**Acceptance:** Fixtures reject malformed, stale, cross-character/build/ruleset and secret data; verified status cannot be inferred from source name.

### [ ] OI02-03: Class and role profiles
**Depends on:** OI02-02.
**Implementation:** Complete existing Profiles mapping for all nine classes and documented roles; explicit role override and UNKNOWN fallback.
**Acceptance:** 54 class-goal cases plus hybrid, respec, absent talent and unknown token tests; no unsupported role inference.

### [ ] OI02-04: Character and account state
**Depends on:** OI02-03.
**Implementation:** Build read-only state view over gear, spellbook, location, inventory, gold, professions and alts; distinguish offline snapshot ages.
**Acceptance:** Events invalidate affected fields only; no direct private-module dependency; stale alt state displayed and not treated as current.

### [ ] OI02-05: Goal model
**Depends on:** OI02-04.
**Implementation:** Support level, gold, gear, professions, explore and mix plus multiple prioritized targets, deadlines and reserves.
**Acceptance:** Create/edit/pause/complete/delete persists per scope; conflicting or infeasible goals produce explanation, not silent override.

### [ ] OI02-06: Candidate adapters - progression
**Depends on:** OI02-05.
**Implementation:** Normalize WhatNow, Journey, QuestInfo, Nearby, DungeonGuide, LevelRoutes and Errands into common opportunities.
**Acceptance:** Existing result IDs map deterministically; missing data yields unknown/excluded; no duplicate quests/rewards.

### [ ] OI02-07: Candidate adapters - resources
**Depends on:** OI02-06.
**Implementation:** Normalize GearScore, MoneyGuide, Professions, CraftQueue, DealDesk, Rares, Handoffs and travel providers.
**Acceptance:** Independent adapters disable gracefully; every cost/benefit has unit and evidence; no additional automatic scans.

### [ ] OI02-08: Dependency graph
**Depends on:** OI02-07.
**Implementation:** Build prerequisites, eligibility, objective overlap, travel and mutually exclusive action edges.
**Acceptance:** Cycle, unmet prerequisite, faction mismatch, double-count, missing travel and resource conflicts tested.

### [ ] OI02-09: Scoring and trade-offs
**Depends on:** OI02-08.
**Implementation:** Implement versioned goal-normalized marginal utility with confidence/risk and hard constraints; deterministic tie break.
**Acceptance:** Same input produces same rank; bounds, monotonicity, reserve, low-confidence and cross-unit tests; reason trace reconstructs score.

### [ ] OI02-10: Bounded sequence planner
**Depends on:** OI02-09.
**Implementation:** Add beam or equivalent bounded search, time/work cap, safe partial return and alternatives.
**Acceptance:** Known small graph matches exhaustive oracle; adversarial large graph terminates; infeasible budget yields no-plan, not fabricated sequence.

### [ ] OI02-11: Invalidation and execution boundary
**Depends on:** OI02-10.
**Implementation:** Event debounce, snapshot revisions, active plan pin/pause/skip/resume, safe waypoint/open-panel intents on user click.
**Acceptance:** Combat, stale plan, late event, logout, disable and changed gear tests; no game actions from plan evaluation.

### [ ] OI02-12: Radar and WhatNow integration
**Depends on:** OI02-11.
**Implementation:** Reuse current Radar/WhatNow interface and existing Hub; add primary/secondary plan cards, alternatives and progressive evidence display.
**Acceptance:** Feature flag off gives baseline behavior; no duplicate suggestions; screen reader-friendly labels and no unsolicited combat overlay.

### [ ] OI02-13: Confidence and Troubleshooter core
**Depends on:** OI02-12.
**Implementation:** Expose why, missing prerequisites, stale sources, uncertain estimates and safe remediation; distinguish error from no opportunity.
**Acceptance:** Every rejected plan has reason code; diagnostics do not reveal private details or promise unsupported data.

### [ ] OI02-14: Cross-language contract tests
**Depends on:** OI02-13.
**Implementation:** Golden fixture roundtrips across Lua, Python and legacy transports; fuzz bounds and invalid data.
**Acceptance:** Stable IDs and numerical units preserved; malformed model/peer data cannot create arbitrary actions.

### [ ] OI02-15: Planner benchmark
**Depends on:** OI02-14.
**Implementation:** Compare Nexus against existing WhatNow using curated representative goals, verify work limits and resource use.
**Acceptance:** Report latency/accuracy, test fixtures and differences; live p95 and memory targets verified or explicitly blocked.

### [ ] OI02-GATE: Phase 2 review gate
**Depends on:** OI02-15.
**Implementation:** Deliver all-class deterministic planner, graph/score contracts, UI, regression tests and performance evidence.
**Acceptance:** Reviewer independently traces scenarios and CI; owner validates initial live slice; all nine-class release checks remain tracked.

## Phase 3 - Personal learning - AfterAction (16 tasks)

### [ ] OI03-01: Session recorder reconciliation
**Depends on:** OI02-GATE.
**Implementation:** Extend existing SessionXP, Ledger, LootLog, FightMeter and Alts rather than duplicate history; define session boundaries and interruption states.
**Acceptance:** Logout, reload, disconnect, multi-character and duplicate event fixtures show no double counts or false completed sessions.

### [ ] OI03-02: Outcome event schema
**Depends on:** OI03-01.
**Implementation:** Record bounded observed quest, travel, XP, spend/earn, gear, profession and permitted death/recovery events; bind to plan IDs when known.
**Acceptance:** Events dedup by semantic key; missing/secret fields unknown; wrong-character, late event and unknown attribution tests pass.

### [ ] OI03-03: Activity timing
**Depends on:** OI03-02.
**Implementation:** Classify observable segments (travel, quest, crafting, dungeon, recovery, unclassified) without pretending to know unseen activity.
**Acceptance:** Segments do not overlap or exceed wall time; inactive/unclassified reported; no unsupported combat log or screenshot source.

### [ ] OI03-04: Quest time observations
**Depends on:** OI03-03.
**Implementation:** Capture start/finish and prerequisites when observable; separate multi-session, abandoned, grouped and censored quests.
**Acceptance:** No invented durations; samples stratified by context and build; compare against Journey's 300-second baseline.

### [ ] OI03-05: Travel time observations
**Depends on:** OI03-04.
**Implementation:** Record user-traveled edges, mode, map/build and interruptions; distinguish planned from actual trips.
**Acceptance:** Teleports, disconnects, flight/boat, detour and unknown map fixtures not mixed with walking samples.

### [ ] OI03-06: Economy outcome capture
**Depends on:** OI03-05.
**Implementation:** Separate actual currency flow from estimated loot value; track confirmed transactions, fees/deposits and costs if observable.
**Acceptance:** Disappeared auctions are not sales; no double-counting transfers or estimates as realized profit; unknown fees explicit.

### [ ] OI03-07: Performance and survival observations
**Depends on:** OI03-06.
**Implementation:** Use only readable permitted post-fight meter results and supported death/recovery events; store comparable context.
**Acceptance:** Unknown meter, active combat, different builds and missing result cases safely excluded; never derive restricted combat metrics.

### [ ] OI03-08: Chronicle timeline
**Depends on:** OI03-07.
**Implementation:** Create concise chronological milestones and decisions, with plan/outcome references and privacy controls.
**Acceptance:** Replay and reload preserve order/dedup; user can clear/export selected history; no raw chat or unrestricted event stream.

### [ ] OI03-09: Estimator and calibration
**Depends on:** OI03-08.
**Implementation:** Use robust median/quantile or conservative shrinkage by class/level/activity, minimum sample counts, recency and fallback estimates.
**Acceptance:** Held-out test prevents training leakage; outlier, sparse and patch-change cases widen interval or fall back; report actual calibration error.

### [ ] OI03-10: Preference and feedback model
**Depends on:** OI03-09.
**Implementation:** Record useful/wrong/ignored/completed separately; bounded preference adjustment with reset, opt-out and explicit owner goals dominant.
**Acceptance:** Ignored is not negative performance; no feedback amplification from duplicates; change trace explainable and reversible.

### [ ] OI03-11: AfterAction report
**Depends on:** OI03-10.
**Implementation:** Display observed wall-clock XP/hour, realized gold, activity breakdown, uncertainty, milestones and alternative next-session focus.
**Acceptance:** Report totals reconcile with source; no fake improvement claim; missing/partial sessions labeled; example screenshots clearly demo data.

### [ ] OI03-12: Next-session planner reuse
**Depends on:** OI03-11.
**Implementation:** Integrate existing XP60 offline planner and NextSession with Nexus and calibrated estimates; preserve safe fallback.
**Acceptance:** Fixtures enforce time budget, quest dedup, stale/character/session/build binding; offline delivery still policy-gated.

### [ ] OI03-13: Recovery capability
**Depends on:** OI03-12.
**Implementation:** Resume pinned plan on return; revalidate expired quests, gear, location, time and goals; summarize changes.
**Acceptance:** Old plan cannot blindly reapply; user chooses resume or new plan; long absence and deleted quest fixtures pass.

### [ ] OI03-14: Benchmark and measurement harness
**Depends on:** OI03-13.
**Implementation:** Add repeatable baseline comparisons, paired routes, observed outcomes and held-out estimate metrics; export sanitized evidence.
**Acceptance:** Same fixture yields same report; sample counts, confidence and unmatched comparisons disclosed; no causal claim without matching.

### [ ] OI03-15: Retention and privacy controls
**Depends on:** OI03-14.
**Implementation:** Add opt-in recording, per-character retention caps, reset/export/delete and no-provider offline support.
**Acceptance:** Disabled records no new data; reset/delete removes derived state as documented; bounded persistence and migration tests pass.

### [ ] OI03-GATE: Phase 3 review gate
**Depends on:** OI03-15.
**Implementation:** Deliver observed session report, learning/calibration, XP60 crosswalk and live sample plan.
**Acceptance:** Review checks attribution and statistics; owner logs confirm XP and elapsed time; sparse data cannot produce quantified uplift; unresolved delivery stays off.

## Phase 4 - Intelligent planning - Horizon, GearROI, Foresight (16 tasks)

### [ ] OI04-01: Horizon session inputs
**Depends on:** OI03-GATE.
**Implementation:** Add 15/30/60/120-minute and custom bounded budget, solo/group/either, goals, reserve and stop preferences.
**Acceptance:** Inputs validate; no-group excludes group prerequisites; existing saved preferences migrate; no LLM required.

### [ ] OI04-02: Multi-objective planning
**Depends on:** OI04-01.
**Implementation:** Use Nexus to combine quests, gear, gathering, errands, travel and turn-ins; merge overlapping objectives.
**Acceptance:** Fixture proves shared travel/reward counted once and prerequisites respected; time bounds shown as estimates with buffer.

### [ ] OI04-03: Session ending strategy
**Depends on:** OI04-02.
**Implementation:** Reserve time for hand-ins, repairs, safe rest point and next-session preparation when applicable.
**Acceptance:** Near-deadline replan offers feasible closure, never starts impossible long step; no automatic logout or action.

### [ ] OI04-04: Horizon live adaptation
**Depends on:** OI04-03.
**Implementation:** Replan on meaningful progress or detours, keep pinned plan unless infeasible, offer manual alternate.
**Acceptance:** Late events, pause/resume, new goal, budget exhaustion and combat suppression tested; no thrashing.

### [ ] OI04-05: GearROI baseline
**Depends on:** OI04-04.
**Implementation:** Reuse GearScore, QuestRewards, Nearby, GearShop, loot and role profiles; normalize role-specific improvement and source types.
**Acceptance:** Guaranteed vs probabilistic source distinct; class/spec/level/bind/slot eligibility tested; no universal DPS claim from stat score.

### [ ] OI04-06: Acquisition time and risk
**Depends on:** OI04-05.
**Implementation:** Estimate travel, prerequisites, run durations, drop probability and competing loot only when supported; unknown otherwise.
**Acceptance:** Probability fixtures include zero/unknown, conditional drops, independent-roll assumption and missing group availability; no guaranteed rare-drop time.

### [ ] OI04-07: Replacement horizon
**Depends on:** OI04-06.
**Implementation:** Identify realistic upcoming eligible quest/vendor/crafted/dungeon replacements from verified data and level pace.
**Acceptance:** Future item not treated as owned; uncertain pace/availability yields range or unknown; avoids circular dependencies.

### [ ] OI04-08: Gear acquisition utility
**Depends on:** OI04-07.
**Implementation:** Combine incremental role score, estimated useful life, acquisition cost and opportunity cost; use goal constraints/reserves.
**Acceptance:** Expensive short-lived item can rank below free alternative; negative/unknown evidence and reserved mount gold tested; units explained.

### [ ] OI04-09: Gear comparison UX
**Depends on:** OI04-08.
**Implementation:** Add current vs candidate, cost/time/risk/lifespan, alternatives and evidence detail to existing Gear pages/tooltips.
**Acceptance:** No purchase action except existing user-confirmed flow; user can dismiss/pin; display works with missing price and no provider.

### [ ] OI04-10: Foresight triggers
**Depends on:** OI04-09.
**Implementation:** Add upcoming trainer/quest/mount/material/dungeon needs based on supported prerequisites and user goals; reuse Radar/Handoffs.
**Acceptance:** Trigger fixtures include near-route savings and false positives; unknown facts not alerts; no automatic quest acceptance.

### [ ] OI04-11: Quartermaster early reservations
**Depends on:** OI04-10.
**Implementation:** Add explicit material and gold hold indicators to vendor/gear advice and account-wide inventory; connect full allocator later.
**Acceptance:** Reserved stock cannot be counted twice; no item transfer/sale blocking without clear UI and override; stale alt inventory flagged.

### [ ] OI04-12: Guardian travel advice
**Depends on:** OI04-11.
**Implementation:** Use verified level/hazard facts and historical deaths where available to label risk, offer safer alternatives.
**Acceptance:** No hidden enemy detection or secret-derived calculations; missing risk data labeled; user controls route choice.

### [ ] OI04-13: Pathfinder measured routes
**Depends on:** OI04-12.
**Implementation:** Feed learned edge times into Travel/Journey with source/version and route deviation; do not equate untraveled straight line with valid road.
**Acceptance:** Test disconnected edges, map changes, no history, slow mode, wrong build and fallback; route remains player-directed.

### [ ] OI04-14: Dungeon decision improvements
**Depends on:** OI04-13.
**Implementation:** Rank eligible dungeons by gear, XP, quest prerequisites, reputation, readiness and realistic group constraints.
**Acceptance:** No assumption of guaranteed drops or group availability; existing dungeon quest and readiness UI remains intact.

### [ ] OI04-15: Foresight quiet UX
**Depends on:** OI04-14.
**Implementation:** Set opt-in categories, cooldown, duplicate suppression, importance threshold, quiet mode and post-combat recheck.
**Acceptance:** One primary plus two secondary; no interruptions in combat; dismiss/snooze persists; no irrelevant repeat spam.

### [ ] OI04-GATE: Phase 4 review gate
**Depends on:** OI04-15.
**Implementation:** Deliver cross-goal session, GearROI, Foresight, Guardian and route tests and representative owner scenarios.
**Acceptance:** Reviewer checks costs/eligibility and actual UI; live comparisons report uncertainty and no false savings claims; no new gameplay automation.

## Phase 5 - Predictive intelligence - Oracle, Forge, Quartermaster, Treasurer (18 tasks)

### [ ] OI05-01: Scenario contract
**Depends on:** OI04-GATE.
**Implementation:** Build immutable scenario branch from base snapshot and explicit hypothetical gear, talent, spending, role, zone or profession overrides.
**Acceptance:** Before/after actual state hash unchanged; invalid hypothetical item/role/level rejected; assumptions/version included.

### [ ] OI05-02: Oracle deterministic comparisons
**Depends on:** OI05-01.
**Implementation:** Compare alternatives with Nexus, Horizon, GearROI and budget results; expose delta, trade-off and uncertainty.
**Acceptance:** No fabricated precise gain; missing data compares only known dimensions; stale base requires refresh; works offline.

### [ ] OI05-03: Forge combat data model
**Depends on:** OI05-02.
**Implementation:** Extend TalentSim/Stats/FightPlan/Spellbook model with versioned abilities, resources, attack speed, damage/heal effects and talent modifiers.
**Acceptance:** Use cited or verified facts only; model unknown mechanics explicitly; no double-count current talents or weapon damage.

### [ ] OI05-04: Forge resource and timing
**Depends on:** OI05-03.
**Implementation:** Model energy/mana/rage/combo points where supported, GCD, cooldown, cast time, periodic ticks and resource limits.
**Acceptance:** Synthetic analytical scenarios match expected timing; unsupported mechanics do not silently default; role-specific constraints tested.

### [ ] OI05-05: Forge damage mechanics
**Depends on:** OI05-04.
**Implementation:** Add supported hit/miss, resistances, armor, crit, procs, weapon speeds and relevant encounter conditions incrementally.
**Acceptance:** Each mechanic has fixture and source; missing coefficient invalidates or widens estimate; no claim of full simulator coverage.

### [ ] OI05-06: Forge healing/tank/survival models
**Depends on:** OI05-05.
**Implementation:** Implement separately labeled healing throughput, resource sustainability, mitigation and survivability scenarios where evidence exists.
**Acceptance:** Avoid collapsing HPS, tank survival and DPS into one misleading score; scenario assumptions and unknown enemy damage visible.

### [ ] OI05-07: Forge scenario runner
**Depends on:** OI05-06.
**Implementation:** Run deterministic or seeded bounded simulation outside combat, optional offline Python acceleration using same contracts.
**Acceptance:** Repeatable results with seed/version; bounded work; no game action; unsupported class/build safe partial report.

### [ ] OI05-08: Forge equipment and build comparison
**Depends on:** OI05-07.
**Implementation:** Compare hypothetical talents, weapons, gear, consumables, enchants, pets and role profiles using existing TalentLab/GearScore.
**Acceptance:** Eligibility and ownership separate; cost/respec and model limits visible; no spending points or equipping automatically.

### [ ] OI05-09: Benchmark training-dummy calibration
**Depends on:** OI05-08.
**Implementation:** Use permitted readable post-fight FightMeter snapshots with owner-controlled exercises; match duration/build/buffs/target conditions.
**Acceptance:** Compare like-for-like; exclude missing metrics, active combat and wrong scenario; no overclaim from one test.

### [ ] OI05-10: Macro versioning and rollback
**Depends on:** OI05-09.
**Implementation:** Version generated macro body, rationale and source spellbook; add preview, diff, explicit user approval and rollback via existing rules.
**Acceptance:** 255-character limit, slots, combat lockdown, respec and rank changes tested; no prohibited commands or automatic execution.

### [ ] OI05-11: Macro regression scenarios
**Depends on:** OI05-10.
**Implementation:** Build all-class fixture matrix for Forever observed macro quirks, modifier paths, spell availability and invalid castsequence patterns.
**Acceptance:** Tests check generated text and known restrictions; owner real-client verification separate; no inference that simulated key sequence proves combat results.

### [ ] OI05-12: Quartermaster supply graph
**Depends on:** OI05-11.
**Implementation:** Expand account inventory and CraftQueue to dependency DAG for recipes/materials, intermediate components and alternative sources.
**Acceptance:** Cycle detection, stale alt inventory, bound/realm/faction restrictions, quantity rounding, no double allocation tested.

### [ ] OI05-13: Quartermaster reservations and transfers
**Depends on:** OI05-12.
**Implementation:** Reserve quantities by account goal, recommend user-confirmed transfers, shopping list and crafting sequence.
**Acceptance:** Competing goals resolved by explicit priority/override; stock remains accurate after changes; no automatic mail/craft/buy.

### [ ] OI05-14: Treasurer budget model
**Depends on:** OI05-13.
**Implementation:** Use Ledger, MoneyGuide, Prices and known costs to track mount/training/repair/gear/profession reserves and planned spend.
**Acceptance:** Integer copper, insufficient gold, user override, missing costs, multiple character wallets; no spending advice beyond modeled reserve.

### [ ] OI05-15: Realized economics and sale uncertainty
**Depends on:** OI05-14.
**Implementation:** Track actual sale/fees where supported, compare vendor vs AH vs craft, estimate sale probability only from adequate data.
**Acceptance:** Unsold listings and disappeared auctions not realized sales; deposits/costs and unknown market depth shown; report sample counts.

### [ ] OI05-16: Professions cost optimizer
**Depends on:** OI05-15.
**Implementation:** Rank skill-up and supply paths considering owned stock, market prices, recipe prerequisites and expected skill gains where supported.
**Acceptance:** Missing rates labeled; actual costs and skill-up observations separate; no purchase/craft without manual action.

### [ ] OI05-17: Oracle and Forge UX
**Depends on:** OI05-16.
**Implementation:** Integrate scenario controls, comparisons, model assumptions, export and reset into existing Talent/Gear/Advisor surfaces.
**Acceptance:** No live state mutation; novice summary and advanced detail; failure/unknown displayed clearly; tests cover stale inputs.

### [ ] OI05-GATE: Phase 5 review gate
**Depends on:** OI05-17.
**Implementation:** Deliver scenario engine, supported simulation subset, macro regression, reservations, and economy tests.
**Acceptance:** Reviewer verifies math and test oracle; owner validates macro/dummy workflows; unsupported mechanics explicitly listed; no speculative guaranteed profit.

## Phase 6 - Community intelligence - Cartographer and Fellowship (14 tasks)

### [ ] OI06-01: World observation schema
**Depends on:** OI05-GATE.
**Implementation:** Extend Discovery/POICapture/Trail/Sightings with build, realm/ruleset, layer, method, precision, consent and provenance.
**Acceptance:** Validate IDs, fractional coords, time/build, known map; no player coordinates passed off as exact NPC location.

### [ ] OI06-02: Versioned source registry
**Depends on:** OI06-01.
**Implementation:** Extend Data Registry and pack manifest with license, revision, evidence classification and conflict rules.
**Acceptance:** Mixed Classic/Forever sources labeled; old builds invalidated by rules; missing or unlicensed data quarantined.

### [ ] OI06-03: Conflict resolution
**Depends on:** OI06-02.
**Implementation:** Retain disagreeing observations, cluster by context/precision, prioritize stronger evidence without destructive overwrite.
**Acceptance:** Wrong layer, relocated NPC, spoofed source, uncertain coordinates and outdated pack fixtures; audit trail preserved.

### [ ] OI06-04: Rare forecasting
**Depends on:** OI06-03.
**Implementation:** Improve Forecasts using same-layer confirmed observations, distinguish sightings from respawns and censored intervals.
**Acceptance:** No forecast below minimum sample threshold; unknown layer and patch change handled; probability calibrated only with adequate records.

### [ ] OI06-05: Route/community discovery
**Depends on:** OI06-04.
**Implementation:** Build Explorer and Cartographer views for unseen locations and supported observations, optional personal exploration objectives.
**Acceptance:** Unseen distinct from unavailable; route suggestions use verified evidence and player navigation; no restricted data.

### [ ] OI06-06: Privacy-filtered contribution export
**Depends on:** OI06-05.
**Implementation:** Create manual reviewed export of allowed world observations with preview, no unnecessary character identifiers or private coordinates.
**Acceptance:** Default off; explicit consent; schema/size validation; export does not expose character account, chat, gold or player route history unless separately approved.

### [ ] OI06-07: Import and pack build pipeline
**Depends on:** OI06-06.
**Implementation:** Offline validate contributor records, dedup, provenance review, reproducible build, version manifest, rollback and moderation queue.
**Acceptance:** Malformed/oversized and malicious files rejected without execution; deterministic build; rights review required before publish.

### [ ] OI06-08: Community release gate design
**Depends on:** OI06-07.
**Implementation:** Document optional future external submission, authentication, rate limits, moderation, consent, deletion and policy/legal review; do not deploy service.
**Acceptance:** Offline manual workflow functional; any external server/network work remains blocked pending separate authorization.

### [ ] OI06-09: Fellowship consent and protocol
**Depends on:** OI06-08.
**Implementation:** Extend Comm/PartyQuests/KitShare with versioned minimal group goals, readiness, eligibility and opt-in share fields.
**Acceptance:** Use supported party/guild/raid/whisper only; sender/scope/size/rate validation; unsupported peer/version safe; no data without opt-in.

### [ ] OI06-10: Fellowship group planner
**Depends on:** OI06-09.
**Implementation:** Combine consenting member opportunities, travel, quest prerequisites, gear needs, availability and fairness.
**Acceptance:** Unknown/unshared member not treated as fully ready; avoid repeatedly favoring one member; no private inventory inferred; no auto-invite.

### [ ] OI06-11: Group UX and shared plan
**Depends on:** OI06-10.
**Implementation:** Show group benefit, per-member gaps, shared itinerary and voluntary ready/accept/decline signals; no external chat spam.
**Acceptance:** Consent revoke stops sharing; disconnect/roster change invalidates group state; members retain individual plan autonomy.

### [ ] OI06-12: Mentor plan portability foundation
**Depends on:** OI06-11.
**Implementation:** Define shareable curated plan references with source/version, role/class eligibility, expiration and manual acceptance.
**Acceptance:** Imported plan cannot run code or automatically act; invalid IDs, inappropriate level and older build rejected or marked stale.

### [ ] OI06-13: Guild contribution and handoff tests
**Depends on:** OI06-12.
**Implementation:** Exercise two or more consenting clients with group changes, conflicting rare sightings, repeated messages and bounded rate.
**Acceptance:** Actual owner-led multi-client evidence plus mock adversarial fixtures; no public/global channel or background collector.

### [ ] OI06-GATE: Phase 6 review gate
**Depends on:** OI06-13.
**Implementation:** Deliver native observation packs, conflict and rare tests, group planning, privacy and license review.
**Acceptance:** Reviewer audits untrusted imports/messages and provenance; owner demonstrates consent with second client; external service not enabled by default.

## Phase 7 - Player education and experience - Expedition, Mentor, UX (13 tasks)

### [ ] OI07-01: Experience modes
**Depends on:** OI06-GATE.
**Implementation:** Introduce Beginner/Experienced/Advanced preference using existing Hub/Theme and per-character defaults; progressive disclosure.
**Acceptance:** Same engine and facts across modes; novice avoids overload; advanced exposes evidence; no duplicate navigation or broken settings.

### [ ] OI07-02: Lesson contract
**Depends on:** OI07-01.
**Implementation:** Define versioned lesson IDs, class/role/level/spell prerequisites, objectives, safe practice and verified sources.
**Acceptance:** Unknown spell/build skips rather than invents lesson; no automated input; localization strings separated.

### [ ] OI07-03: Nine-class curriculum
**Depends on:** OI07-02.
**Implementation:** Implement core lessons for Warrior, Paladin, Hunter, Rogue, Priest, Shaman, Mage, Warlock and Druid; role-specific variants.
**Acceptance:** At least fundamentals, survival, utility and group responsibilities for each; lesson eligibility fixtures and source review; no unverified mechanics marketed as facts.

### [ ] OI07-04: Adaptive lesson delivery
**Depends on:** OI07-03.
**Implementation:** Use learned spellbook, explicit skill goals, opt-in preferences and completion feedback to offer relevant lessons.
**Acceptance:** No unsupported inference of skill from hidden data; user can skip/disable/reset; lessons not shown mid-combat.

### [ ] OI07-05: Practice and Benchmark integration
**Depends on:** OI07-04.
**Implementation:** Offer owner-controlled training-dummy exercises, scenario goals and voluntary knowledge checks using permitted post-fight data.
**Acceptance:** Missing meter gives qualitative practice only; no action execution; compare only matched test contexts.

### [ ] OI07-06: Mentor curated progression
**Depends on:** OI07-05.
**Implementation:** Build authoring and manual import/export of goals/routes/lessons via existing safe serialization; add compatibility checks.
**Acceptance:** No executable data; explicit preview/accept; source/license and build recorded; incompatible steps not installed.

### [ ] OI07-07: Troubleshooter expansion
**Depends on:** OI07-06.
**Implementation:** Diagnose missing quest prerequisite, stale route, wrong macro rank, unsupported API, role mismatch, missing pack and disabled module.
**Acceptance:** Actionable reason and safe manual remedy for each; no misleading success on failed registration; privacy-filtered diagnostic export.

### [ ] OI07-08: Confidence UI consistency
**Depends on:** OI07-07.
**Implementation:** Standardize observed/verified/community/inferred/unknown badges, estimate explanations and source details across screens.
**Acceptance:** Text not color-only; no 'verified' without evidence; source timestamp/build visible; accessibility fixtures.

### [ ] OI07-09: Recovery and Chronicle UX
**Depends on:** OI07-08.
**Implementation:** Summarize changed progress after absence and resume or discard plan; chronological highlights and user filters.
**Acceptance:** No false completion after patch or character switch; clear/delete/export controls consistent; no unnecessary notifications.

### [ ] OI07-10: Explorer challenges
**Depends on:** OI07-09.
**Implementation:** Offer voluntary personal discovery/quest milestones from verified eligibility and known visited history; no performance pressure.
**Acceptance:** Unknown visit state not considered completed; no restricted API or invented data; dismiss/reset supported.

### [ ] OI07-11: Navigation and UI quality
**Depends on:** OI07-10.
**Implementation:** Audit common workflows, readability, keyboard navigation, resizing, localization, missing assets and accessibility; reuse UI kit.
**Acceptance:** Relevant common actions reachable within target clicks; no clipped text at supported scales; target textures fit actual client limits.

### [ ] OI07-12: Documentation and help completeness
**Depends on:** OI07-11.
**Implementation:** Update HelpData, user guide, README, feature flags, error guide, lesson sources, privacy and onboarding, remove stale status claims.
**Acceptance:** Every new public feature/settings/error has a documented workflow; no feature claims without matching evidence; independent review checklist complete.

### [ ] OI07-GATE: Phase 7 review gate
**Depends on:** OI07-12.
**Implementation:** Deliver training matrix, UX walkthroughs, documentation and privacy tests.
**Acceptance:** Reviewer samples lessons and diagnostics; owner tests novice/advanced flows and accessibility; all-class live limitations remain explicit.

## Phase 8 - Desktop companion and release (15 tasks)

### [ ] OI08-01: Companion contract inventory
**Depends on:** OI07-GATE.
**Implementation:** Reconcile Advisor/Snapshot, AdviceLoader, server, context, schemas_v3, coach_v3, XP60 CLI and provider code; map reusable components.
**Acceptance:** No second server, model bridge or separate state store; exact existing schema migrations and transport limits documented.

### [ ] OI08-02: Passport snapshot
**Depends on:** OI08-01.
**Implementation:** Build task-specific local snapshot preview with opaque IDs, allowed field selection, age/build, consent and size limits.
**Acceptance:** Sensitive defaults excluded; export/import versioned and validated; stale/wrong-character data cannot be used as current.

### [ ] OI08-03: Offline companion experience
**Depends on:** OI08-02.
**Implementation:** Provide practical Windows UI/CLI for finalized session history, scenario exploration, reports, settings and explicit export; reuse existing reader.
**Acceptance:** No live game capture; missing/corrupted/in-progress saved file safe; no writes to WTF; native addon works when app absent.

### [ ] OI08-04: Manual OTR1 transport UX
**Depends on:** OI08-03.
**Implementation:** Polish player copy/paste Ask/Explain flow with preview, schema check, error messages and expiration.
**Acceptance:** Real-client roundtrip validated; old schema compatibility; malicious/oversized payload rejected; no hidden bridge or reload automation.

### [ ] OI08-05: XP60 offline delivery policy gate
**Depends on:** OI08-04.
**Implementation:** Reconcile existing watcher with deploy-only write rule and D18/D16; validate process-exit race, destination allowlist and atomic data-only Advice.lua if explicitly approved.
**Acceptance:** Without owner policy approval automatic install stays disabled; approved path tested on real Windows, refuses active/unknown client, writes only sanctioned file and data.

### [ ] OI08-06: Provider adapters
**Depends on:** OI08-05.
**Implementation:** Reuse local OpenAI-compatible and existing cloud adapters, consent, Credential Manager, endpoint auth/TLS and budget; no mandatory provider.
**Acceptance:** No network default; user-approved provider test; retries/timeouts/cancellation/circuit breaker; credentials not logged or bundled.

### [ ] OI08-07: AI grounded explanations
**Depends on:** OI08-06.
**Implementation:** Pass only bounded validated evidence and plan/scenario IDs to model; implement strict response schemas, structured errors and deterministic fallback.
**Acceptance:** Unknown IDs, injected instructions, malformed/multiple JSON, stale model output, unsupported prose claims and false warnings tested; critical caveats cannot be truncated.

### [ ] OI08-08: Provider security and privacy
**Depends on:** OI08-07.
**Implementation:** Review SSRF/redirects, TLS, secrets, local endpoint configuration, file path safety, redaction, budget and prompt injection; minimize exported data.
**Acceptance:** Adversarial fixtures and manual review; no arbitrary commands or model-driven file access; cloud spend requires opt-in and enforced limit.

### [ ] OI08-09: Optional voice UX gate
**Depends on:** OI08-08.
**Implementation:** If existing I2 opt-in push-to-talk is approved, add desktop-only question input on last explicit snapshot, show age and text preview.
**Acceptance:** No screen capture, always-listening microphone or real-time bridge; off by default; if unapproved leave blocked with documented alternative.

### [ ] OI08-10: Companion packaging
**Depends on:** OI08-09.
**Implementation:** Create Windows installer/update/uninstall plan, pinned dependencies, offline mode, version checks, settings backup and rollback; no silent startup registration.
**Acceptance:** Clean machine trial; uninstall preserves or deletes chosen data; no automatic network or game write; unsigned package warning documented if applicable.

### [ ] OI08-11: Competitive usefulness evaluation
**Depends on:** OI08-10.
**Implementation:** Run 25 representative questions/actions against existing baseline and relevant competitors using publicly documented capabilities; record current sources and limitations.
**Acceptance:** Blind scoring where feasible; report useful/incorrect/unanswered and latency; no unsupported 'only addon' marketing claim.

### [ ] OI08-12: Universal live beta
**Depends on:** OI08-11.
**Implementation:** Run all nine classes and documented roles, solo/group, locale, addon conflicts, low funds, reload/logout, taint and performance tests on actual build.
**Acceptance:** Owner-collected sanitized logs, build, scenario and outcomes; no mock substitution; all failures tracked; nonavailable role checks block universal claim.

### [ ] OI08-13: Release privacy and license audit
**Depends on:** OI08-12.
**Implementation:** Review distribution manifest, upstream notices, data and asset licenses, naming, private snapshots, credentials and public claims.
**Acceptance:** No unlicensed/rebranded extracts or personal logs in packages; owner confirms name and legal review scope; unresolved license blocks distribution.

### [ ] OI08-14: Release test and rollback
**Depends on:** OI08-13.
**Implementation:** Full CI exact SHA, clean install/update, old data migration, restore, disable flags, no-provider operation and adverse transport cases.
**Acceptance:** Reproducible package hashes, test output and rollback instructions; no P0/P1 defects without approved safe disable; no publish yet.

### [ ] OI08-GATE: Final independent review and owner approval
**Depends on:** OI08-14.
**Implementation:** Deliver full diff, task status matrix, source/test evidence, actual-client metrics, release notes and signoff checklist.
**Acceptance:** Reviewer verifies at exact SHA and records accepted scope; Gary approves merge/publication separately; blocked items clearly excluded from release.

