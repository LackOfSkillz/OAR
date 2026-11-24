# Nexus v4 schema map (OI02-01)

Nexus adds version-4 records **alongside** the existing contracts. Nothing in v1-v3 changes:
OTR1 snapshot codes, v2 advice, the v3 envelope (`companion/.../schemas_v3.py`) and the v3 opportunity
card (`Intelligence/Opportunity.lua`, `SCHEMA = 3`) keep their shapes and tests.

- Spec (single source): [docs/contracts/nexus_v4.lua](../contracts/nexus_v4.lua), plain Lua table data.
  - Lua: `Intelligence/Contracts.lua` holds an exact copy (`ns.Nexus.SPEC`). `nexus_contracts_spec` fails
    if the copy differs.
  - Python: `companion/outrider_companion/intelligence/schemas_v4.py` reads the docs file through the
    companion's existing `luadata` parser.
- Shared fixtures: [docs/contracts/nexus_v4_fixtures.lua](../contracts/nexus_v4_fixtures.lua), 18 cases,
  valid and invalid, each with its expected verdict and failing field. Both validators must agree:
  `tests/spec/nexus_contracts_spec.lua` and `companion/tests/test_nexus_v4.py`.

## Rules common to all records

Validation is strict:
- Unknown fields are rejected (`unknownField`), so nothing executable or private rides along.
- `id` allows letters, digits and `_ - : . @` only, up to 120 characters.
- Text up to 300 characters (titles 180), with no control characters or `|` (no UI escape codes).
- Times are UTC epoch integers. Copper and counts are integers. `unit` is a number in [0, 1].
- Enums are closed. Lists are bounded.
- Secret values are rejected.
- Missing data is absent: an optional field left out means unknown, not zero.

## Records and where their data comes from today

| v4 record | Fields (required **bold**) | Existing source (unchanged) |
|---|---|---|
| Evidence | **evidenceId, kind, sourceId, sourceType, observedAt, expiresAt, confidence, privacy**, clientBuild, packRevision, sampleCount | `Intelligence/Evidence.lua` records (`id` to evidenceId, `category` to kind, `label` to confidence, `build` to clientBuild); v3 envelope `evidence[]` |
| CharacterState | **characterKey, classToken, role, roleSource, level, faction, takenAt, revision**, copper | `Intelligence/Profiles.lua` (class, role, explicit role override), `db.char.meta`, the Advisor snapshot |
| Goal | **goalId, scope, objective, priority, status, createdAt**, target, deadline, reserveCopper | `WhatNow:Goal()` (one active goal today); the six objectives match the I2 universal goals. `archived` replaces deletion (data preservation override) |
| Opportunity | **opportunityId, kind, title, benefit, confidence, evidenceIds, expiresAt, intent, revision**, costSeconds, costCopper, risk, legacyCandidateId, why | the v3 card: `candidateId` to legacyCandidateId (and `opp:<id>`), `score` to benefit, `label` to confidence, `evidenceId` to evidenceIds[1]. `intent` is only waypoint, panel or none: never an action |
| Plan | **planId, snapshotRevision, steps (≤8), reasonCodes (≤16), createdAt, version, truncated**, budgetSeconds | new (OI02-10); `NextSession.lua` / XP60 plans map their step ids into `steps` |
| Outcome | **eventId, sessionId, startAt, result, attribution**, planId, stepId, endAt, feedback | `SessionXP.lua` history, Radar and NextSession feedback (`feedback` is kept apart from the observed `result`) |

`N.FromV3Opportunity(card)` produces a v4 Opportunity from a v3 card without changing the card;
an invalid card (for example an unknown confidence label) maps to nothing.

## Versioning

`NexusSpec.version = 4`. A later change adds a new version file and a new validator entry. It never
edits v4 in place once Phase 2 is accepted.
