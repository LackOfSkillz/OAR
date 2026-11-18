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
