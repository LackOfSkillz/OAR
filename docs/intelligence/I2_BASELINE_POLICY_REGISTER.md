# Intelligence 2.0 — Baseline and policy register

**Branch:** ai/intelligence-2.0. **Original baseline:** p1-foundation ec828d4. **Reconciliation:** merge 91387a2 (p1-foundation 4e4b692).
**Release status:** development only. Historical client observations are not new Intelligence 2.0 live benchmarks.

## Trust and decision register

| Boundary | Current decision | Required acceptance |
|---|---|---|
| Gameplay control | D6 and D18: advice only; player presses each key/click. | No input automation, macros driven by events, or protected changes. |
| Transport | D18: player-copied OTR1 or explicit data-only Advice.lua; no continuous bridge, screen, memory, or addon-state communication. | I2-09 remains blocked until a separate owner/policy decision. |
| Secrets | Compat.Readable and IsSecret; never compute with client-secret combat values. | Real-client taint, forbidden API and combat checks. |
| Privacy | No chat, other-player details, account identity or keys passed to models. | Preview selected evidence, consent, bounded payload and private binding. |
| Model output | Candidate ID selection only; whitelist actions reconstructed from the trusted snapshot on player paste. | Prompt injection, invented IDs, stale/wrong snapshot negative tests. |
| Data | Observed/verified/community/inferred are distinct; no guessed item IDs or coordinates. | Source build, timestamps, expiry and live evidence. |
| Economy | No automatic auctions or purchases; history alone is never an executable deal. | Live lot, unit/stack, gold reserve, bind and price negative tests. |
| Licensing | Original software GPLv3; derived data rights remain independently reviewed. | Review corresponding source/attribution before public release. |

## Existing modules are authoritative

| Source category | Existing source of truth | New Intelligence adapter |
|---|---|---|
| Next-step candidates and goals | Modules/WhatNow.lua | Intelligence/Opportunity.lua, Radar.lua |
| Quest/gear/dungeon routes | Journey, Nearby, GearScore, DungeonGuide | WhatNow candidate source and evidence |
| Role state | ns.PlayerClass plus per-character DB | Intelligence/Profiles.lua, manual role override |
| Market history and live listings | Prices, AHBuy, AuctionHelper | Intelligence/Economy.lua (read-only calculator) |
| Snapshot and advice | Advisor/Snapshot, AdviceLoader; Python context and orchestrator | additive schemas_v3, coach_v3 |
| UI and refresh lifecycle | UI/Widgets, Core/Timer, Core/Events, Core/DB | opt-in Radar using source events |

## Nine-class acceptance matrix

Warrior: tank, melee. Paladin: tank, melee, healer. Hunter: ranged, pet. Rogue: melee. Priest: healer, caster. Shaman: healer, caster, melee. Mage: caster. Warlock: caster, pet. Druid: tank, melee, caster, healer. UNKNOWN: universal-only.

Every known class must retain all six universal goals: level, gold, gear, professions, explore, mix. That is 54 baseline class-by-goal scenarios, plus UNKNOWN fallback. Automated coverage is not equivalent to checking the live game's nine classes and their specializations. Player-selected roles are not inferred from incomplete talents.

## Known performance baseline and gap

The older general Outrider performance probe measured about 577 KiB with five active modules on client 1.60.1 build 70888, November 11, 2026. This is **not** an Intelligence 2.0 measurement. New Radar is disabled by default, uses no permanent OnUpdate, and coalesces opted-in events at two seconds. The I2 target is <=300 KiB incremental memory and refresh p95 <=3 ms; both require measured live-client traces.

## What still requires hands-on evidence

All-class in-game screenshots/logs, talent-respec and hybrid behavior, actual AH listing review, PvE combat suppression and no-taint checks, source freshness, cloud-provider consent and costs, latest client performance, independent policy/licensing audit and owner signoff. I2-09 may not be implemented without explicit new authorization.

## Status discipline

Commit and automated test evidence support implementation/mock-green labels only. A phase gate requiring the Forever client is not complete until real game behavior, build number and logs have been collected. Main must remain unchanged pending Gary's approval.