# Vanguard independent review packet: VG01 to VG07 (combined)

- **Phase / gate:** VG01-GATE to VG07-GATE, reviewed together by Gary's instruction (D28, 2026-11-26: "loop through all the phases until complete"; ChatGPT reviews once at the end). VG07 (Command Center) not started: it needs Gary's separate authorization.
- **Branch:** `ai/outrider-personal-intelligence` (not merged to main; nothing released or uploaded).
- **Approved baseline:** `fefc7a8` (VG00-GATE accepted after R01/R02).
- **Commits:**

| SHA | Phase |
|---|---|
| `a1e9b17` | VG01-01..10 Group check and shared InspectBroker |
| `3ab8e19` | VG02-01..10 roles, gear stat ranges, indicators, utility, Prep checklist; D28 |
| `ab77169` | VG03-01..11 catalog, access, readiness, Boss matrix, Nexus producer, report |
| `58b76a0` | VG04-01..07 What-if, optimizer, notes, opt-in sharing, reconciliation |
| `7678b77` | VG05-01..10 run records, archive, rates, forecast plan and gate |
| `1d2e491` | VG06-01..06 audits, evidence, docs |
| `37ac555` | VG05-03 archive loop fix, audit entry; first candidate |
| `99fb744` | Researched facts pack (boss needs, access, raids, prices, enchants) wired into Catalog, Access, Assess, Stats, Plan; **candidate** (full suite, deploy and CI below) |

- **Exact-SHA CI and local run:** see "Results" at the end (filled in after the run).

## Microtask matrix

Per-task tables with source paths, tests and limits: `VG01_EVIDENCE.md`, `VG02_EVIDENCE.md`, `VG03_EVIDENCE.md`, `VG04_EVIDENCE.md`, `VG05_EVIDENCE.md`, `VG06_EVIDENCE.md`, `VG07_EVIDENCE.md`. Machine-readable status: `vanguard_backlog.json`.

| Phase | Done (code and unit tests) | Outstanding |
|---|---|---|
| VG01 | 01–10 | live L01–L05 |
| VG02 | 01–10 | live L01, L06, L09 part |
| VG03 | 01–11 | live L01, L08, L09 |
| VG04 | 01–07 | **VG04-08 live only** (two Outrider users, a raid), L07 |
| VG05 | 01–08, 10 | **VG05-09 blocked** (no real labelled runs); L10, L11 |
| VG06 | 01, 02, 06 (automated) | 03 real client (L12), 04 live classes/locale (L06), **05 competitor benchmark not run**, **07 live acceptance** |
| VG07 | 01–07 (authorized D29; companion code and tests) | L14 live export/import with real runs; forecast blocked on data and plan approval |

## Spec tests (new for VG01–VG07)

`inspect_broker_spec` (9), `vanguard_spec` (11), `vanguard_load_spec` (3), `vanguard_roles_spec` (8), `vanguard_board_spec` (10), `vanguard_whatif_spec` (9), `vanguard_runs_spec` (9), `vanguard_audit_spec` (6), `vanguard_facts_spec` (6), `vanguard_desktop_spec` (3): 74 Lua tests; companion `test_vanguard_desktop.py` (21 Python tests). Negative cases included.

## API capability matrix

Unchanged from VG00 (`VG00-04-06_CAPABILITY_MATRIX.md`): inspect via Traits config −1 works on Forever; party roles readable. New probe entries: `GetSpecializationRoleByID`, `GetNormalizedRealmName` (read on the next `/ride probe`). No forbidden API was probed.

## Competitor comparison

None tested in game. All competitors stay "untested" (unknown, not zero). No superiority claim. Scenarios listed in `VG06_EVIDENCE.md`.

## Data preservation

No existing dataset changed, moved or shrunk. Data packs are read-only (VG06 test compares them before and after). New saved data is your own: Vanguard settings and `char.vanguardRuns` (anonymous). Overflow goes to the Archive; damaged values go to `archiveDamaged`; a newer store is left untouched. Deleted count: 0. Tooltip inspect cache lifetime 15 → 5 minutes (memory only, D27).

## Privacy and threat model

- Native inspect data: memory only, 5 minutes, dropped on leave, logout or turning off; never in saved data or logs (disk-wide test with debug on, every feature used).
- Peer data (`VPREP` v1): opt-in, previewed, PARTY/RAID only, sender in group, version and type checks, unknown fields refused, per-sender rate limit, monotonic sequence (replay refused), revoke honoured at once and not undone by late packets, 15-minute expiry, forgotten on leave or off. Memory only.
- Reports: copy box on your press; names only with Copy with names.
- Diagnostics: counts only.

## One-install scenario

`vanguard_board_spec` standalone test: roster only, then a partial inspect (one answers, one too far), with no peers, desktop or internet; useful results with unknowns stated; nothing sent.

## Readiness math and gates

`vanguard_board_spec`: all-unknown never gives a score; range below 80% coverage, point at 80%+; monotonic; deterministic; bad inputs ignored; a confirmed critical miss blocks even with a high average; unknown critical is "not established". No probability wording anywhere (tested in the assessment, report and Runs text).

## Nexus integration

Vanguard's prep actions go through the real `NexusAdapters.Adapt` and `Adapters:All` (tested); unknown cost stays `costUnknown`; empty while Group check is off; invalid candidates rejected; panel intent only. Existing Nexus suites (130 tests) pass.

## Performance

Mock only (desktop Lua 5.1, not the game client): 40-member assessment p95 < 0.1 s; 40-player scan ≤ 4 timers, one request at a time; 40-player optimizer within 200 steps / 20,000 evaluations and deterministic; redraws don't accumulate timers; off leaves nothing. Real-client frame time, memory and taint: **outstanding (L12)**.

## History and forecast

Targets, cohort floors, split and metrics pre-registered (`VG05-07_FORECAST_PLAN.md`). No model fitted or shipped; `Forecast.Predict` abstains; synthetic, thin, other-build, low-coverage and worse-than-base-rate models are refused (tested). Descriptive rates use Wilson intervals with counts and abstain under 5 known fights. Readiness is never presented as odds.

## Outstanding blockers

- **Live (Gary in game):** L01 party with non-users; L02 out of range/offline; L03 Inspect window during a scan; L04 combat and leaving during a scan; L05 raid roster; L06 nine classes; L07 two-user sharing and revoke; L08 a place with a key; L09 prep and Plan; L10 run outcomes with reload; L11 backup/restore with history; L12 real-client performance and taint; L13 competitors; L14 desktop export/import, scenario and guild report from real runs (VG07).
- **Data:** researched facts in the candidate (`docs/vanguard/VANGUARD_FACTS_SOURCES.md`): boss needs for 29 dungeons, access for 30 places, Forever raid sizes and status, vendor prices and Forever enchant values, all from cited web sources and unverified in game. Still missing: recommended raid makeups (none published), most boss NPC ids.
- **Policy/owner:** release, merge to main and CurseForge upload need Gary's approval. VG07 authorized (D29); the forecast plan still needs independent approval before anything is fitted.
- **Forecast:** blocked on real data by design.

## Developer recommendation (not independent approval)

Accept VG01–VG07 as engineering-complete **preview** features with the live blockers above recorded; keep everything off by default until Gary's live pass; do not release.

## Results

- **Candidate:** `99fb74468caafd88fa3de2d78d7b0f61021cfaca` (adds the researched facts pack; new spec `vanguard_facts_spec`, 6 tests).
  - Local full suite (`tools/deploy.ps1`): 1602 passed, 0 failed. The first deploy of the facts shipped an empty pack (build-script slip); fixed, and a minimum-count test now guards it.
  - Deployed: build `20261126-164304-7d13f71+` (the facts commit's files). Full game restart needed. Not run in game yet.
  - Exact-SHA CI: https://github.com/LackOfSkillz/OAR/actions/runs/45900055669, conclusion **success**.
- **Previous candidate:** `37ac5555962c60d4d6248e284ca69afa2f7e7ed3`.
- **Local full suite** (`tools/deploy.ps1`, Lua 5.1 via lupa, Windows): 1596 passed, 0 failed, 0 syntax errors. The first run at `1d2e491` failed one test (archive static contract: the run archive loop wasn't in the fail-safe form and `vanguardRuns` wasn't in `docs/quality/data_preservation_audit.json`); fixed in `37ac555`.
- **Deployed:** build `20261126-152328-37ac555` to the game folder. New files: a full game restart is needed. Not run in game yet.
- **Exact-SHA CI:** https://github.com/LackOfSkillz/OAR/actions/runs/45890717410, conclusion **success**.
- Earlier CI on this branch: VG01 `a1e9b17` (run 45868231506) success, VG02 `3ab8e19` (run 45886947914) success. VG03 to VG06 were pushed together with the candidate.
