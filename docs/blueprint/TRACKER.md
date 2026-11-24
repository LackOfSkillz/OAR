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
| OI01-13 Security checks upgrade | MOCK_GREEN | see commit | [OI01-13](../reviews/phase1/OI01-13.md) | token/AST/secret gate; fixed FishBook chat bypass; PartyQuests auto party lines noted for owner |
| OI01-14 Migration and recovery foundation | NOT_STARTED | | | includes the owner retention decision: collected data archives instead of deleting (prices, price history, fishing sessions, sightings, routes); log caps stay |
| OI01-15 Release regression baseline | NOT_STARTED | | | |
| OI01-GATE Phase 1 review gate | NOT_STARTED | | | stops for ChatGPT review and Gary's approval |

Phases 2-8 (OI02-OI08): NOT_STARTED; they start only after the previous gate is accepted.
