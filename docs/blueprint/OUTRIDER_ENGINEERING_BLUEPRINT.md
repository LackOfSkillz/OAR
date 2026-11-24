# OUTRIDER | Personal Warcraft Intelligence
## Engineering blueprint and implementation contract

**Revision:** 1.0 | 2026-11-24 | **Owner:** Gary Mix | **Implementation:** Claude Code | **Independent reviewer:** ChatGPT (on request at each review gate)

**Status:** Proposed engineering work, not implemented or approved for release. This is a forward-looking specification, not evidence of completed work or platform approval.

## 1. Mission and non-goals

Transform Outrider from a broad addon suite into an offline-first, character-aware progression intelligence system. Its differentiator is the connection between observations, goals, actionable plans, actual results, and improved future decisions. A player should get useful recommendations without an LLM; optional AI explains and explores validated results rather than inventing them. Support all nine original classes, applicable roles, different experience levels, and account-wide goals. Preserve the player's autonomy and ability to play without coaching.

Do not create a second advisor, a second database, nine isolated branded addons, a gameplay bot, a live external bridge, or an unbounded telemetry platform. Do not rewrite working modules merely to fit new names. The branded names in this specification are capability labels, not mandatory separate tabs or public product names. Do not claim that no competing addon implements a feature without a separate current competitive review. Evaluate differentiation by usefulness and measurable outcomes, not feature count.

### Success measures (proposed targets, not measured baselines)

| Metric | Proposed acceptance target | Measurement |
|---|---|---|
| Recommendation usefulness | >=80% useful or accepted in at least 25 owner-reviewed representative scenarios; report denominator and nonresponses | Compare with existing WhatNow/Radar and blind paired review |
| Route efficiency | >=10% median reduction in avoidable travel on matched, observed route trials where feasible; otherwise disclose insufficient data | Same character/build, similar goals, start/end and time; at least 10 paired trials |
| Calibration | Report median absolute error and interval coverage for quest/travel estimates on held-out sessions; target <=25% median relative error for supported segments | Time-split validation; no leakage; compare against existing 300s estimate |
| Recommendation honesty | Zero actionable invented IDs, secret-derived calculations, unsupported guaranteed outcomes or unlabeled estimates in negative fixtures | Contract tests and independent code review |
| Stability | Zero new attributable Lua errors/taint in agreed live test sessions; all tests pass | CI + owner logs on target build |
| Performance | Preserve existing core idle target <1.5 MB and <0.1 ms/frame average as applicable; I2 Radar incremental <=300 KiB and refresh p95 <=3 ms | Measure separately; full addon footprint and startup also recorded; no false claim that old baseline covers new modules |
| User experience | Default quiet, one primary plus two optional secondary cards; common actions reachable within 2 clicks from relevant page | Task walkthroughs, accessibility checks, no forced overlay |

If sample sizes are insufficient or targets are missed, report actual numbers and hold the relevant release gate. Targets can only change with a documented owner decision; do not tune test fixtures to pass. Time estimates must not be marketed as proven improvement before live matched trials.

## 2. Source baseline and precedence

Repository: https://github.com/LackOfSkillz/OAR ; baseline inspected `main` SHA `272ae1b8aa6db40feee7aaf012fdb78b5d30f6ef`; CI reported success at https://github.com/LackOfSkillz/OAR/actions/runs/45320432631 . TOC reports version 0.4.8 and Interface 16001. This is a source inspection, not a fresh local test run. Recheck HEAD, branch and client build before implementation. The repository is private; keep source and evidence in authorized locations.

Read in full before coding: `CLAUDE.md`, `HANDOFF.md` (if present), `TASKS.md`, `docs/ARCHITECTURE.md`, `docs/CONVENTIONS.md`, `docs/DATA_SCHEMAS.md`, `docs/DECISIONS.md`, `docs/FOREVER_CONSTRAINTS.md`, `docs/PROBE_RESULTS.md`, `docs/intelligence/I2_BASELINE_POLICY_REGISTER.md`, `docs/intelligence/OUTRIDER_INTELLIGENCE_2_0_UNIVERSAL_ENGINEERING_BLUEPRINT.md`, `docs/intelligence/OUTRIDER_INTELLIGENCE_2_0_IMPLEMENTATION_BACKLOG.md`, `docs/intelligence/I2_IMPLEMENTATION_STATUS.md`, `docs/intelligence/AFTERACTION_XP60_ENGINEERING_DESIGN.md`, `docs/intelligence/XP60_USER_GUIDE.md`, `docs/intelligence/THREAT_MODEL.md`, `docs/intelligence/LICENSE_REVIEW.md`, and `COPYRIGHT.md`.

Source files and actual tests outrank historical status notes about whether implementation exists. Current TOC includes Profiles, Evidence, Opportunity, Economy, Radar, DealDesk, SessionXP and NextSession. Older I2/XP60 notes call portions branch-only or unmerged; reconcile on actual HEAD and retain all unresolved real-client and policy gates. I2-09 stays blocked. Do not assume green CI proves live APIs, permissions, distribution rights or end-user usefulness.

Precedence: controlling project rules and explicit owner decisions > confirmed client/API facts > this new blueprint > speculative design. If requirements conflict, document the conflict and stop the affected microtask; continue unrelated safe work. No relaxation of D18 by implication. D19 is limited to separately approved owner-clicked development UI screenshots, not gameplay capture. Resolve the XP60 offline Advice.lua delivery vs the existing deployment-only write rule before enabling automatic delivery; do not broaden allowed writes.

## 3. Reuse map (architectural ownership)

| Capability | Primary existing ownership | Change requested |
|---|---|---|
| Nexus | Intelligence/Profiles, Evidence, Opportunity, Radar; Modules/WhatNow, Journey | Normalize producers and add constrained joint planning; retire duplicate scorers through adapters |
| AfterAction, Chronicle, Benchmark | Intelligence/SessionXP, NextSession; Modules/Ledger, LootLog, FightMeter, Alts, Feedback; Python xp60_* | Broaden observed session evidence and feedback loop, not another session recorder |
| Horizon, Foresight, Guardian, Recovery, Pathfinder | Journey, Travel, Path, Trail, Errands, WhatNow, Radar, Handoffs | Time-budget plans, forecast dependencies, risk-aware user navigation and resumable plans |
| GearROI | GearScore, Nearby, GearShop, QuestRewards, GearSets, LootRolls, Prices | Role-aware acquisition utility and replacement horizon |
| Quartermaster, Treasurer | Alts, Inventory, CraftQueue, Professions, ProfessionHub, SkillUp, TrainShop, MoneyGuide, Ledger, Prices, DealDesk, Economy | Goal reserves, stock reservations, cost and realized returns |
| Forge | TalentLab, TalentStats, TalentSim, FightPlan, ClassFight, HunterFight, MacroEngine, RankCheck, Spellbook, FightMeter | Versioned model, scenario runner, validated macro and build comparisons |
| Oracle | Nexus, Forge, GearROI, Horizon, Quartermaster | Immutable what-if branches; optional model explanations later |
| Cartographer, Explorer | Discovery, POICapture, NPCPack, NodePack, SharedData, Sightings, Forecasts, RareScan, Layers, Travel, Trail, Data/Registry | Auditable native observations, evidence conflict handling, discovery goals |
| Fellowship, Mentor | PartyQuests, Comm, KitShare, GatherShare, LocationShare, Handoffs, DungeonGuide, DungeonQuests, Alts | Opt-in group goal planning and portable curated plans |
| Expedition, Troubleshooter, Confidence | UI/HelpData, HelpPage, Pages, Hub, Core/Probe, Errors, AutoCheck, MacroTree, Radar | Progressive training, actionable diagnostics, evidence detail |
| Passport, desktop companion | Advisor/Snapshot, AdviceLoader, Modules/Advisor; companion store, server, intelligence providers, coach_v3, context, schemas_v3, session_reader | Consent-filtered snapshots, validated responses, offline reporting, provider UX |

Paths under `addon/Outrider/` unless otherwise noted. Names may change after source inventory; each replacement requires a mapping, migration, compatibility tests, and reviewer approval. Prefer documented public functions or OTR_ events, not cross-module private state. Preserve module enable/disable lifecycle and addon-yield behavior.

## 4. Target architecture

```
Permitted game APIs -> Compat + existing feature producers
                           |
                   Evidence registry
                           |
             Character / account / goal state
                           |
              Candidate & dependency graph
                           |
          Nexus constrained deterministic planner
                 /        |        \
         Horizon      GearROI     Foresight
          Oracle       Forge       Fellowship
                 \        |        /
                    Plan / reason trace
                           |
           Existing Hub / Radar / Advisor UI
                           |
                Player decides and acts
                           |
            Observed outcomes -> AfterAction
                           |
               bounded calibrated models
```

Cartographer supplies versioned world facts; Quartermaster/Treasurer supply inventory and budget constraints; Expedition supplies education and diagnostics. Desktop companion reads consented snapshots or finalized saved records only. Optional LLM receives bounded evidence and deterministic result IDs, never owns game actions, new coordinates or calculation truth. Native core must run with no desktop, provider, or network.

### 4.1 Contract definitions (logical, extend existing I2 schemas additively)

Types below are proposed, not assertions about the existing API. Claude must map to actual existing v1/v2/v3/v4 contracts and choose additive version increments after inspecting them. No incompatible duplicate schema. Lua 5.1 tables and Python equivalents; integers for copper and IDs, finite numbers for times/coordinates, UTF-8 strings, bounded arrays. IDs are opaque stable keys, names are display text only. UTC epoch seconds for persisted observations; monotonic game-time deltas only inside a session. Missing data is explicitly unknown, not zero.

| Record | Required fields and semantics |
|---|---|
| Evidence | evidenceId, kind, sourceId, sourceType, observedAt, clientBuild, packRevision, realm/ruleset scope as applicable, confidence enum observed/verified/community/inferred/unknown, expiry or validity rule, value, privacy scope; capture method and sample count where relevant |
| CharacterState | characterKey (local opaque ID for export), classToken, role (explicit/observed/unknown), level, faction, ruleset, known spells/talents, gear, currency, location, capabilities, timestamp, revision; per-field evidence reference and unknown semantics |
| AccountState | snapshot keys, snapshot ages, inventories, professions, reservations, goals; no offline live-state inference |
| Goal | goalId, owner scope, objective type, target value, priority, deadline optional, constraints, user preference, completion rule, status |
| Opportunity | opportunityId, kind, targetRef, goal contributions, eligibility predicates, prerequisites, exclusions, resource costs, duration distribution or unknown, risk, confidence, evidenceIds, revision, expiry; permitted navigation/panel intents only |
| Plan | planId, snapshotRevision, ordered step IDs, dependency edges, budget/time constraints, predicted metric ranges, alternatives, reason codes, invalidation triggers, createdAt, version |
| Outcome | eventId, sessionId, planId/stepId optional, start/end, observed result or unknown, attribution confidence, evidenceIds, dedup key; user feedback kept distinct from observed completion |
| Estimate | modelId/version, estimate type, context bucket, sample count, median and interval if supported, unit, timestamp, fallback source, calibration status |
| WorldObservation | observationId, factType, entity ID, mapID, fractional x/y if applicable, capture method, build/ruleset/layer, time, precision, source/provenance, consent state, conflict status |
| Scenario | scenarioId, base snapshot hash, hypothetical overrides, assumptions, requested metric, model versions; no mutation of actual character |
| ReviewArtifact | taskId, commit SHA, changed files, commands, exit codes, test results, fixture hashes, limitations, policy status, live evidence reference, reviewer status |

Use per-entity source TTL/invalidation (AH snapshot becomes stale after query/market change; spell/gear/talent after corresponding events; static data after build/version change; position after map/route change). Define exact TTLs during Phase 2 with fixtures. Reject cross-character, cross-ruleset, future timestamp and incompatible builds where the record's semantics require it. Never map a secret value to a numeric default used in a decision. Every predicted range needs a reason and provenance. Dedup evidence by stable semantic key and revision, not by display label.

### 4.2 Planner algorithm and invariants

1. Normalize and validate existing module outputs; exclude ineligible candidates and quarantine malformed evidence. Separate unavailable vs unknown vs stale.
2. Build a bounded directed acyclic dependency graph (detect cycles; mark affected candidates invalid). Add travel edges, overlapping objective groups, resource requirements, role/group prerequisites and irreversible costs. Unknown edge cost must not silently become zero.
3. Score feasible actions using goal-weighted normalized marginal benefit minus normalized time, cost and risk, adjusted for evidence quality. Proposed starting expression: `utility = sum(goalWeight * marginalBenefit) - timeWeight * timeCost - goldWeight * goldCost - riskWeight * riskPenalty - uncertaintyWeight * uncertainty`. Persist weight version, explain reason contributions, do not double-count overlapping rewards or subtract the same cost twice. Hard constraints (gold reserve, deadlines, eligibility, consent, combat restriction) dominate any score.
4. Enumerate feasible sequences with bounded beam search or equivalent; initial proposal: max 60 candidates, horizon 8 steps, beam width 16; process in small scheduled slices, stop at configured time/work budget and return best feasible result plus truncation indicator. Benchmark and tune within Phase 2; no exponential search on game thread. Always support zero feasible plans and explain why. Stable tie-break by candidate ID for deterministic fixtures.
5. Compare alternative goals/paths on common units, expose trade-offs rather than arbitrary percent improvements. Only allow estimated aggregate benefits when source evidence supports the arithmetic; use intervals or unknown, not invented precision.
6. Replan on meaningful events (quest completion, inventory/gold change, route deviation, user goal change), with debounce and hysteresis; do not constantly replace the active plan. User can pin, skip, pause, resume, reject or dismiss. No automatic casts, purchases, crafting, transfers, target selection or travel. Navigation intent only on explicit user action using existing safe waypoint API.
7. Attach reason codes, evidence IDs, confidence and alternative to each recommendation. Record outcome once; feed back only appropriately attributable observations. Keep user preference distinct from measured performance.

### 4.3 Storage and performance

Additive migration through Core/DB and schema constant; backup before deploy. Keep data in existing SavedVariables layout; do not write WTF externally. Proposed initial caps to validate: 30 finalized sessions per character, 500 outcome events per character, 100 learned estimate buckets per character, 20 retained plans per character, 1000 recent world observations per account with compaction, 100 active goals/reservations combined per account. Enforce both record count and serialized byte budgets; old evidence becomes aggregates where possible, never silently remove active goals. Expose clear/export/reset controls. Set conservative per-tick work cap and coalesce frequent events; cancel timers and pending work on disable/logout. No permanent idle OnUpdate, no frame per item, load large data packs on demand. Use existing Theme, UI widgets and secure pools. Profile before/after each phase, report worst-case and p95 on actual client. Caps are engineering defaults for owner/reviewer confirmation, not observed current limits.

### 4.4 Security, policy, privacy and licensing (non-negotiable)

D18: advice only; no external screen/game-window capture, input emulation, client memory inspection, live bridge, hidden channel, or runtime addon rewrite. No combat-log registration or parsing; no computations from secret values; no protected frame changes in combat. Use existing Compat and Secure mechanisms. No automatic gameplay action, including clicks, buying/selling, crafting, posting, talents, equipping, sending mail or accepting quests. Do not implement anti-cheat evasion. Treat missing APIs as degraded capability, not a reason to circumvent restrictions. Out-of-combat Blizzard meter data only if readable and confirmed allowed. User-provided inputs and peer/model messages are untrusted data, not instructions. Do not execute arbitrary Lua, deserialize code, invoke a shell with model text, accept arbitrary file paths, or allow model-selected commands.

Local-first; opt-in per feature for recording, sharing and cloud. Redact account names, character identifiers, gold, exact location, chat and other unnecessary data by default in exports; explicitly disclose fields and recipients. Existing guild/party/raid/whisper channels only where supported and enabled, size/rate limits and sender validation, no public global network. External community publishing is a separate consent and policy gate; MVP is manually reviewed exports/imports, offline distribution. No network from addon. No cloud calls without approved provider/config/preview, token/spend caps, credentials outside repo, TLS for non-loopback, allowlisted destinations and safe redirect policy. Never log tokens or raw private snapshots. No claims of Blizzard approval.

Data provenance is mandatory: record upstream revision, license, source, modifications and attribution; quarantine data with unclear rights. GearQuest bridge currently describes upstream as All Rights Reserved. Do not import or distribute an extracted/rebranded GearQuest database without verified permission; renaming does not change rights. Preserve existing read-only integration unless a reviewed owner decision changes it. QuestieDB derived packs retain upstream notices, caveats and corresponding source. Independently collected observations must not copy prohibited upstream datasets. Confirm licensing and product naming before public launch; naming conflict from prior competitive assessment is unverified for this blueprint and needs independent validation.

## 5. Implementation order and review gates

Implement in the eight phases below in this exact dependency order. The companion safety foundations already in the repository stay in place throughout; Phase 8 is productization, not first implementation of AI. Phase 4 delivers GearROI/Foresight/Horizon as the first major visible differentiation after Nexus and learning. Phase 5 adds Oracle/Forge plus deeper resource planning. Phase 6 builds the community layer. No phase may be called release-ready on mocks alone. Parallelize independent microtasks within an approved phase only after shared contracts are frozen; avoid simultaneous edits to common files.

| Phase | Goal | Entry dependency | Exit evidence |
|---|---|---|---|
| 1 | Production stabilization | Baseline captured | Clean incremental test/CI, policy/data inventory, live baseline, migrations and UI readiness |
| 2 | Unified intelligence / Nexus | Phase 1 accepted | Deterministic all-class bounded planner, common contracts, safe UI, comparison fixtures |
| 3 | Personal learning / AfterAction | Phase 2 accepted | Session outcomes, calibration, privacy controls, XP60 reconciliation, observed vs estimated reporting |
| 4 | Horizon, GearROI, Foresight | Phase 3 accepted | Time-budget and multi-goal plan, verified costs, proactive triggers and user controls |
| 5 | Oracle, Forge, Quartermaster, Treasurer | Phase 4 accepted | Reproducible scenario comparisons, simulation limits, reservations and economics |
| 6 | Cartographer, Fellowship | Phase 5 accepted | Auditable facts, conflict handling, consented group planning and secure import/export |
| 7 | Expedition, Mentor, UX | Phase 6 accepted | Nine-class education, troubleshooting, accessibility, no overload |
| 8 | Desktop companion + release | Phase 7 accepted | Safe transport and provider tests, real Windows trial, all-class beta, reviewer and owner signoff |

See `OUTRIDER_MICROTASKS.md` for individually testable work; `outrider_backlog.json` is its machine-readable mirror. Phase gates are explicit tasks. Every task has a default dependency on the preceding task in its phase unless explicitly approved to run in parallel. Every phase's first task depends on previous phase gate. A gate may be blocked on owner evidence; no silent skipping. Reviewer may approve limited mock-only continuation for unrelated development with blocked gates still visible; never equate that with release signoff.

## 6. Quality, verification and handoff

### Task protocol for Claude

1. Read rules and current status. Create a new owner-approved development branch, suggested `ai/outrider-personal-intelligence`; do not commit directly to main. Capture exact baseline SHA and clean working tree. Do not overwrite unrelated local changes. Update a new roadmap task tracker and cross-reference existing TASKS/I2 IDs; do not mark old incomplete items done automatically.
2. Select one task with satisfied prerequisites. State acceptance criteria, affected contracts and existing ownership in the task note. Add failing behavior/negative tests first where feasible. Implement minimal change; reuse existing services. Keep code comments technical; avoid conversational owner quotes. Maintain public APIs or explicit deprecation adapters. No broad unrelated refactors.
3. Run focused tests, then full `powershell -NoProfile -ExecutionPolicy Bypass -File tools/test.ps1 -RequirePython` from repo root on Windows. Use actual repo-supported invocation for non-Windows if available; record platform and runtime. Run new lint/analysis checks as introduced. Never alter mocks to hide production defects. Test mock API shape against approved probe evidence. Do not use SkipTests. Do not deploy or publish without owner authorization. Use existing deploy procedure when approved; full restart if TOC/files change.
4. Record test commands, exit status, counts, CI link, diff summary, limitations and data/policy consequences in `docs/reviews/<phase>/<taskId>.md` or phase-indexed equivalent. Document every feature/module, public interface, event, data schema, user workflow, error/degraded state, configuration, privacy, test and performance behavior. Update user guide, HelpData, changelog, data schema and decisions when relevant. Commit one logical task, with ID in message. If blocked, record why, exact evidence needed and next safe action. Never fabricate live logs, test outcomes or screenshots.
5. At phase gate, stop and prepare independent review package. Owner returns the branch/SHA and package to ChatGPT; no automatic/background verification is implied. ChatGPT will inspect actual changed code and CI, compare against these criteria and request corrections before recommending acceptance. Gary owns live gameplay checks, policy choices, merge/release approval.

### Required status vocabulary

`NOT_STARTED`, `IN_PROGRESS`, `IMPLEMENTED`, `MOCK_GREEN`, `LIVE_PENDING`, `BLOCKED`, `REVIEW_CHANGES`, `REVIEW_ACCEPTED`, `RELEASE_APPROVED`. IMPLEMENTED means source exists; MOCK_GREEN means full automated suite passed at exact SHA; LIVE_PENDING means mandatory real-client evidence missing. Review acceptance must state scope (mock or live). RELEASE_APPROVED requires all necessary live evidence and owner authorization. No single percentage substitutes for status.

### Independent review and test matrix

Review exact commit and diff from phase base; verify tests exercise behavior, not just function existence; independently reproduce commands when repository/runtime available; inspect CI head SHA, workflow and exit status. Trace input -> validation -> calculation -> UI -> player intent -> outcome, inspect stale/unknown/secret, wrong-character, disabled-module, nil API, bad data, oversized input, expired/corrupted SavedVariables, migration/reload/logout, duplicate/late events, locale, combat transitions, competing addons and rejected provider responses. Nine class matrix: Warrior tank/melee; Paladin tank/melee/healer; Hunter ranged/pet; Rogue melee; Priest caster/healer; Shaman melee/caster/healer; Mage caster; Warlock caster/pet; Druid melee/tank/caster/healer. Six goals per class (level, gold, gear, professions, explore, mix), 54 baseline automated scenarios plus role variants and UNKNOWN fallback. Also test solo/party, 15/30/60/120 min, low funds, insufficient data, old/new builds, different locales, novice/advanced, no provider and unavailable optional data packs. Owner validates actual Forever client on all classes/roles before universal release claim; collect build, dates, steps and sanitized logs; no requests for mid-combat typing or automation. Live test samples and any consented dev UI screenshots are manual and authorized.

### Failure handling and rollback

On regression, disable new feature flag, revert targeted commit or restore approved backup while game closed. Migrations need forward compatibility and tested downgrade/export recovery; never destroy prior user data to make a test pass. A policy/security/privacy violation is release-blocking regardless of feature value. A failed estimate or stale record returns a safe no-plan/unknown result. Report issues by severity: P0 safety/data loss, P1 wrong decisions or broken common flow, P2 degraded UX/performance, P3 cosmetic/docs. No new phase until P0/P1 addressed or explicitly deferred with safe disable and reviewer/owner approval.

## 7. Deliverable checklist

- Source changes and tests in the development branch, phase/task traceability, precise public interfaces and backwards compatibility notes.
- Each phase: review packet, baseline and final SHA, CI, live gate state, performance evidence, screenshots only where approved, limitations and open defects.
- User documentation: install, setup, capability descriptions, all settings, class/role limitations, evidence confidence, privacy, offline operation and troubleshooting.
- Developer documentation: architecture and data flow, each module's responsibilities and public API, events, schemas, migrations, fixtures, feature flags, logs, failure modes, dependencies, source licensing, runbooks, rollback.
- Release candidate: clean-room install and update, signed-off data manifest, versioned release notes, package integrity, opt-in settings, no secrets, no private logs, no unlicensed data, rollback path. No public publish until Gary explicitly approves.
