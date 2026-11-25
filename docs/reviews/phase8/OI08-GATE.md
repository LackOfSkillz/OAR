# Outrider phase review packet: Phase 8 (Desktop companion and release)

## Implementation submission (Claude)

- **Phase / task IDs:** OI08-01 to OI08-14, gate OI08-GATE.
- **Branch:** `ai/outrider-personal-intelligence`.
- **Tested SHA:** `7d91268` (the full suite below ran at this commit). The gate commit adds only the reproducible-zip change in `tools/package.ps1` and documents.
- **Review:** this is the last gate; the combined packet is `docs/reviews/FINAL_REVIEW_PACKET.md`.

### Results at the tested SHA

| Check | Result |
|---|---|
| Lua specs | 1451 passed, 0 failed |
| Companion tests | passed (including test_phase8, test_eval25 and 6 delivery tests) |
| Quality | 22 findings, 0 new |
| Deps | 32 pairs, 48 private reads, 0 new |
| Security | 271 Lua, 66 Python, 814 text files, 0 violations |
| Package reproducibility | before the fix: zip bytes differed (file timestamps), contents identical (468 files). After the fixed timestamps and order: two builds give SHA-256 `88b9283c...51edbd` both times |
| Forbidden package entries | none (WTF, SavedVariables, backups, local.json, config.json, policy.json) |

The task table and evidence are in `docs/reviews/phase8/OI08-01_14.md`.

### Not done at this gate

- **Contract fixtures** (`tools/contract_fixtures.ps1`) are refreshed only for a release; nothing is published.
- **The TOC version** is still 0.5.0; a release would bump it.
- **`tools/curseforge.ps1`** doesn't use the reproducible zip settings yet.
- **Owner items:**
  - OI08-09 voice (blocked)
  - OI08-12 live beta
  - OI08-13 name and legal scope
  - XP60 policy approval
  - real-provider and real-client round trips

## Independent review (ChatGPT fills)

| Finding ID | Severity | File/symbol and evidence | Requirement | Correction | Regression test | Status |
|---|---|---|---|---|---|---|
| | | | | | | |
