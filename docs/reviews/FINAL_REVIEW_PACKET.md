# Outrider independent review packet: Phases 3 to 8 (one combined review)

## Implementation submission (Claude)

- **Phases / task IDs:** OI03-01 to OI03-15, OI04-01 to OI04-15, OI05-01 to OI05-17, OI06-01 to OI06-13, OI07-01 to OI07-12 and OI08-01 to OI08-14, with every phase gate.
- **Repository and branch:** `LackOfSkillz/OAR`, `ai/outrider-personal-intelligence`. Not merged into `main`.
- **Base SHA:** `7f4ab21` (Phase 2 accepted). **Candidate SHA:** `7d91268`.
- **Review arrangement (owner, 2026-11-24):** "we will let gpt review when all phases are complete. continue with no stops til the entire spec is complete. then we will have a review at the end". Each phase has its own gate packet; this packet ties them together.
- **Client:** WoW Forever 1.60.1 (build 70862). **Live evidence:** only OI03-01 is partly confirmed live (the session marker and Ledger stamp). Everything else is mock-tested and needs owner live checks.
- **Release:** 0.5.0 was uploaded to CurseForge (file 9803350) during Phase 3, at the owner's request. Nothing from Phases 4 to 8 has been published.

### Phase gate packets

| Phase | Packet | Gate commit | Full suite at the gate |
|---|---|---|---|
| 3 Personal outcomes | `docs/reviews/phase3/OI03-GATE.md` | `237a53b` | 1302 passed |
| 4 Planning (Horizon, GearROI, Foresight) | `docs/reviews/phase4/OI04-GATE.md` | `78897bf` | 1372 passed |
| 5 Oracle, Forge, Quartermaster, Treasurer | `docs/reviews/phase5/OI05-GATE.md` | `6b10c5e` | 1416 passed |
| 6 Cartographer and Fellowship | `docs/reviews/phase6/OI06-GATE.md` | `771e413` | 1431 passed, 2 fixed after |
| 7 Expedition, Mentor, UX | `docs/reviews/phase7/OI07-GATE.md` | `c54e4ee` | 1446 passed, 1 fixed after |
| 8 Companion and release | `docs/reviews/phase8/OI08-GATE.md` | `7d91268` | 1451 passed, 0 failed |

Per-task status and evidence for every task: `docs/blueprint/TRACKER.md`.

### Status summary

| Status | Tasks |
|---|---|
| MOCK_GREEN (tests pass, live check pending) | all of Phases 3 to 7 except the documents, and OI08-02 to 07 |
| DONE (documents) | OI06-08, OI08-01, OI08-08 |
| PARTIAL | OI08-11 (Outrider's own 25-question baseline; competitors not scored) |
| PLAN | OI08-10 (packaging plan; clean-machine trial pending) |
| BLOCKED (owner) | OI08-09 voice (not approved), OI08-12 universal live beta (needs real clients) |
| OWNER CONFIRMATION | OI08-13 (name and legal scope) |
| Live tests pending | OI06-13 (two clients), OI08-04 (real round trip), OI08-05 (approved install on real Windows), OI08-06 (a real provider) |

### Behaviour changes a reviewer should check

1. **Planner (Phase 4):**
   - Step times now include the activity, and shared same-map travel is counted once.
   - Budgets carry a 20% margin.
   - Automatic re-plans are at least 20 s apart, with a 10% better-first-step rule.
   - `Travel:TimeTo` is corrected by measured walking (the original is kept as `TimeToRaw`).
2. **Hub sections:** `Hub:AddSection` was defined twice, and the old alias hid the Gear page's sections. It is now one definition (found in Phase 5).
3. **Sightings:** sightings record the game build, and respawn gaps don't cross a build (Phase 6).
4. **Fellowship and plan ids:** Fellowship now shares plan picks via `NexusCore:StepIds`. The first version read a field that doesn't exist, so it shared none (fixed at the Phase 6 gate).
5. **Recovery:** a quest reading done or gone after a game update becomes "check it yourself"; another character's summary is ignored (Phase 7).
6. **Experience modes:** a new character starts in Beginner mode, which shows less on cards. Same facts (Phase 7).
7. **Companion:**
   - XP60 `--install` refuses without an owner policy file.
   - The model's limits can no longer push out Outrider's own caveats.
   - Pasted advice over 64 KB is refused before decoding (Phase 8).

### Bugs the tests found and fixed during these phases

- `Compat.Call` kept only 5 return values, so four modules lost values. Fixed with `Compat.CallAll` and a static guard.
- Hysteresis compared whole-plan totals.
- Recovery's "gone" check used a global list.
- An inactive stretch was cut from "now".
- `Hub:AddSection` was overridden by the old alias.
- Fellowship's plan read was wrong.
- The Lessons page had a card-tag shape error.
- The orchestrator could truncate caveats.

### Not done or not claimed

- **Not modelled:**
  - **Forge:** procs, spell-changing talents, rage, energy and combo-point rates, haste changes.
  - **Supply:** bind state of alts' items (each transfer says to check).
  - **Market:** yellow and green skill-up rates, per-item post counts.
- **No live evidence** for anything after OI03-01. "Universal" support isn't claimed until OI08-12 runs on real clients.
- **No network code** in the addon. No external community service: it is designed in `docs/COMMUNITY_RELEASE_GATE.md` and blocked.

### How to reproduce

```
powershell -NoProfile -ExecutionPolicy Bypass -File tools/test.ps1 -RequirePython
py -I companion/tests/test_eval25.py --report
```

The first command covers the Lua specs, companion tests, and the quality, deps and security gates.

### Owner data rules followed

- **Data preservation:** nothing collected is deleted or redacted. Replaced data is archived first, and every saved dataset is listed in `docs/quality/data_preservation_audit.json`.
- **No game automation:** advice only.
- **No writes to WoW** except through `tools/deploy.ps1`.

## Independent review (ChatGPT fills)

| Finding ID | Severity (P0-P3) | File/symbol and evidence | Requirement violated | Required correction | Regression test | Status |
|---|---|---|---|---|---|---|
| | | | | | | |

Decision: `REVIEW_CHANGES` / `REVIEW_ACCEPTED` (scope stated) / `BLOCKED`.

## Product owner decision (Gary)

- Live evidence approved / outstanding:
- Policy decisions: XP60 auto install (approve or keep off), voice (approve or keep blocked), name and legal scope (OI08-13).
- Merge or publication approval:
