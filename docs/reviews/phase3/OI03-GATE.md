# Outrider independent phase review packet: Phase 3 (AfterAction, personal learning)

## Implementation submission (Claude)

- **Phase / task IDs:** OI03-01 to OI03-15, gate OI03-GATE.
- **Repository and branch:** LackOfSkillz/OAR, `ai/outrider-personal-intelligence` (pushed).
- **Phase base SHA:** `7f4ab21` (Phase 2 accepted, automated scope; the owner forwarded the acceptance as the Phase 3 go-ahead).
- **Candidate SHA:** the commit that adds this packet. Take it from `git log -1`; CI runs on every push.
- **Also in this range (not Phase 3 scope):** `b1d4187` "Fix: Compat.Call drops values past the fifth". Found while building OI03-06: four modules (Census, Favor, LootRolls, PetStatus) read a sixth or seventh return value that was always nil. A guard spec now rejects any such call.
- **Release note (owner instruction, 2026-11-24):** Gary asked for this pass to be pushed to git and uploaded to CurseForge when done. That upload happens after this packet and before ChatGPT's review of Phase 3. Every Phase 3 recorder is opt-in and off by default, and the planner (Phase 2) is still off by default.
- **Client:** WoW Forever 1.60.1 (TOC 16001).
  - **Live evidence collected:** OI03-01 only (PlaySession marker and Ledger stamping, 2026-11-24).
  - **Not yet seen live:** the rest.

### ChatGPT's Phase 3 conditions, and where each is met

| Condition | Where |
|---|---|
| Reuse XP60, session history, evidence, archive, Nexus; no duplicate history stores | **Shared marker:** PlaySession is a session marker, not a store; SessionXP and Ledger stamp their own records (OI03-01). **Derived on demand:** quest times come from the existing quest diary (OI03-04); fight context goes into FightMeter's existing rows (OI03-07); preferences read existing Radar and What now? feedback (OI03-10); the next-session plan reuses the XP60 loader (OI03-12). **New store:** all new collection sits in one opt-in store (`char.outcomes`). |
| Observed apart from inferred; correlation never shown as proof | Attribution is only "likely" or "unknown", never "direct" (OI03-02). The report, the evidence and the harness test for claim words and state that "likely" is not proof (OI03-11, OI03-14). Sessions are compared only when matched, and then only as an observation (OI03-14). |
| Learning bounded, explainable, reversible, with enough evidence | The preference nudge is at most ±0.05 and appears in the score trace; it can be switched off, reset and undone (OI03-10). The estimator needs at least 5 samples, else it falls back with a reason; it uses shrinkage, MAD outliers, the current build first and held-out calibration (OI03-09). |
| No fabricated observations; derived estimates never overwrite history | No duration is invented: only complete one-session quests and arrived ground trips count (OI03-04, OI03-05). Derived values are computed on demand and never written back. Evidence keeps observedAt separate from calculatedAt (Phase 2). |
| Data preservation override | Every cap and clear archives first. Two existing silent wipes were fixed: `/ride xp60 clear` (OI03-01) and the NextSession suppression list (OI03-12). The new datasets are in the audit (57 in total): `xpSessionsCleared`, `outcomeEvents`, `activitySessions`, `travelTrips`, `confirmedSales`, `chronicleEntries`, `chronicleCleared`, `xp60Suppressed`, `nexusLastPlan`, `outcomesReset`. |

### Architecture (additive, under `addon/Outrider/Intelligence/`)

```
PlaySession (session marker: reload / logout / interrupted)
   │ stamps
SessionXP, Ledger (existing)            QuestInfo diary (existing, +session/group/build)
   │                                        │
Outcomes (opt-in recorder, v4 OutcomeEvent) ── ActivityTimeline, TravelTimes,
   │                                            EconomyOutcomes, Chronicle
   ├─> QuestTimes, PerformanceStats (FightMeter rows + survival), Estimator
   ├─> Preferences ──> Score (bounded "your feedback" term)
   ├─> AfterAction (report page, Evidence, exports, Start fresh)
   ├─> NextSession (offline XP60 plan, now session/planner/estimate aware)
   └─> Recovery (welcome-back check, player chooses)
```

### Acceptance evidence table

| Task | Acceptance criterion | Files | Tests | Status |
|---|---|---|---|---|
| OI03-01 | logout, reload, disconnect, multi-character, duplicates: no double counts or false completed sessions | PlaySession.lua, SessionXP.lua, Ledger.lua, xp_baseline.py | playsession_spec (9), test_xp60 (+1) | MOCK_GREEN; live partly confirmed |
| OI03-02 | semantic dedup; missing or secret fields unknown; wrong character, late, unknown attribution | Outcomes.lua, Contracts (OutcomeEvent) | outcomes_spec (11), contract fixtures | MOCK_GREEN |
| OI03-03 | segments don't overlap or exceed wall time; inactive and unclassified reported; no combat log | ActivityTimeline.lua | activity_timeline_spec (7) | MOCK_GREEN |
| OI03-04 | no invented durations; strata by context and build; Journey 300 s comparison | QuestTimes.lua, QuestInfo.lua | questtimes_spec (4) | MOCK_GREEN |
| OI03-05 | teleport, disconnect, flight, boat, detour, unknown map never mixed with walking | TravelTimes.lua | traveltimes_spec (8) | MOCK_GREEN |
| OI03-06 | disappeared auctions aren't sales; no double-counted transfers; estimates not profit; unknown fees explicit | EconomyOutcomes.lua (+ Compat.CallAll fix) | economyoutcomes_spec (7), compat_callall_spec (2) | MOCK_GREEN |
| OI03-07 | unknown meter, combat, other builds and missing results excluded; no restricted metrics | FightMeter.lua, PerformanceStats.lua | performance_spec (6) | MOCK_GREEN |
| OI03-08 | replay and reload keep order and dedup; clear or export selected; no raw chat | Chronicle.lua | chronicle_spec (8) | MOCK_GREEN |
| OI03-09 | held-out, no leakage; outlier, sparse and patch cases widen or fall back; real calibration error | Estimator.lua | estimator_spec (8) | MOCK_GREEN |
| OI03-10 | ignored isn't negative; no amplification; explainable and reversible | Preferences.lua, Score.lua, NexusCore.lua | preferences_spec (7) | MOCK_GREEN |
| OI03-11 | totals reconcile; no fake claims; partial sessions labelled; demo data labelled | AfterAction.lua, Hub, Tips, HelpData | afteraction_spec (6) | MOCK_GREEN |
| OI03-12 | time budget, quest dedup, stale, character, session and build binding; delivery policy-gated | AdviceLoader.lua, NextSession.lua | nextsession_reuse_spec (7) + existing xp60 and advice specs | MOCK_GREEN |
| OI03-13 | no blind reapply; resume or new; long absence and deleted quest | Recovery.lua, NexusCore.lua, NexusPage.lua | recovery_spec (7) | MOCK_GREEN |
| OI03-14 | same fixture, same report; counts and unmatched disclosed; no causal claim without matching | AfterAction.lua (Evidence), afteraction_fixture, afteraction_bench.lua | afteraction_bench_spec (6) | MOCK_GREEN |
| OI03-15 | disabled records nothing; reset and delete as documented; bounded persistence and migration | Outcomes.lua, AfterAction.lua | retention_spec (8) | MOCK_GREEN |

Per-task evidence: `docs/reviews/phase3/OI03-xx.md`. Data lifetime: `docs/intelligence/DATA_LIFETIME.md` (Phase 3 stores added).

### Results at the candidate

Full suite (`tools/test.ps1 -RequirePython`):
- Lua: 1302 passed, 0 failed, 0 syntax errors (1191 at the Phase 3 base; 111 new tests across 16 new specs).
- Python: all suites pass, including the new reload-merge test.
- Quality: 22 baselined, 0 new.
- Deps: 0 new.
- Security: 0 violations.

### The gate's own items

- **Observed session report:** Home > After action (OI03-11), with "Show an example" for a labelled demo.
- **Learning and calibration:** Estimator (OI03-09), fixture calibration in the harness (OI03-14). Live calibration error appears from your own play through Export evidence.
- **XP60 crosswalk:** the offline XP60 plan is bound to the merged play session the companion reads (OI03-01 + OI03-12). The companion's `merge_segments` and the addon's `PlaySession.Merge` follow the same rules (tested on both sides).
- **Live sample plan** (one evening, recorder on):
  1. Full restart, then switch on Home > After action > Record outcomes.
  2. Take and turn in quests.
  3. Set a waypoint and walk to it; take one flight.
  4. Sell to a vendor; take one auction mail if any.
  5. Die once if convenient.
  6. Do one `/reload`, then log out.
  - **Then I read:** the session marker's endReason values, the outcome events and their categories, the timeline totals against the wall time, trip modes, the chronicle, and the After action page (Print Screen).
- **Sparse data:** nothing quantifies an uplift. Fewer than 5 samples falls back with a reason, sessions are compared only when matched, and the harness disclosures are tested.
- **Unresolved delivery stays off:** the companion's offline plan still arrives only through the policy-checked advice file. Nothing new sends or receives data.

### Known limits and open items

- **Live:** everything except the OI03-01 marker is mock-verified only. The live slice above is needed before release acceptance, along with the Phase 1 and Phase 2 live items in the tracker (frame cost and memory, route finder, event compatibility, backup restore).
- **Activity labels are deliberately coarse:** walking isn't "travel" and fighting isn't "quest" without a quest event, so "unclassified" can be large. That is honest, not a defect.
- **Teleport detection** relies on a cast followed by a loading screen or a jump within 15 s; a rare edge case could label a portal walk as transport.
- **Two identical auction sales** read in the same hour count once (an undercount, never an overcount).

### Rollback

Each task is one commit. The recorder is off by default; switched off, no Phase 3 code records anything. Reverting removes the Intelligence files; saved data stays in `char.outcomes` and the archive, harmlessly unread.

## Independent review (ChatGPT fills)

| Finding ID | Severity | File/symbol and evidence | Requirement | Correction | Regression test | Status |
|---|---|---|---|---|---|---|
| | | | | | | |

Decision: `REVIEW_CHANGES` / `REVIEW_ACCEPTED` (scope stated) / `BLOCKED`.

## Product owner decision (Gary)

- Live slice approved / outstanding:
- Approve Phase 4 / request revisions:
