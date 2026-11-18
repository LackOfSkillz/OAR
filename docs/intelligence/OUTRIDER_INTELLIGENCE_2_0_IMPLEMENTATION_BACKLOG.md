# Outrider Intelligence 2.0 — Atomic Engineering Backlog

**Owner:** Gary Mix · **Created:** 2026-11-18 · **Status:** DESIGN ONLY; no I2 tasks are implemented merely because this file exists.

**Read first:** [Universal Engineering Blueprint](OUTRIDER_INTELLIGENCE_2_0_UNIVERSAL_ENGINEERING_BLUEPRINT.md). Compare the current code with previous AI v1 tasks in `docs/OUTRIDER_INTELLIGENCE_TASKS.md`. Do not mark any item done without source, automated tests and where applicable live Forever verification.

**Non-negotiable:** Nine supported classes and every documented role must pass quality gates; default quiet/offline; no external live bridge (D18); no autonomous game input; protected/secret combat values never computed for action selection.

## Progress contract

All tasks begin `[ ]`. Mark `[~]` while coding, `[x]` only when committed with tests, `[!]` when blocked. A phase gate needs recorded CI URL, build SHA, Forever client version, test evidence and owner signoff where specified. Distinguish *coded*, *mock-green*, *live Works*, *Matches*, *Surpasses*. Never convert a task count to "product percent complete."

| Phase | Priority | Atomic tasks | Gate |
|---|---|---:|---|
| I2-00 | P0 | 6 | Explicit tests + evidence |
| I2-01 | P0 | 9 | Explicit tests + evidence |
| I2-02 | P0 | 10 | Explicit tests + evidence |
| I2-03 | P1 | 9 | Explicit tests + evidence |
| I2-04 | P1 | 9 | Explicit tests + evidence |
| I2-05 | P1 | 10 | Explicit tests + evidence |
| I2-06 | P1 | 7 | Explicit tests + evidence |
| I2-07 | P0 release | 6 | Explicit tests + evidence |
| I2-08 | P0 release | 7 | Explicit tests + evidence |
| I2-09 | BLOCKED | 4 | BLOCKED policy/owner review |

**Required order:** I2-00 → I2-01 → I2-02 → parallel I2-03/I2-04 → I2-05 → I2-06 → I2-07 → I2-08. I2-09 stays blocked. Features in I2-03 and I2-04 can be implemented incrementally, but cannot be called universally released until I2-08.

## I2-00: Baseline and policy (P0)

- [ ] **I2-00-01** Recheck branch HEAD, CI and compare with this blueprint; record changed modules.
  - **Done when:** git state and exact CI logs.
- [ ] **I2-00-02** Read controlling CLAUDE.md, D18, privacy, probe, threat model and create conflict register.
  - **Done when:** risk register; prior decisions preserved.
- [ ] **I2-00-03** Inventory all producer candidates / snapshots / IDs and map reuse to old modules.
  - **Done when:** source-to-contract map, no duplicate owner.
- [ ] **I2-00-04** Freeze 9-class and role acceptance matrix including unknown Forever tokens.
  - **Done when:** 54 universal scenarios and hybrid roles declared.
- [ ] **I2-00-05** Document policy posture and forbidden live bridge; feature flags default OFF.
  - **Done when:** security suite rejects prohibited paths.
- [ ] **I2-00-06** Record measured idle CPU/memory and snapshot size on client.
  - **Done when:** baseline trace and version stamped.

- [ ] **I2-00-GATE** Exit criteria demonstrated in automated and live-client evidence where relevant; no unsourced success claims.

## I2-01: Evidence registry and universal profiles (P0)

- [ ] **I2-01-01** Add ClassProfiles registry keyed by readable class token with a separate UNKNOWN profile.
  - **Done when:** 10 profiles (9+UNKNOWN) resolve without error.
- [ ] **I2-01-02** Read talent/role evidence conservatively via Compat; support player override.
  - **Done when:** hybrids and unreadable talent values retain UNKNOWN.
- [ ] **I2-01-03** Build additive normalized Observation v3 records and per-source provider registry.
  - **Done when:** schema validation; bounded plain data, no secret branches.
- [ ] **I2-01-04** Implement Evidence v3 with IDs, timestamp, client build, pack version and confidence.
  - **Done when:** provenance and meaningful freshness demonstrated.
- [ ] **I2-01-05** Create TTL/invalidation policies by source (AH, quest, bags, talent, location).
  - **Done when:** event invalidates only correct facts, no stale actionable cards.
- [ ] **I2-01-06** Implement character/account scoped preference and role state migrations.
  - **Done when:** v1/v2 fixture load, idempotent migration.
- [ ] **I2-01-07** Add sanitization and separate local-only vs exportable evidence.
  - **Done when:** privacy golden tests, zero unapproved fields.
- [ ] **I2-01-08** Implement budgeted task-specific ContextEnvelope v3 on existing OTR1 copy flow.
  - **Done when:** <= 50KiB, fails visibly instead of truncating essential evidence.
- [ ] **I2-01-09** Compat adapter and provider tests against all nine class profiles.
  - **Done when:** 54 universal class×goal test cases pass.

- [ ] **I2-01-GATE** Exit criteria demonstrated in automated and live-client evidence where relevant; no unsourced success claims.

## I2-02: Native Opportunity Radar (P0)

- [ ] **I2-02-01** Wrap WhatNow as first producer preserving old score/actions.
  - **Done when:** old WhatNow regression green.
- [ ] **I2-02-02** Build immutable Opportunity v3 validation and candidate ID registry.
  - **Done when:** malformed/unverified identifiers rejected.
- [ ] **I2-02-03** Create normalized goal-fit, benefit, eligibility, role, freshness and distance scoring.
  - **Done when:** property tests and fixed fixtures.
- [ ] **I2-02-04** Add event coalescer, bounded refresh rate, TTL and duplicate suppression.
  - **Done when:** rapid BAG/QUEST bursts <= 1 recompute every 2s.
- [ ] **I2-02-05** Implement 1 primary + at most 2 secondary Coach cards using existing UI kit.
  - **Done when:** 1+2 enforced, small-window rendering verified.
- [ ] **I2-02-06** Add per-card Why?, dismiss, snooze, useful, wrong and completed.
  - **Done when:** persistent state, source inspectability.
- [ ] **I2-02-07** Stop unsolicited combat notifications, queue safe post-combat reminder.
  - **Done when:** zero combat toasts, no protected actions.
- [ ] **I2-02-08** Add per-category mute, quiet default, HUD enable/minimize/scale.
  - **Done when:** no modal onboarding or chat spam.
- [ ] **I2-02-09** Make Coach open known in-addon panels or user-requested waypoint.
  - **Done when:** only whitelisted nonprotected actions.
- [ ] **I2-02-10** Native offline no-model experience for Warrior, Druid, Hunter at first vertical slice.
  - **Done when:** three classes verified before adding specializations.

- [ ] **I2-02-GATE** Exit criteria demonstrated in automated and live-client evidence where relevant; no unsourced success claims.

## I2-03: All-class and role coaching (P1)

- [ ] **I2-03-01** Define class profile data reference schema/version and unknown ability behavior.
  - **Done when:** no invented talent/spell rank IDs.
- [ ] **I2-03-02** Warrior & Paladin profiles and gear/readiness tests.
  - **Done when:** tank, melee damage, healing where documented.
- [ ] **I2-03-03** Hunter & Rogue profiles and gear/readiness tests.
  - **Done when:** pet utility, ammo, poison, melee/ranged equipment.
- [ ] **I2-03-04** Priest & Shaman profiles and gear/readiness tests.
  - **Done when:** healer, melee/spell damage and mana contexts.
- [ ] **I2-03-05** Mage & Warlock profiles and gear/readiness tests.
  - **Done when:** spell/consumable/demon preparation.
- [ ] **I2-03-06** Druid profiles and role override tests.
  - **Done when:** four roles, hybrid/shape-shift unknown safe.
- [ ] **I2-03-07** Unrecognized Forever class/race/talent probes and graceful fallback.
  - **Done when:** universal quest/economy works, class advice quiet.
- [ ] **I2-03-08** Unify class profile with GearScore/QuestRewards/TrainShop/LevelRoutes.
  - **Done when:** role-appropriate evidence and selected scale.
- [ ] **I2-03-09** End-to-end 9×6 goals + role scenarios, missing data pack cases.
  - **Done when:** all nine same quality bar, no Hunter-only feature gate.

- [ ] **I2-03-GATE** Exit criteria demonstrated in automated and live-client evidence where relevant; no unsourced success claims.

## I2-04: Economy and Deal Desk (P1)

- [ ] **I2-04-01** Define item listing, stack, vendor price and currency contracts.
  - **Done when:** copper int, quantity, binding and age validated.
- [ ] **I2-04-02** Build AH→NPC unit/stack gross-margin calculator.
  - **Done when:** unit vs stack property tests, nonpositive margin rejected.
- [ ] **I2-04-03** Require verified sellability, current listing, sufficient available gold after reserve.
  - **Done when:** unknown/secret/expired facts suppress active candidate.
- [ ] **I2-04-04** Build Deal Desk nonprotected list with evidence, totals, age and visit navigation.
  - **Done when:** no auto-buy; player review always required.
- [ ] **I2-04-05** Integrate existing player-requested AH scan and query throttle.
  - **Done when:** no background full scan or polling when AH closed.
- [ ] **I2-04-06** Store player-approved outcomes separately from disappeared-auction observations.
  - **Done when:** no false sale/profit claims.
- [ ] **I2-04-07** Separate AH→AH and crafting opportunities as hypotheses with known fee/deposit status.
  - **Done when:** unknown liquidity cannot yield precise sale probability.
- [ ] **I2-04-08** Implement option to compare gold/hour and goal fit from observed timing.
  - **Done when:** time/price data provenance shown.
- [ ] **I2-04-09** Test stale, unsellable, bound, 0-price, missing stack, changed lot and insufficient gold.
  - **Done when:** 100% arithmetic + eligibility gates.

- [ ] **I2-04-GATE** Exit criteria demonstrated in automated and live-client evidence where relevant; no unsourced success claims.

## I2-05: Companion and external models (P1)

- [ ] **I2-05-01** Add Python v3 typed context schemas and v1/v2 migration wrappers.
  - **Done when:** old golden codes still decode.
- [ ] **I2-05-02** Create new deterministic evidence and candidate tools without duplicating MCP server.
  - **Done when:** tool scope read-only; source IDs trusted.
- [ ] **I2-05-03** Build model tool selection and structured explanation flow.
  - **Done when:** provider may rank IDs, cannot author commands/data.
- [ ] **I2-05-04** Add response v3 validator in Python; then additive Lua AdviceLoader v3.
  - **Done when:** malicious answer tests; all legacy formats unchanged.
- [ ] **I2-05-05** Reuse existing OpenAI-compatible local adapter and vLLM/LAN config.
  - **Done when:** no hardcoded home IP; TLS/auth on LAN per policy.
- [ ] **I2-05-06** Preserve cloud OpenAI/Anthropic/Gemini opt-in, preview, Credential Manager and token cap.
  - **Done when:** zero network calls before explicit consent.
- [ ] **I2-05-07** Add provider health/timeouts/retry/circuit breaker and cancellation semantics.
  - **Done when:** deterministic fallback, no automatic cloud escalation.
- [ ] **I2-05-08** Add companion freshness status and selectable 'Explain' view.
  - **Done when:** no false live-awareness claim.
- [ ] **I2-05-09** Benchmark 25 mixed questions on a local model and chosen cloud model (user-approved spend).
  - **Done when:** accuracy, latency and costs reported.
- [ ] **I2-05-10** Verify OTR1 Ask→copy→companion→paste loop against real WoW Forever client.
  - **Done when:** 0 code or source mismatch, no model-controlled actions.

- [ ] **I2-05-GATE** Exit criteria demonstrated in automated and live-client evidence where relevant; no unsourced success claims.

## I2-06: Planning and feedback learning (P1)

- [ ] **I2-06-01** Create per-character coaching preference profile.
  - **Done when:** role override/goal/time persisted separately.
- [ ] **I2-06-02** Record bounded usefulness/incorrectness feedback and reason.
  - **Done when:** explicitly entered or verified, no implied acceptance.
- [ ] **I2-06-03** Track only observed quest times and known travel cost.
  - **Done when:** unknown travel stays unknown.
- [ ] **I2-06-04** Re-rank candidates after measurable outcome/relevance evidence.
  - **Done when:** replay tests detect quality change.
- [ ] **I2-06-05** Implement 30/45/60 minute plan and alternative selection.
  - **Done when:** feasible ordering with stated estimates.
- [ ] **I2-06-06** Add delete/export/reset feedback history and preview.
  - **Done when:** no secret/local identity leaks.
- [ ] **I2-06-07** Add opt-in desktop push-to-talk with last-snapshot age label.
  - **Done when:** no game hooks, no persistent audio recording.

- [ ] **I2-06-GATE** Exit criteria demonstrated in automated and live-client evidence where relevant; no unsourced success claims.

## I2-07: Security/performance hardening (P0 release)

- [ ] **I2-07-01** Audit secure actions, scripts, combat taint and unknown/secret API behavior.
  - **Done when:** 0 forbidden calls or taint in game.
- [ ] **I2-07-02** Audit model input prompt injection, oversized fields and malicious tool outputs.
  - **Done when:** 0 trusted malicious commands.
- [ ] **I2-07-03** Audit endpoint redirects/SSRF, TLS, credential storage and cloud spend caps.
  - **Done when:** no remote leakage/redirect or unknown fallback.
- [ ] **I2-07-04** Bound event registry/history/serialized snapshot, measure memory and CPU.
  - **Done when:** measured budgets or approved documented waiver.
- [ ] **I2-07-05** Test competing addon yielding, source absence, intermittent provider failures.
  - **Done when:** graceful degradation.
- [ ] **I2-07-06** Validate /reload, logout, character changes, v1/v2 migration and offline restore.
  - **Done when:** saved data stable, no corrupted profiles.

- [ ] **I2-07-GATE** Exit criteria demonstrated in automated and live-client evidence where relevant; no unsourced success claims.

## I2-08: Universal beta and release (P0 release)

- [ ] **I2-08-01** Play in live client on all nine classes; collect role verification, logs and screenshots.
  - **Done when:** 9 class signed evidence rows, no mock-only certifications.
- [ ] **I2-08-02** Check all role variants, unusual Forever races and talent respec/gear relevance.
  - **Done when:** explicit UNKNOWN fallback, no role mismatch.
- [ ] **I2-08-03** Verify auction seller/buyer review only and 10 negative tests in AH.
  - **Done when:** zero uncontrolled buy/sell.
- [ ] **I2-08-04** Compare 25 questions and common actions with Wisp, thott.bot and other relevant offerings.
  - **Done when:** fair side-by-side report with dated evidence.
- [ ] **I2-08-05** Run independent threat, privacy and policy audit; review GPL and data rights.
  - **Done when:** all safety/legal release blockers resolved.
- [ ] **I2-08-06** Publish changelog/setup, metrics, free-addon notice and owner-approved beta.
  - **Done when:** no misleading live sync claims.
- [ ] **I2-08-07** Release only after Gary approves screenshots, quality metrics and all gates.
  - **Done when:** branch eligible for merge; main unchanged until signoff.

- [ ] **I2-08-GATE** Exit criteria demonstrated in automated and live-client evidence where relevant; no unsourced success claims.

## I2-09: Potential seamless synchronization (not approved) (BLOCKED)

- [ ] **I2-09-01** Explicit owner request revising existing D18 (not implied by this blueprint).
  - **Done when:** specific signed decision prerequisite.
- [ ] **I2-09-02** Written review/approval of proposed specific interface and privacy impact.
  - **Done when:** no implementation without policy gate.
- [ ] **I2-09-03** Separate isolated non-distributed experiment and adversarial review.
  - **Done when:** never production if ambiguous.
- [ ] **I2-09-04** New transport-specific user consent, rate limits, and verifiable evidence checks.
  - **Done when:** independent release decision.

- [ ] **I2-09-GATE** Only with explicit policy/owner authorization.

## Suggested first Claude Code execution batch

1. Reconcile the branch with `CLAUDE.md`, D18, existing AI v1 and this document. Establish tests and initial performance logs.
2. Build one tiny universal profile registry and observation/evidence model.
3. Adapt existing `WhatNow` candidates into the new Opportunity schema, not new hard-coded Hunter advice.
4. Render one native Coach card using existing widgets. Keep old Advisor intact.
5. Prove class-neutral behavior on **Warrior, Druid and Hunter** fixtures, with no model or network dependency.
6. Commit the vertical slice and stop at the I2-02 acceptance gate before adding ten simultaneous subsystems.

## Nine-class fixture matrix

| Class | Minimum role cases | Universal goal tests |
|---|---|---|
| Warrior | tank / damage | level, gold, gear, professions, explore, mix |
| Paladin | tank / melee damage / healing | all six |
| Hunter | ranged damage / pet utility | all six |
| Rogue | melee damage | all six |
| Priest | healing / spell damage | all six |
| Shaman | healing / melee damage / spell damage | all six |
| Mage | spell damage | all six |
| Warlock | spell damage / demon utility | all six |
| Druid | tank / melee damage / spell damage / healing | all six |
| Unknown Forever token | universal only, explicit unknown | all six |

**Additional role tests:** role overrides, hybrid talent distributions, unreadable talents, missing data packs, self-healing/off-role stat suggestions, alternate gear profiles and no secret-combat inference.

## Test evidence template per task

```text
Task: I2-xx-yy
Branch/commit: ________
Files changed: ________
Automated test command/result: ________
CI URL: ________
Current Forever client build: ________
Live steps performed: ________
Observed game behavior / logs: ________
API provenance / secret fields: ________
Performance delta: ________
Policy/feature-flag check: ________
Remaining risks: ________
Acceptance state: IMPLEMENTED | MOCK-GREEN | LIVE-WORKS | MATCHES | SURPASSES
```

## Release-blocking acceptance checklist

- [ ] All 9 class profiles and all applicable role fixtures pass; each class observed on actual Forever client.
- [ ] All 54 baseline class × universal goal scenarios pass; unknown class safe fallback passes.
- [ ] No model output supplies an executable game action or unsupported IDs/coords.
- [ ] Opportunity Radar behaves offline; no unnecessary network connection.
- [ ] Native HUD shows at most 1+2 opportunities and does not interrupt combat.
- [ ] Every active actionable suggestion has evidence ID, source timestamp/build, and visible certainty.
- [ ] Auction math handles stack/unit, binding, vendor value, funds/reserve, freshness and no auto-buy.
- [ ] Cloud defaults off and all external sharing is previewed and consented; credentials remain protected.
- [ ] Full Lua/companion CI green, no saved-state migrations regressions, no taint, no leaking chat/players.
- [ ] Real-game measurements for CPU, memory and latency recorded; owner approves any exceptions.
- [ ] No continuous external bridge without a new explicit decision and policy acceptance.
- [ ] Gary Mix reviews the final UX, setup, beta outcomes and production release notes.

**Do not mark all gates complete simply because the task list is exhausted.**