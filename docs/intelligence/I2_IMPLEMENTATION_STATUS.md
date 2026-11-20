# Intelligence 2.0 — development status (November 18, 2026)

**Branch:** `ai/intelligence-2.0`; **release state:** DEVELOPMENT, not approved for deployment or merge.

## Source implemented, acceptance still in progress

- **Class profiles:** nine original WoW classes plus UNKNOWN, six universal goals, per-character manual role override (`/ride role`). Verified in mocks, not yet every live role/Forever race.
- **Evidence/Opportunity:** bounded read-only local evidence, class/role eligibility, TTL checks, source-bound candidate IDs; excludes secret values from actionable decisions.
- **Offline Radar:** opt-in `/ride radar` UI, up to 1+2 suggestions, source explanation, explicit feedback, mute, reset, 30/45/60-minute preference and event coalescing. No model required, no gameplay automation.
- **Economy:** verified-stack vendor floor and conservative eligibility; resale/crafting are hypotheses, confirmed outcomes separately recorded; opt-in Deal Desk reads player-issued AH searches without purchasing or scanning.
- **Companion v3:** player copy/paste OTR1 transport remains; additive Python v3 typed contexts and validator, v3 Lua AdviceLoader, offline deterministic fallback or explicitly configured model. Legacy v1/v2 remain supported.
- **Provider hardening:** non-loopback TLS/auth gate (documented explicit development override), local circuit breaker; Anthropic server-side model fallback disabled.
- **UI baseline:** newer `p1-foundation` Advisor/UI improvements merged into this branch at `91387a2`.
- **Policy:** [risk and ownership register](I2_BASELINE_POLICY_REGISTER.md) preserves D18, privacy, no secret-value computation, user-controlled actions and I2-09 block.

## CI and review evidence

The original command-smoke failure was fixed in `a4344a9`; [run 44404920384](https://github.com/LackOfSkillz/OAR/actions/runs/44404920384) passed. A later integrated run with Deal Desk reached **741 passed, 1 failed, 0 syntax errors**; the failed test used a host `time()` instead of the mock clock and was corrected at `530e583`. **The newest combined code must pass its own CI** before any mock-green claims.

See the [77-task backlog](OUTRIDER_INTELLIGENCE_2_0_IMPLEMENTATION_BACKLOG.md) for statuses. `[~]` means partial; it is not a claim of completion. The project is not 77/77 complete.

## Remaining engineering and acceptance blockers

- Genuine specialization/talent evidence, role-appropriate gear and consumable coaching with nine-class live checks.
- Source-pack version/provenance, event-specific invalidation, full v3 Lua snapshot/export UX and strict privacy previews.
- Comprehensive native Coach HUD UX/performance verification, no-taint combat checks and SaveVariables migrations.
- AH scan/commodity coverage, player-review UX, source currency/lot age and confirmation accuracy on real Forever auctions.
- Real local/cloud model trials, provider cost/latency benchmarks, provider consent tests, real OTR1 copy/paste round trip.
- Real memory/CPU timings, source/third-party compatibility, independent security/GPL review and 25-question side-by-side evaluation.
- User-approved nine-class beta, release packaging and signoff. I2-09 remains blocked by D18.

`main` remains untouched. Do not mark tasks or release gates complete without their distinct source, CI and live evidence.


## XP60 AfterAction integration — unverified developer beta

- **XP60-00**: Opt-in Lua `SessionXP.lua`, XP/level/zone/turn-in observations, persisted bounded per-character history and native periodic quest snapshot. Login/off, logout/reload, and interruption tests exist. Real Forever XP/level-up event semantics remain unverified.
- **XP60-01**: Read-only `session_reader.py` parses `WTF/.../SavedVariables/Outrider.lua`, caps input, checks file stability and deduplicates sessions; `xp_baseline.py` computes a wall-clock rate only from valid completed sessions.
- **XP60-02**: `xp60_planner.py` has a bounded 3600-second search, prerequisites, buffer, quest-reward dedup and safe no-data fallback. Journey provides a separately labeled tentative estimate tier. Quantified improvement claims are withheld without comparable observations. Real travel/quest predictions and useful alternative routes need hands-on validation and calibration.
- **XP60-03**: `next_session_delivery.py` validates data and requires Windows process-exit checks before writing existing `Advisor/Advice.lua`. `xp60_cli.py` supports one-shot preview and opt-in watch/install. Lua schema 4 is bound to a finalized character session and `NextSession.lua` displays it without auto-actions.
- **XP60-04**: Feedback and tests added. **Incomplete:** complete live-client verification, performance/cap/taint benchmarks, actual Windows watcher trial, nine classes and owner UX signoff.

[AfterAction design](AFTERACTION_XP60_ENGINEERING_DESIGN.md) | [Windows beta guide](XP60_USER_GUIDE.md)

No automatic background worker has been started in a user's environment. The feature has not been merged into `main`.
