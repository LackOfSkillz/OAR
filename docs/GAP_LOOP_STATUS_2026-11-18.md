# Outrider /loop — verified gap-closure ledger

**Branch:** `p1-foundation` (do not merge to main without passing tests and live validation).  
**Created:** 2026-11-18.  
**Primary plan:** `docs/GAP_ANALYSIS_DEEP_2026-11-18.md` (38 ranked builds) and raw option-by-option checks. The broader GPT roadmap carries 107 named sub-gaps, many overlapping the deep plan.  
**Important:** The following changes were committed using a GitHub repository connector; there was **no access to the Windows local WoW client or a runnable copy of the full private repository**. The full Lua + companion test suite and actual Forever behavior remain **unverified** until a local or CI test runs. Never mark anything `WORKS` before in-game checks.

| Deep gap | Feature | Status | Source changes | Test artifacts | Missing evidence |
|---|---|---|---|---|---|
| #1 | XP pace + ready quest XP | IMPLEMENTED / UNTESTED | `Modules/QuestExtras.lua`, `Modules/InfoBar.lua` | `tests/spec/questextras_spec.lua` | Run full test suite; login/AFK/level-up and quest turn-ins in-game |
| #2 | Layer bar + visited history | IMPLEMENTED / UNTESTED | `Modules/Layers.lua`, `Modules/InfoBar.lua` | `tests/spec/layers_spec.lua`, `tests/spec/infobar_spec.lua` | Test zone changes, instances, uncertainty, recent-visit timestamp, restart, and text layout in-game |
| #3 | Corpse arrow | IMPLEMENTED / UNTESTED | `Modules/Nearest.lua`, `tests/lib/wowmock.lua` | `tests/spec/waypoints_spec.lua` | Verify `C_DeathInfo.GetCorpseMapPosition` returns expected coordinates on Forever; release, ghost navigation, resurrection, old waypoint restore; ensure no regression |
| #4–9 | Vendor sells/restock, waypoint queue, cursor coordinates, tooltips, hunter alerts | NOT STARTED | — | — | Check deps and run after 1–3 prove green |
| #10–15 | Tracker scrolling, chat, instance, map, mail and settings wins | NOT STARTED | — | — | Feature-by-feature |
| #16/17/25 | Auto Shot, threat, damage-meter probes | NOT STARTED / PROBE | — | — | Real client API readings; no combat log |
| #18 | Subzone-aware graveyard map | NOT STARTED | — | — | Death capture/ground truth; distinct from #3 corpse arrow |
| #33/34/35 | 1–60 leveling, categorized bags, dungeon journal | NOT STARTED | — | — | Big builds; individual release gates |
| Importer | Switch to Outrider migration tool | NOT STARTED | — | — | Backup/preview, permissions, reversible imports, no unattended changes |

## Next executable gate

1. Pull the branch and run `powershell -NoProfile -ExecutionPolicy Bypass -File tools/test.ps1 -RequirePython`. Check GitHub Actions run status if available.
2. If red, fix tests and code; rerun. If green, deploy with `tools/deploy.ps1`, fully restart WoW only if files/TOC changed, and test all three scenarios.
3. Record screenshots/logs, compare with the competing addon disabled and enabled; change each status only as supported by evidence.
4. Once validated, continue #4–6 in small separate commits, then resume /loop. Update this table every iteration.

## Restrictions

Never infer completeness from filename, documentation claims or mock tests alone. Keep `main` untouched; do not bypass secret-value/taint safeguards, do not read combat logs, do not automate player actions, and use opt-in privacy rules. No personal/account data in commits. Externally maintained guide/data licenses need their own review.
