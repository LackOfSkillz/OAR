# Intelligence 2.0 development branch status

**Branch:** `ai/intelligence-2.0`  
**Based on:** `p1-foundation` at `ec828d423b188e5a76c20f3d657d7b2ad467a000`  
**Created:** 2026-11-18  
**Release status:** DEVELOPMENT ONLY — do not merge.

## Implemented in this branch (pending full review)

| Area | Files | Scope |
|---|---|---|
| Universal roles | `addon/Outrider/Intelligence/Profiles.lua` | Registry for nine Classic classes plus UNKNOWN; six universal goals; explicit role override; no inferred talent/ability assumptions |
| Typed evidence | `Intelligence/Evidence.lua` | Bounded, local-only registry, sanitization, category TTL, invalidation and source provenance |
| WhatNow adaptation | `Intelligence/Opportunity.lua` | Source-bound opportunity cards with score, validation, class/role eligibility, max-three ranking |
| Opt-in Coach | `Intelligence/Radar.lua` | Player-requested offline radar; at most three cards, Why?, Go (existing permissible actions), Later and persisted feedback; off by default |
| Vendor floor math | `Intelligence/Economy.lua` | Read-only current lot eligibility and stack buyout vs NPC unit-price calculation; strictly no automated purchase |
| Automated tests | `tests/spec/intelligence2_spec.lua`, `tests/spec/intelligence_economy_spec.lua` | Unit coverage of class/role registry, evidence lifecycle, safe candidates, feedback and vendor-margin negative cases |
| CI | `.github/workflows/outrider-tests.yml` | Enabled tests for `ai/**` branch pushes |

## Not completed / cannot be certified by mock tests

The complete I2-00..I2-08 backlog is **not implemented** by this first engineering slice. A number of tasks remain: full event-driven refresh/coalescing, 9×6 plus role fixtures, task-specific v3 model context and migrations, complete deal desk UI and player-selected AH integration, model-provider benchmarks, privacy and performance tests, in-game UI visual checks, live addon compatibility, licensing and owner acceptance.

**I2-09 remains BLOCKED** by D18; no external live transport, addon-state side channel, screen capture or input automation has been added. Any review must preserve no-gameplay-automation and no-secret-combat-value processing.

## Test/merge policy

Only mark checklist items `[x]` when a specific implementation and committed automated evidence exist, and only mark live gates complete after actual Forever client verification by the owner. The existing `main` branch is untouched. Never interpret created files alone as satisfying the full release contract.

To continue: inspect the latest AI-branch CI run, fix any failures, then execute I2-00 and I2-01 gates, followed by a fuller I2-02 event-driven Coach. Rebase/reconcile new `p1-foundation` changes before opening the final review PR.
