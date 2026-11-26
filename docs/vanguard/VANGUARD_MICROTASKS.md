# Vanguard dependency-ordered microtask backlog

Each task requires code (where applicable), meaningful behavioral and negative tests, documentation, a commit and an evidence report. Dependencies are deliberately conservative: each task follows the preceding task; phase gates require independent acceptance and owner approval. Phase 7 is separately authorized. A live or data-dependent blocker must remain visible, not be faked. No broad refactor.

## VG00 — Baseline, policy and feasibility

### VG00-01 — Pin baseline and inventory
- Depends on: owner-approved baseline
- Implementation: Record exact approved commit, existing tests, source contracts, data hashes and outstanding release gates.
- Acceptance: Baseline manifest and dependency map; no new implementation before review.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG00-02 — Competitive parity matrix
- Depends on: VG00-01
- Implementation: Inspect advertised features and versions for all sources in spec; plan reproducible tests.
- Acceptance: Per-feature source, verification status, scenario, gap and licensing note; no unsupported exclusivity claims.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG00-03 — Policy and privacy ADR
- Depends on: VG00-02
- Implementation: Reconcile D18, owner override and third-party transient cache policy.
- Acceptance: Threat model and explicit retention/consent matrix; unresolved decisions block relevant work.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG00-04 — Native roster capability probe
- Depends on: VG00-03
- Implementation: Verify roster/class/level/role/subgroup APIs and safe contexts on Forever.
- Acceptance: Real client build matrix or explicit blocked status; unknown fallback tested.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG00-05 — Native inspection capability probe
- Depends on: VG00-04
- Implementation: Verify CanInspect/NotifyInspect/INSPECT_READY, item slots and talent interfaces; no forbidden event registration.
- Acceptance: One non-user inspected with owner present; range, combat, manual Inspect and failure behavior recorded.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG00-06 — Encounter event feasibility
- Depends on: VG00-05
- Implementation: Verify allowed encounter/instance events, IDs, success/failure semantics, available raid content.
- Acceptance: No prohibited events; unavailable outcomes explicitly unknown.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG00-07 — Data and modeling feasibility
- Depends on: VG00-06
- Implementation: Inventory current gear, talents, role weights, Forge gaps, catalog sources and archived run records.
- Acceptance: Nine-class coverage matrix and supported mechanics; no inferred missing mechanics.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG00-08 — Performance baseline
- Depends on: VG00-07
- Implementation: Measure existing addon load, frame timing, memory and timer counts; define reference hardware.
- Acceptance: Reproducible baseline and agreed provisional budgets.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG00-GATE — Independent review gate
- Depends on: VG00-08
- Acceptance: Independent reviewer accepts exact candidate SHA and evidence; owner authorizes next phase. Record outstanding live, policy, data and performance blockers; no false pass.
- Do not advance, merge or release without approval.


## VG01 — Native roster and inspection

### VG01-01 — Feature lifecycle
- Depends on: VG00-GATE
- Implementation: Create preview module using existing module/events/timer conventions.
- Acceptance: Disabled state makes zero scan requests; enable/disable repeatable.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG01-02 — Canonical roster adapter
- Depends on: VG01-01
- Implementation: Normalize party/raid membership, subgroup, identity and role evidence.
- Acceptance: Mixed realms, same names, unreadable GUIDs, offline and churn fixtures.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG01-03 — Observation schema
- Depends on: VG01-02
- Implementation: Implement validated statuses, sources, timestamps, revisions and finite numeric fields.
- Acceptance: Unknown cannot become zero; secret values rejected before computation.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG01-04 — Inspect broker
- Depends on: VG01-03
- Implementation: Build one-in-flight queued request state machine, deadlines and rate/backoff.
- Acceptance: No overlapping requests; timeout/retry limits; cancellation deterministic.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG01-05 — Inspect ownership and conflicts
- Depends on: VG01-04
- Implementation: Respect native Inspect UI and competing inspection, combat and zone transitions.
- Acceptance: No stolen inspection; late result cannot populate wrong member.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG01-06 — Slot metadata normalization
- Depends on: VG01-05
- Implementation: Resolve slot links and item data asynchronously with generation checks.
- Acceptance: Empty vs unavailable distinct; delayed callbacks ignored after cancellation.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG01-07 — Talent and role evidence
- Depends on: VG01-06
- Implementation: Use only verified inspected talent APIs; support user-assigned role with tentative inference.
- Acceptance: No fabricated spec, explicit role takes precedence, all unavailable talent paths usable.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG01-08 — Transient peer cache
- Depends on: VG01-07
- Implementation: Limit current-roster cache, expiration and identity lifetime.
- Acceptance: No identifiable non-consenting peer data in SavedVariables, export or logs; roster leave clears view.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG01-09 — Scan interface
- Depends on: VG01-08
- Implementation: Show roster-only view, scan progress, refresh and cancellation.
- Acceptance: One-user party works with partial data; no request from rendering or combat.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG01-10 — Integration and load tests
- Depends on: VG01-09
- Implementation: Exercise 5/40 roster, delayed item data, 100 cancellations and 200 roster changes.
- Acceptance: Bounded timers/memory/requests, no stale member association, full regression suite.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG01-GATE — Independent review gate
- Depends on: VG01-10
- Acceptance: Independent reviewer accepts exact candidate SHA and evidence; owner authorizes next phase. Record outstanding live, policy, data and performance blockers; no false pass.
- Do not advance, merge or release without approval.


## VG02 — Role modeling and preparation parity

### VG02-01 — Role evidence registry
- Depends on: VG01-GATE
- Implementation: Version role profiles by class, build and role; include hybrid cases.
- Acceptance: All nine classes represented or explicitly unsupported; data sources and missing mechanics tracked.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG02-02 — Gear stat derivation
- Depends on: VG02-01
- Implementation: Reuse item data, enchant parsing and role weights; separate observed/derived values.
- Acceptance: Golden fixtures for gear sets, missing slots, unknown enchants, stat units.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG02-03 — Tank adequacy
- Depends on: VG02-02
- Implementation: Assess verified survivability, mitigation, resistances and supported threat proxies.
- Acceptance: No unsupported armor/avoidance formula; missing inputs widen range.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG02-04 — Healer adequacy
- Depends on: VG02-03
- Implementation: Assess verified mana, regeneration, healing and sustain proxies.
- Acceptance: No invented HPS or mana endurance; model limitation visible.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG02-05 — DPS adequacy
- Depends on: VG02-04
- Implementation: Assess role-specific gear/talent indicators and bounded Forge outputs only when validated.
- Acceptance: No numerical DPS from unsupported rotation/proc mechanics; tests for melee/ranged/caster.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG02-06 — Class utility registry
- Depends on: VG02-05
- Implementation: Model ability availability by level, talents, faction, scope and source.
- Acceptance: Potential distinct from verified; absent only when established; no class-only skill assumption.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG02-07 — Stacking and scope rules
- Depends on: VG02-06
- Implementation: Implement independently verified exclusivity, party/raid scope and provider caps.
- Acceptance: Duplicate/exclusive buffs do not inflate score; unknown rule stays unknown.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG02-08 — Personal prep profiles
- Depends on: VG02-07
- Implementation: Extend existing readiness checks for activity, role, duration and class essentials.
- Acceptance: Food/reagents/ammo/consumables thresholds; carried vs bank separate; no auto-use.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG02-09 — Equipment and access checklist
- Depends on: VG02-08
- Implementation: Integrate enchants, empty slots, repairs, verified access/attunement and manual confirmations.
- Acceptance: Missing vs unknown distinct; custom templates cannot masquerade as verified rules.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG02-10 — Journal and acquisition links
- Depends on: VG02-09
- Implementation: Reuse dungeon journal, quests, maps, loot and favorites; verify source/build status.
- Acceptance: Missing eligible quests and possible upgrades link to existing UI; no copied proprietary data.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG02-GATE — Independent review gate
- Depends on: VG02-10
- Acceptance: Independent reviewer accepts exact candidate SHA and evidence; owner authorizes next phase. Record outstanding live, policy, data and performance blockers; no false pass.
- Do not advance, merge or release without approval.


## VG03 — Encounter assessment, Nexus and interface

### VG03-01 — Versioned encounter catalog
- Depends on: VG02-GATE
- Implementation: Define instance and encounter IDs, sizes, ruleset, difficulty, verified requirements and source refs.
- Acceptance: No assumed Classic mechanics or future unlocks; unknowns shown.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG03-02 — Access dependency graph
- Depends on: VG03-01
- Implementation: Model keys, quests, attunements and prerequisites using existing data.
- Acceptance: AND/OR prerequisites and cycle guards; access unknown != access denied.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG03-03 — Coverage and readiness engine
- Depends on: VG03-02
- Implementation: Implement weighted intervals, known-only index and separate critical gates.
- Acceptance: All-unknown cannot produce confident score; monotonicity, determinism and missing-critical tests.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG03-04 — Boss-specific risk matrix
- Depends on: VG03-03
- Implementation: Apply role and utility requirements per encounter.
- Acceptance: Distinct boss risks, reasons, source/build and evidence coverage; no probability label.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG03-05 — Readiness improvement candidates
- Depends on: VG03-04
- Implementation: Produce bounded gap actions for self and advisory text for peers.
- Acceptance: Criticality, costs, alternatives and prerequisite tests; no actions on peers.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG03-06 — Nexus adapters
- Depends on: VG03-05
- Implementation: Reuse validated opportunity, budget, evidence and Act boundaries.
- Acceptance: Actual producer-to-planner tests; stale/disabled/invalid actions rejected.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG03-07 — GearROI and supply integration
- Depends on: VG03-06
- Implementation: Connect item acquisition, crafting, existing inventory, AH and travel estimates.
- Acceptance: Unknown cost never free; reserve protected; enchant depends on equipment decision.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG03-08 — Overview and boss matrix UI
- Depends on: VG03-07
- Implementation: Integrate overview, roster, evidence, boss tabs and clear unknown/expired states.
- Acceptance: 5/40 layout, accessible color+text, no hidden confidence caveats.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG03-09 — Personal checklist and report
- Depends on: VG03-08
- Implementation: Create reusable templates, actionable checklist and aggregate copy preview.
- Acceptance: User initiated copy, no auto chat, identifying details excluded by default.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG03-10 — Context invalidation
- Depends on: VG03-09
- Implementation: Invalidate on roster/role/profile/catalog/time and relevant goal changes.
- Acceptance: Old assessment unusable immediately; UI cannot keep stale success status.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG03-11 — Standalone acceptance scenario
- Depends on: VG03-10
- Implementation: Exercise full flow with no peer addon, desktop or internet.
- Acceptance: Roster-only and partial native inspection provide useful accurate assessment; fallback documented.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG03-GATE — Independent review gate
- Depends on: VG03-11
- Acceptance: Independent reviewer accepts exact candidate SHA and evidence; owner authorizes next phase. Record outstanding live, policy, data and performance blockers; no false pass.
- Do not advance, merge or release without approval.


## VG04 — Roster optimization and optional sharing

### VG04-01 — Hypothetical roster model
- Depends on: VG03-GATE
- Implementation: Create immutable alternative rosters, bench, role overrides and locked positions.
- Acceptance: Editing hypothetical state never mutates live roster.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG04-02 — Subgroup optimizer
- Depends on: VG04-01
- Implementation: Bounded deterministic search maximizing scoped verified coverage with constraints.
- Acceptance: Small exhaustive reference agreement; 40-player termination; lock rules preserved.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG04-03 — Encounter and alternatives ranking
- Depends on: VG04-02
- Implementation: Compare candidate compositions against boss requirements and explain marginal changes.
- Acceptance: No candidate falsely guarantees clear; infeasible case explained.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG04-04 — Assignment notes
- Depends on: VG04-03
- Implementation: Support reusable boss-specific manual role/utility assignments and copyable summary.
- Acceptance: No invitations, marks, group changes or automated messaging; preview only.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG04-05 — Fellowship protocol extension
- Depends on: VG04-04
- Implementation: Add versioned opt-in preparation payload with field preview, scope, sender validation and limits.
- Acceptance: Old clients compatible; malformed packets rejected; nonusers retain native-only assessment.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG04-06 — Consent and expiry
- Depends on: VG04-05
- Implementation: Handle immediate revoke, leave, stale message replay and opt-out.
- Acceptance: Validated revoke bypasses ordinary update rate limit; late packet cannot revive data.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG04-07 — Mixed-source reconciliation
- Depends on: VG04-06
- Implementation: Merge native evidence, optional peer report and manual confirmation without silent overwrite.
- Acceptance: Conflicts surfaced; timestamps and source retained; no inferred consent.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG04-08 — Mixed installation live tests
- Depends on: VG04-07
- Implementation: Test one-to-many and two-peer sharing, raid roster, duplicates and manual Inspect.
- Acceptance: Actual evidence packet or outstanding live blocker explicitly recorded.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG04-GATE — Independent review gate
- Depends on: VG04-08
- Acceptance: Independent reviewer accepts exact candidate SHA and evidence; owner authorizes next phase. Record outstanding live, policy, data and performance blockers; no false pass.
- Do not advance, merge or release without approval.


## VG05 — Historical learning and forecasting

### VG05-01 — Run and attempt contract
- Depends on: VG04-GATE
- Implementation: Define run identity, target outcomes, censoring, build/difficulty and aggregate features.
- Acceptance: No member identity persisted without consent; unknown/abandon not counted as confirmed wipe.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG05-02 — Outcome adapter
- Depends on: VG05-01
- Implementation: Reuse PlaySession, DungeonJournal, Alts, Outcomes and permitted encounter events.
- Acceptance: Reload/rejoin/duplicate event and roster-change tests; no combat log.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG05-03 — Immutable history and recovery
- Depends on: VG05-02
- Implementation: Persist anonymized run observations using existing archive; fail-safe migration/staging.
- Acceptance: Failure injection, content manifest, backup and restoration; zero unauthorized loss.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG05-04 — Historical query and report
- Depends on: VG05-03
- Implementation: Query active and archived history scoped to cohort/session; bounded indexing.
- Acceptance: Older runs remain discoverable; no silent wrong-session cap; no frame-blocking scan.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG05-05 — AfterAction feedback
- Depends on: VG05-04
- Implementation: Link pre-run assessment revision with outcome; report observed vs inferred.
- Acceptance: Outcome cannot mutate original prediction; no causal claims from correlation.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG05-06 — Descriptive historical rates
- Depends on: VG05-05
- Implementation: Implement eligible denominator, censor counts, Wilson intervals and time quantiles.
- Acceptance: Sparse/unknown cases show uncertainty or abstain; hand-calculated fixtures.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG05-07 — Forecast validation plan
- Depends on: VG05-06
- Implementation: Pre-register outcome targets, features, minimum cohort, split and metrics.
- Acceptance: Leakage-free chronological/run grouped protocol; independent sign-off before fitting.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG05-08 — Forecast gate and model contract
- Depends on: VG05-07
- Implementation: Build versioned interface and default abstention; optional model only with eligible evidence.
- Acceptance: Synthetic training cannot authorize displayed probabilities; unsupported build/coverage abstains.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG05-09 — Calibration evaluation
- Depends on: VG05-08
- Implementation: If real adequate data available, compare model to prevalence and simple baseline; report intervals and drift.
- Acceptance: Held-out metrics and coverage documented; otherwise mark blocked, not failed/complete model.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG05-10 — Forecast UI and feedback
- Depends on: VG05-09
- Implementation: Present target/horizon, confidence interval, coverage, evidence and abstain reasons.
- Acceptance: No readiness percentage presented as win odds; full-clear distinct from individual boss forecast.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG05-GATE — Independent review gate
- Depends on: VG05-10
- Acceptance: Independent reviewer accepts exact candidate SHA and evidence; owner authorizes next phase. Record outstanding live, policy, data and performance blockers; no false pass.
- Do not advance, merge or release without approval.


## VG06 — Verification and release

### VG06-01 — Security and privacy audit
- Depends on: VG05-GATE
- Implementation: Review event registrations, native scan, peer messages, storage, export, diagnostics and advice actions.
- Acceptance: No restricted APIs, no secret computation, no identifiable nonconsenting peer persistence.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG06-02 — Data preservation audit
- Depends on: VG06-01
- Implementation: Compare full contents of original project data packs and saved migrations; inspect archive integration.
- Acceptance: Zero unauthorized loss; unverifiable data blocks applicable gate; legitimate corrections versioned.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG06-03 — Performance and lifecycle
- Depends on: VG06-02
- Implementation: Run synthetic and real-client timing/memory/taint tests and inspect conflicts.
- Acceptance: Meet agreed measured budgets or explicit unresolved blocker; no timer/frame leaks.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG06-04 — Class, locale and accessibility
- Depends on: VG06-03
- Implementation: Verify all supported roles, localization, resolution, keyboard focus and UI labels.
- Acceptance: Matrix with actual verified cases and unsupported feature states.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG06-05 — Competitive scenario benchmark
- Depends on: VG06-04
- Implementation: Run same permitted tasks against named competitor versions where accessible.
- Acceptance: Evidence of accuracy/coverage/usability; untested competitors marked unknown.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG06-06 — Release regression and docs
- Depends on: VG06-05
- Implementation: Run clean full suite and exact-SHA CI; document settings, limits, data handling, fallback and release notes.
- Acceptance: No new regression/security findings; no skipped claims; no premature superiority claim.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG06-07 — Live acceptance and rollout
- Depends on: VG06-06
- Implementation: Complete L01-L14 as applicable, separate future raid and model gates; confirm owner authorization.
- Acceptance: Preview for unverified capability; release gate explicitly accepted; no unauthorized publication.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG06-GATE — Independent review gate
- Depends on: VG06-07
- Acceptance: Independent reviewer accepts exact candidate SHA and evidence; owner authorizes next phase. Record outstanding live, policy, data and performance blockers; no false pass.
- Do not advance, merge or release without approval.


## VG07 — Optional Command Center extensions

### VG07-01 — Desktop authorization and reuse assessment
- Depends on: VG06-GATE
- Implementation: Require separate owner approval and compatible OCC architecture; map existing companion.
- Acceptance: No code before approval; local-first, addon independent.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG07-02 — Privacy-filtered import/export
- Depends on: VG07-01
- Implementation: Define versioned aggregate run and approved profile contracts; player-approved exchange after game closes.
- Acceptance: Cross-language fixtures, consent filtering, no live bridge.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG07-03 — Knowledge Vault integration
- Depends on: VG07-02
- Implementation: Store immutable anonymized group history and indexes in existing vault.
- Acceptance: Idempotent import, scoped queries, backup/restore; no source deletion.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG07-04 — Advanced roster and scenario analysis
- Depends on: VG07-03
- Implementation: Extend Oracle/Forge for hypothetical group simulations with verified mechanics.
- Acceptance: Uncertainty and model limits; no direct gameplay controls.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG07-05 — Forecast offline pipeline
- Depends on: VG07-04
- Implementation: Implement only approved training workflow on representative consent-compatible records.
- Acceptance: Reproducible dataset hashes, chronological evaluation, calibrated model version and abstention.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG07-06 — Guild preparation and reports
- Depends on: VG07-05
- Implementation: Optional aggregate shared objectives and manual export; no public player rankings.
- Acceptance: Explicit consent and scope; no uploads or integrations without separate permission.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG07-07 — Desktop integration verification
- Depends on: VG07-06
- Implementation: Clean install, export/import, malformed files, offline behavior and regression.
- Acceptance: Core addon remains independent; release authorized separately.
- Evidence: commit SHA, tests and negative cases, docs, data-preservation impact, applicable live status.

### VG07-GATE — Independent review gate
- Depends on: VG07-07
- Acceptance: Independent reviewer accepts exact candidate SHA and evidence; owner authorizes next phase. Record outstanding live, policy, data and performance blockers; no false pass.
- Do not advance, merge or release without approval.
