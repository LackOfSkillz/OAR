# Outrider phase review packet: Phase 5 (Oracle, Forge, Quartermaster, Treasurer)

## Implementation submission (Claude)

- **Phase / task IDs:** OI05-01 to OI05-17, gate OI05-GATE.
- **Branch:** `ai/outrider-personal-intelligence`. **Phase base:** `78897bf` (the OI04-GATE commit).
- **Review arrangement (owner, 2026-11-24):** this packet is written at the gate and reviewed with Phases 3 to 8 at the end.
- **Client:** WoW Forever 1.60.1. **No live evidence yet for Phase 5.**

### Acceptance evidence table

| Task | Acceptance | Files | Tests | Status |
|---|---|---|---|---|
| OI05-01 | live hash unchanged; invalid item, role or level rejected; assumptions and version | Scenario.lua | scenario_spec | MOCK_GREEN |
| OI05-02 | no fabricated precision; only known dimensions; stale asks for refresh; offline | Oracle.lua | scenario_spec | MOCK_GREEN |
| OI05-03..09 | model with sources; timing; ranges for unknown hit and armour; separate roles; bounded deterministic runner; comparison without spending; like-for-like calibration | Forge.lua (on TalentSim) | forge_spec (10) | MOCK_GREEN |
| OI05-10 | 255 limit, slots, combat, respec and rank; no prohibited commands, no automatic execution | MacroVersions.lua (on MacroLibrary) | macroversions_spec | MOCK_GREEN |
| OI05-11 | generated text and known restrictions for every class; real-client check separate | macroversions_spec matrix (9 classes) | macroversions_spec (14 in all) | MOCK_GREEN |
| OI05-12 | cycles, stale alts, realm and faction, rounding, no double allocation | Supply.lua | supply_spec | MOCK_GREEN |
| OI05-13 | priority and override; stock follows changes; no automatic mail, craft or buy | Supply.lua | supply_spec | MOCK_GREEN |
| OI05-14 | integer copper, insufficient gold, override, missing costs, several wallets | Treasurer.lua | supply_spec | MOCK_GREEN |
| OI05-15 | unsold and disappeared auctions not sales; deposits and depth shown; sample counts | Market.lua | supply_spec | MOCK_GREEN |
| OI05-16 | missing rates labelled; actual costs and observed skill-ups apart; no purchase or craft | Market.lua | supply_spec (9 in all) | MOCK_GREEN |
| OI05-17 | no live mutation; novice and advanced; unknowns shown; stale inputs tested | OraclePage.lua, Nearby (Gear page) | oraclepage_spec (5) | MOCK_GREEN |

Per-task notes: `docs/reviews/phase5/OI05-*.md`.

### Results at the gate

- **Full suite:** Lua 1416 passed. The one failure was a Phase 6 file written while the suite ran and not yet in the TOC; with it set aside, the TOC spec passes (12 of 12). This was 1372 at the Phase 4 gate.
- **Quality:** 22 findings, 0 new. **Deps:** 32 pairs, 48 private reads, 0 new. **Security:** 0 violations.

### Behaviour changes a reviewer should check

- **Hub section bug:** `Hub:AddSection` was defined twice. The old tab alias came later and replaced the OI04-GATE section registry, so GearROI's "Worth getting?" never reached the Gear page. It is now one definition for both shapes, with sections looked up by key (OI05-17).
- **Macro approval:** installing through `MacroVersions.Apply` needs the token of the current preview. The existing MacroLibrary install path is unchanged.

### Known limits

- **The Forge** doesn't model procs, spell-changing talents, rage, energy or combo-point rates, or haste changes. Its 9% (hit) and 35% (armour) widths are conservative bounds, not measurements.
- **Sale chance** needs per-item post counts, which aren't recorded yet.
- **Skill-up rates** for yellow and green recipes aren't readable.
- **The Talents page** doesn't show the Forge yet.
- **Live checks pending:**
  - the Gear page What if?
  - a macro preview and rollback
  - a supply plan with an alt
  - the Treasurer rows

## Independent review (ChatGPT fills, at the end of all phases)

| Finding ID | Severity | File/symbol and evidence | Requirement | Correction | Regression test | Status |
|---|---|---|---|---|---|---|
| | | | | | | |
