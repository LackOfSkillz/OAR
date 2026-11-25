# Outrider phase review packet: Phase 7 (Expedition, Mentor, UX)

## Implementation submission (Claude)

- **Phase / task IDs:** OI07-01 to OI07-12, gate OI07-GATE.
- **Branch:** `ai/outrider-personal-intelligence`. **Phase base:** the OI06-GATE commit.
- **Review arrangement (owner, 2026-11-24):** this packet is reviewed with Phases 3 to 8 at the end.
- **Client:** WoW Forever 1.60.1. **No live evidence yet for Phase 7.**

### Acceptance evidence table

| Task | Acceptance | Files | Tests | Status |
|---|---|---|---|---|
| OI07-01 | same engine and facts in every mode; novice not overloaded; advanced shows evidence; one switch | Modes.lua, Settings, OraclePage | expedition_spec, oraclepage_spec | MOCK_GREEN |
| OI07-02 | unknown spell or build skips the lesson; no automated input; words kept apart | Expedition.lua | expedition_spec | MOCK_GREEN |
| OI07-03 | fundamentals, survival, utility and group for all nine classes; eligibility; sources reviewed and marked unverified | Expedition.lua, docs/LESSON_SOURCES.md | expedition_spec | MOCK_GREEN |
| OI07-04 | no skill guessing; skip, off, reset; not in combat | Expedition.lua | expedition_spec | MOCK_GREEN |
| OI07-05 | no meter gives words only; no actions; matched contexts only | Expedition.lua (Forge.Calibrate) | expedition_spec | MOCK_GREEN |
| OI07-06 | no code; preview and accept; source, license and build kept; incompatible parts left out | PlanShare.lua bundles | expedition_spec | MOCK_GREEN |
| OI07-07 | a reason and a manual remedy for each; no false "fine"; private export | Troubleshooter.lua, docs/ERROR_GUIDE.md | expedition_spec | MOCK_GREEN |
| OI07-08 | words, not colour only; no Verified without evidence; when, build and source shown | Confidence.lua, RaresTab | expedition_spec | MOCK_GREEN |
| OI07-09 | nothing done after a patch or on another character; controls consistent | Recovery.lua | expedition_spec, recovery_spec | MOCK_GREEN |
| OI07-10 | unknown visits never done; no invented data; dismiss and reset | Challenges.lua | expedition_spec | MOCK_GREEN |
| OI07-11 | pages reachable; no errors at the largest and smallest sizes; textures within client limits | uiquality_spec | uiquality_spec | MOCK_GREEN |
| OI07-12 | every new feature, switch and error documented; claims match evidence | README, HelpData and USER_GUIDE, FEATURE_FLAGS, ERROR_GUIDE, LESSON_SOURCES, PRIVACY | help_spec | MOCK_GREEN |

Per-task notes: `docs/reviews/phase7/OI07-01_12.md`.

### Results at the gate

- **Full suite:** 1446 passed, 1 failed. The boot spec needed a sample for the new `/ride mode` command; it is added and boot passes (8 of 8).
- **Companion:** all 11 test files OK.
- **Quality:** 1 new. The Rares page builder moved two lines, so its known baseline entry was updated from :103 to :105. Now 0 new.
- **Deps:** 1 new (the Troubleshooter read World's quarantine table); fixed with `World.Quarantined()`. Now 0 new.
- **Security:** 0 violations.

### Found and fixed along the way

- **Lessons page:** card tags were passed in the wrong shape, which made the page throw. The new UI quality spec caught it.
- **What if? spec:** it now expects Beginner mode to hide the detail line.

### Known limits

- No lesson is verified on Forever.
- Keyboard navigation is covered only for Esc.
- **Live checks pending:**
  - novice and advanced flows
  - each class's lessons
  - Fix problems on a real client

## Independent review (ChatGPT fills, at the end of all phases)

| Finding ID | Severity | File/symbol and evidence | Requirement | Correction | Regression test | Status |
|---|---|---|---|---|---|---|
| | | | | | | |
