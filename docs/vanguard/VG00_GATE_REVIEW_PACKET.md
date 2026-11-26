# Vanguard independent review packet: VG00-GATE

- **Phase / gate:** VG00 (baseline, policy and feasibility) / VG00-GATE. Submitted 2026-11-26 for ChatGPT's independent review. Gary's approval is needed before VG01.
- **Baseline / candidate / branch:** approved baseline `c2ef910` (Release 0.6.0). Candidate `b4878ce` (CI-tested; the code is the same as `951a9a0`, plus this packet): VG00-01..08 in `ca73e4a`, plus one unrelated FarmLab fix on top (`951a9a0`: loot-window drop counting and table mouse-wheel handoff in `UI/WidgetsExtra.lua`; reviewers may skip it or check it as a regression). Branch `ai/outrider-personal-intelligence`. Not merged to `main`, not released.
- **CI:** exact-SHA run for `b4878ce`: https://github.com/LackOfSkillz/OAR/actions/runs/45826953998, **success** (4m46s). The run for `951a9a0` (45826882185) was cancelled when the next push replaced it, so it is not a pass. Local: `powershell -NoProfile -ExecutionPolicy Bypass -File tools/test.ps1 -RequirePython`, giving **1530 passed, 0 failed, 0 syntax errors; companion tests passed** on 2026-11-26 at `951a9a0` (1,521 before VG00, 7 new VG00 tests, 2 for the FarmLab fix).

## Microtask matrix

| ID | Requirement | Source / evidence | Test | Result | Live status | Limitations |
|---|---|---|---|---|---|---|
| VG00-01 | Baseline manifest, dependency map | `docs/vanguard/VG00-01_BASELINE.md` (reuse targets with file:line, data hashes, gates) | n/a (docs) | done | n/a | WTF data not hashed (game running) |
| VG00-02 | Competitive parity matrix | `docs/vanguard/VG00-02_COMPETITIVE_MATRIX.md` (31 sources, licenses, Forever status, 6 scenarios) | n/a | done | none tested in game | advertised features only; 3 pages unreachable |
| VG00-03 | Policy and privacy ADR | `docs/vanguard/VG00-03_POLICY_PRIVACY_ADR.md`, `docs/DECISIONS.md` D27 | probe leak test (below) | proposed | n/a | 3 open owner decisions |
| VG00-04 | Roster capability probe | `addon/Outrider/Core/Probe.lua` `Probe:Roster`; `Modules/AutoCheck.lua` `OnRoster`/`SampleRoster` | `tests/spec/vanguard_probe_spec.lua` tests 1-2 | tests green | **pending live** | raid subgroup needs a raid |
| VG00-05 | Inspect capability probe | `Probe:Inspect`; `Modules/PlayerInfo.lua` `ProbeInspect` (before `ClearInspectPlayer`) | tests 3-4 | tests green | **pending live** | watches existing inspects only; sends no `NotifyInspect` of its own |
| VG00-06 | Encounter event feasibility | `Probe:Encounter`; `AutoCheck:OnEncounter`; 17 events checked with `IsEventValid`, none registered blind | test 5 | tests green | **pending live** | no raid content until Dec 9 |
| VG00-07 | Data and modelling feasibility | `docs/vanguard/VG00-07_DATA_MODEL_FEASIBILITY.md` (9-class matrix, gaps, history inventory) | n/a | done | n/a | no composition history exists; forecast must abstain |
| VG00-08 | Performance baseline | `docs/vanguard/VG00-08_PERFORMANCE_BASELINE.md` (reference machine, measured session, budgets) | n/a | done (short session) | long session pending | CPU profiler was off in the measured session |

## API capability matrix

See `docs/vanguard/VG00-04-06_CAPABILITY_MATRIX.md`. Key facts: `GetNumTalentTabs` is **missing** on Forever (probe 2026-11-25, build 71139). The Classic inspected-talent path cannot work, and the Traits inspect path is pending. `COMBAT_LOG_EVENT_UNFILTERED` is never registered (`ns.Events.FORBIDDEN`). Probes check event validity without registering anything.

## Competitor comparison

Advertised capabilities only (VG00-02). Nothing was installed or tested. Untested competitors are "unknown", not zero. No claim of first, only or superior.

## Data preservation report

- Data packs: hashes in VG00-01. VG00 changes no data pack file.
- New saved dataset `global.probeGroup`: 12 newest samples kept; overflow goes to `global.archive.sets.probeGroup` through `ns.Archive:Shift` with a named path. Registered in `docs/quality/data_preservation_audit.json`, behaviour-tested (test 6: 15 written, 12 kept, 3 archived, 0 lost).
- Deleted count: 0. No migration, no reset.

## Privacy and threat model

VG00-03. Probe samples hold counts and shapes only. Test `leaks()` scans every saved string for the fake names, realm, GUID fragments, `|Hitem` links and item names, and finds none. The inspect cache stays in memory (existing PlayerInfo behaviour, unchanged).

## Not applicable at VG00 (stated so it isn't taken as passed)

- One-install mixed-party scenario: VG01 (needs InspectBroker), with live probe input from VG00.
- Readiness math, unknown/critical gates: VG03.
- Nexus integration, action boundary: VG03.
- History and forecast: VG05. Feasibility only here (no composition history, so forecast abstains).
- Performance of Vanguard features: no features yet. The VG00 handlers are capped per session and do one counter check or one sample each.

## Outstanding blockers

1. **Live:** first samples taken 2026-11-26 (see the capability matrix, live section): one non-user rogue inspected by tooltip hover and one party roster sample. Still missing: a boss-kill sample (VG00-06), a raid roster, a member with talents spent, and the long performance session.
2. **Owner decisions:** D27 approval; inspect cache lifetime; named history with friends; whether hover inspect stays automatic.
3. **CI:** green on `b4878ce` (run 45826953998).

## Developer recommendation (not an independent approval)

VG00 is complete as documentation plus capability probes. It is ready for review, with live samples outstanding. VG01 (InspectBroker) should start only after (a) review acceptance, (b) Gary's approval, and (c) at least one live inspect sample, which tells us whether talents of other players can be read on Forever.
