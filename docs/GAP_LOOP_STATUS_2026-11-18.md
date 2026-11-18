# Outrider /loop — verified gap-closure ledger

**Branch:** `p1-foundation` (do not merge to main without passing tests and live validation).  
**Created:** 2026-11-18. **Latest source code gate:** [669 Lua passed / Python passed](https://github.com/LackOfSkillz/OAR/actions/runs/44299730077) at `e0f86939`.  
**Primary plan:** `docs/GAP_ANALYSIS_DEEP_2026-11-18.md` (38 ranked builds) and raw option-by-option checks. The broader GPT roadmap carries 107 named sub-gaps, many overlapping the deep plan.  
**Important:** The following changes were committed using a GitHub repository connector; there was **no access to the Windows local WoW client**. Windows GitHub Actions now executes the full Lua + companion suite, and the latest source build passed automated CI on 2026-11-18 at commit `dcbb875d` ([run](https://github.com/LackOfSkillz/OAR/actions/runs/44294608991)). Actual Forever gameplay remains unverified. Never mark anything `WORKS` before in-game checks.

| Deep gap | Feature | Status | Source changes | Test artifacts | Missing evidence |
|---|---|---|---|---|---|
| #1 | XP pace + ready quest XP | TESTS GREEN / NEEDS GAME | `Modules/QuestExtras.lua`, `Modules/InfoBar.lua` | `tests/spec/questextras_spec.lua` | Run full test suite; login/AFK/level-up and quest turn-ins in-game |
| #2 | Layer bar + visited history | TESTS GREEN / NEEDS GAME | `Modules/Layers.lua`, `Modules/InfoBar.lua` | `tests/spec/layers_spec.lua`, `tests/spec/infobar_spec.lua` | Test zone changes, instances, uncertainty, recent-visit timestamp, restart, and text layout in-game |
| #3 | Corpse arrow | TESTS GREEN / NEEDS GAME | `Modules/Nearest.lua`, `tests/lib/wowmock.lua` | `tests/spec/waypoints_spec.lua` | Verify `C_DeathInfo.GetCorpseMapPosition` returns expected coordinates on Forever; release, ghost navigation, resurrection, old waypoint restore; ensure no regression |
| #4 | Sell-approved, sell-once and never-sell vendor lists | TESTS GREEN / NEEDS GAME; PARTIAL depth | `Modules/Merchant.lua`, `tests/lib/wowmock.lua` | `tests/spec/merchant_spec.lua`; Windows CI 44294608991 passed | Live vendor checks, non-grey quest-item protection, controls/feedback; automatic learned selling and policy explanations are not implemented |
| #5 | Vendor restock with item targets, gold reserve and player-click batch | TESTS GREEN / NEEDS GAME | `Modules/Merchant.lua`, `tests/lib/wowmock.lua` | `tests/spec/merchant_spec.lua` | Verify merchant return shape, bag-space and spending behavior in Forever |
| #6 | Waypoint queue, arrival advance, saved stops and named-zone/map commands | TESTS GREEN / NEEDS GAME | `Modules/Waypoints.lua` | `tests/spec/waypoints_spec.lua` | Confirm persistence, Travel zone lookup, game arrow ownership and death overlay |
| #7 | Cursor coordinates on visible world map | TESTS GREEN / NEEDS GAME | `Modules/Coords.lua` | `tests/spec/waypoints_spec.lua` | Confirm map canvas geometry on Forever, UI positioning and scale |
| #8 | Combat tooltip suppression, Shift exception, quest objective remaining lines | TESTS GREEN / NEEDS GAME | `Modules/Tooltips.lua`, `UI/TooltipLines.lua` | `tests/spec/tooltiplines_spec.lua` | Verify hooks, no protected/secret taint, quest line types, compatibility |
| #9 | Hunter missing/Cheetah/Pack aspect and group Growl warnings | TESTS GREEN / NEEDS GAME | `Modules/PetStatus.lua` | `tests/spec/petstatus_spec.lua` | Test with real hunter and party; API values/localization and rate limiting |
| #10–15 | Tracker scrolling, chat, instance, map, mail and settings wins | NOT STARTED | — | — | Feature-by-feature |
| #16/17/25 | Auto Shot, threat, damage-meter probes | NOT STARTED / PROBE | — | — | Real client API readings; no combat log |
| #18 | Subzone-aware graveyard map | NOT STARTED | — | — | Death capture/ground truth; distinct from #3 corpse arrow |
| #33/34/35 | 1–60 leveling, categorized bags, dungeon journal | NOT STARTED | — | — | Big builds; individual release gates |
| Importer | Switch to Outrider migration tool | NOT STARTED | — | — | Backup/preview, permissions, reversible imports, no unattended changes |

## Next executable gate

1. Pull the branch and run `powershell -NoProfile -ExecutionPolicy Bypass -File tools/test.ps1 -RequirePython` locally. Windows GitHub Actions passed at `dcbb875d` but in-game proof is pending.
2. If red, fix tests and code; rerun. If green, deploy with `tools/deploy.ps1`, fully restart WoW only if files/TOC changed, and test all four scenarios. In particular, check item allowlist/keep/once at a real vendor; ensure quest items are not sold.
3. Record screenshots/logs, compare with the competing addon disabled and enabled; change each status only as supported by evidence.
4. After #1-9 pass local and in-game gates, begin #10 tracker scroll and #11 chat enhancements. Keep each completion evidence-backed. Update this table every iteration.

## Restrictions

Never infer completeness from filename, documentation claims or mock tests alone. Keep `main` untouched; do not bypass secret-value/taint safeguards, do not read combat logs, do not automate player actions, and use opt-in privacy rules. No personal/account data in commits. Externally maintained guide/data licenses need their own review.

## Quick wins 5-9: operation and client acceptance

- **#5 Restock:** at the vendor use `/ride restock add <itemID> <desired bag count>`, `/ride restock reserve <gold>`, then click **Restock** (up to three item types per click). Test normal stack bundles, costs, missing stock, limited supplies, insufficient funds and extended-cost merchants. Never purchases on vendor open.
- **#6 Queue:** `/ride way add 60 37 First`, `/ride way add 1412 70 37 Second`, `/ride way start` then `next|pause|resume|list|clearqueue`. Verify arrival advancement, SavedVariables persistence, manual override, corpse navigation and map IDs.
- **#7 Cursor:** show the full world map, move over the map and verify the reported coordinates against manual location tests on scaled panels; unknown outside canvas.
- **#8 Tooltip:** combat tooltip hidden by default, Shift allows it, quest NPC tooltip includes typed objective remaining count. Verify on Forever and with conflicting tooltip addons enabled.
- **#9 Hunter:** missing aspect and Cheetah/Pack-in-combat warnings, plus Growl autocast with a group. Verify warnings do not spam and never change ability state.
- **Evidence policy:** all five are **TESTS GREEN / NEEDS GAME**, not `WORKS` or `MATCHES`. A live player must verify purchase and game API behavior before claiming parity.

## Batch 3: ranked gaps #10-14 (2026-11-18)

**Status:** TESTS GREEN / NEEDS GAME for each; GitHub Actions [669 Lua / companion Python green](https://github.com/LackOfSkillz/OAR/actions/runs/44299730077). Do not claim Works, Matches or Surpasses without Forever play-tests.

| Rank | Feature | Source and tests | What shipped | In-game gate |
|---|---|---|---|---|
| #10 | Quest tracker scroll/focus | `QuestTracker.lua`, `MapPins.lua`; `questtracker_scroll_spec.lua` | 20-row visible viewport over entire supported quest log, mousewheel scroll, focus/unfocus and quest-pin alpha | Test 40+ rows, last objective, zone fold, focus with world/minimap pins, Questie conflicts |
| #11 | Chat & whispers | `Chat.lua`; `chat_spec.lua` | 600-line bounded account archive, 100 latest whispers per person / max 30 people, `/ride history [person]`, class-colored author only on resolved GUID | Test true SavedVariables persistence across reload, LFG routing, whispers/secret values, player hyperlink integrity |
| #12 | Dungeon lockout corrections | `Alts.lua`, `UI/MinimapButton.lua`; `alts_spec.lua` | Exit-time based lockout estimates, instance ID, delete erroneous entry, hover readout | Verify actual instance ID and true reset/exit timing versus client; prevent false claims of authoritative limit |
| #13 | Map extras | `MapReveal.lua`; `mapreveal_spec.lua` | `/ride mapextras missing|fishing|faire`; missing overlay count & pixel locations, fishing skill bands by zone, dated Faire location | Overlay positions are not names, skill bands are guidance, **Faire schedule is unverified community calendar**; confirm against real event UI |
| #14 | Mail | `Mailbox.lua`, `wowmock.lua`; `mailbox_spec.lua` | Auction sold/won/expired filters; reserve N bag slots for attachments; Shift-click collect (one user click per thing) | Verify real localized auction subject/sender strings and multi-attachment collection, COD and free-slot protection |

**Current status:** 14 of 38 ranked builds have passing automated CI; 24 remain to implement. No feature has achieved in-game acceptance gates from this remote review.

**Next ranked item:** #15 Settings search box. Then Tier 2 #16 Auto Shot timer and #17 threat overlays, both requiring explicit Forever API probes first.
