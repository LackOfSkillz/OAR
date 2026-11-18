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

## Batch 4 — DEEP-15 through DEEP-24 (2026-11-18)

**Status: IMPLEMENTED / CI PENDING, NOT ACCEPTED.** Ten implementation slices are committed to `p1-foundation`. The first full [CI run](https://github.com/LackOfSkillz/OAR/actions/runs/44304072219) passed 666 Lua tests, failed eight and had zero syntax errors. Corrections for fixtures, tooltips and test harness declarations were pushed; the corrected [run](https://github.com/LackOfSkillz/OAR/actions/runs/44304709374) was cancelled before receiving jobs while an older job remained in progress. **The last corrected source has NOT passed CI.** Run the entire suite when Actions is available, triage failures, and test on WoW Forever. Do not merge to `main` or mark Works/Matches/Surpasses without evidence.

| Rank | Implementation | Important remaining gate |
|---|---|---|
| #15 | Settings page search by control labels, jump and next match; `UI/Form.lua`, `UI/Pages.lua` | Corrected test file and UI.Tip changes need CI, real UI search navigation |
| #16 | Read-only moving/out-of-range Auto Shot hint anchored to native `SwingTimerRanged`; `Modules/HunterFight.lua` | True shot timing & dead-zone probe, frame creation during client load, range accuracy |
| #17 | Independent threat indicator below nameplates showing YOU/PET %, with pet-blue coloring; `Modules/RarePlates.lua` | Verify real `UnitDetailedThreatSituation` in combat, no taint; still lacks small threat list |
| #18 | Subzone-death log and actual observed ghost graveyard map positions; `Modules/Nearest.lua`, `/ride grave` | Actual Forever ghost events, sample enough subzones, add hover map before parity |
| #19 | Dungeon quest lookup from Questie boss NPC objectives, with manual links; `Modules/DungeonGuide.lua`, `/ride dungeonquests` | Join ALL quests, givers, chains, rewards; load private QuestieDB dataset |
| #20 | Trainer UI observations create class level-up notices and future cost cards; `Modules/Spellbook.lua`, `/ride training` | Need cited standalone 1–60 spell-rank-cost pack to work before **first** trainer visit. Modern Forever trainer API may differ |
| #21 | Queue all/watched rare spawn pins via existing waypoint queue; `Modules/RareScan.lua`, `/ride rareroute` | Real map paths, de-dupe, routes may exceed 30 queue stops and aren't guaranteed optimal |
| #22 | Zone quest XP estimates and greying count; `Modules/Journey.lua`, `/ride zones` | Chain future XP, multi-level projections, best abandon recommendations, data coverage |
| #23 | Personal gear wish list, bag Alt-click, tooltips, boss loot lookup; `Modules/BagExtras.lua`, `Modules/DungeonGuide.lua` | Test secure bag behavior, complete private dungeon data, boss drop percentages |
| #24 | Editable character map notes via Map tab and `/ride note`, world/minimap pin integration; `Modules/MapTab.lua`, `Modules/MapPins.lua`, `Modules/Coords.lua` | Real cursor/map UI and saved-variables/reload verification |

**Current count:** 14/38 rank items with earlier green automated tests, 10 new implementation slices with CI pending, 14 ranked builds not started. This is **not** 24/38 complete under the three acceptance gates.

## Batch 5 — DEEP-25 through DEEP-34 (2026-11-18)

**Status: IMPLEMENTED / CI PENDING, NOT LIVE-ACCEPTED.** Ten ranked slices now have code and `tests/spec/batch5_gap_spec.lua`. The initial full run passed **691/693** tests with **zero syntax errors**; it caught a missing auction-ID case and command-smoke samples. Corrections were committed after that run. Do not merge until final CI and in-game checks are green.

| Rank | Implemented | Outstanding parity / safety gate |
|---|---|---|
| 25 | Read-only `FightMeter.lua`: post-combat `C_DamageMeter` sessions, DPS history, optional toast, `/ride fights` | Validate real combat sessions in Forever, pet-split disclosure; no live Details parity |
| 26 | `BagFood.lua`: prefer and never lists, Well Fed hint, obsolete food review (`/ride foodrules`) | No delete-old-food button; safe user confirmation UI and official buff data needed |
| 27 | `GearScore.lua`: editable named stat scales and validated Pawn subset importer (`/ride scale`) | Full per-spec visual editor, complete Pawn format parser and gear benchmark |
| 28 | `AuctionHelper.lua`: sellable bags preview, selected owned-auction cancel click, audit of disappeared auctions (`/ride auctions`) | Never infer sale vs expiry vs cancellation; explicit event/ledger proof and native AH UI test |
| 29 | `ProfExtras.lua`: learned/unknown recipes from observed trainer or user-supplied registry (`/ride recipesources`) | Cited recipe vendor/drop/quest/level range pack not available; incomplete independent coverage |
| 30 | `Alts.lua`: cached reputation, known recipes and bag details (`/ride altdetail`) | Snapshots require logging in on each alt, not remote live inspection; recipe tooltip parity |
| 31 | `GearSets.lua`: visual set window with item icons, missing bag item report and explicit equip click (`/ride gearwindow`) | Real-game secure equip behavior and icon availability |
| 32 | `RareAlerts.lua`: 3D `PlayerModel` preview when a sourced display ID is known; falls back to icon; sourced loot listing (`/ride rareloot`) | No complete rare display-ID or drop dataset yet; real client fallback test |
| 33 | `LevelRoutes.lua`: original multi-step system (quest, quest-linked kill, loot, place) with persistence, manual skip/undo and Horde 1–20 quest-data candidate seed (`/ride levelroute`) | A *curated full* Horde 1–20 in-zone route was not produced; available NPC-pack quests are incomplete and level-dependent; route timings and steps require human verification |
| 34 | `BagExtras.lua`: optional separate inventory browser, categories, BoE marks, bag/bank/alt snapshots and search highlighting (`/ride bags`) | Read-only browser instead of full native bag replacement, verify bank/stale inventory presentation and yielding to bag add-ons |

No `main` changes. **Ranks #35–38 remain not started.** "Implementation" is not the same as Works/Matches/Surpasses acceptance.

## Batch 6 — final ranked gaps DEEP-35 through DEEP-38 (2026-11-18)

**Code gate PASS:** [CI run 44330275735](https://github.com/LackOfSkillz/OAR/actions/runs/44330275735), source commit `4f85b778`: **702 Lua passed, 0 failures, 0 syntax errors; Python cloud/companion/intelligence/security suites passed**. Regression tests: `tests/spec/batch6_gap_spec.lua`. No Forever gameplay acceptance performed.

| Rank | Implemented and verified in mocks | Explicit remaining parity gate |
|---|---|---|
| #35 Dungeon journal | `Modules/DungeonJournal.lua` added after `DungeonGuide.lua`; linked from Dungeons page; list and boss details, recorded loot, loot wishlist/upgrades, dungeon quests, readiness, entrances; `/ride journal` | Quest pack covers only boss-associated or manually linked quests, not every dungeon quest/chain. Loot/boss pack source may be incomplete. Confirm full data and UI behavior in Forever |
| #36 Heal panel | `HealPanel.lua` secure-unit frame capacity increased to **40**, 5-column/8-row layout; known-spell Shift/Ctrl/Alt left/right click bindings plus visual selector/editor and `/ride heal bind ...`, `/ride heal editor` | 40-player raid, secure retargeting and combat lock test, spellbook rank/target details; mock test is not real 40-player certification. Competitor click-casting options still need exhaustive parity matrix |
| #37 Auction engine | `Prices.lua`: median, mean, min/max and coefficient of variation across **daily lows** (not sale prices), shopping lists/target amounts/groups, `/ride market` | Dynamic AH shopping UI and true item-level market distribution/volume missing; 14-day low-only record cannot support TSM-equivalent market forecasts without new sampling |
| #38 Boss notes/timeline | `Modules/BossTimeline.lua` reads `C_EncounterTimeline.GetEventList` with strict readability checks; user-authored persistent notes; `/ride bossnotes` | Client API present but live event shape, authoritative countdowns and broad boss-mechanic datasets unverified; no full DBM/BigWigs parity |

**Final ranked implementation state:** 38/38 have *some* code and automated passing tests. **0/38 have finished real-game Works/Matches/Surpasses acceptance evidence.** The highest-priority remaining work is not more placeholders: (1) validate client secure/timer behaviors, (2) complete sourced quest/route/dungeon/rare and recipe data, (3) close each raw competitor option row, (4) measure cross-module advantage, (5) verify addon conflicts/taint, persistent settings, memory and CPU in game.

`main` remains untouched. `p1-foundation` is development, **not a release-certified parity build**.

## Feature-request batch A: #8, #11, #9 (2026-11-18)

**AUTOMATED PASS, NEEDS GAME:** [710 Lua passed / 0 failed / 0 syntax errors; 68 Python tests green](https://github.com/LackOfSkillz/OAR/actions/runs/44349318495). New test module: `tests/spec/feature_requests_batch1_spec.lua`. Prior corpse-route tests now explicitly simulate a real ghost state.

- **#8** Shift-only tooltip extras are optional with per-provider visibility and line count caps. No secure behavior changes.
- **#11** Feign Death and false death-like events are vetoed before death history, corpse arrow and graveyard learning. Test genuine WoW Forever Feign Death and resurrection.
- **#9** Item tooltip reverse quest references are indexed across all known quests, not only active quests. The private, Questie-derived pack is **not** in Git. Regenerate using `python tools/import_questie_quests.py --deploy` from the user's local QuestieDB source, then restart the game.

This is an **additional research-feature batch**, not a change to the existing 38-gap acceptance count. The Works, Matches and Surpasses client/competitor gates remain unfulfilled; do not claim launch-ready parity.

## Premium UI rebuild (Claude, 2026-11-18, docs/UI_PREMIUM_PLAN_2026-11-18.md)

**Status: TESTS GREEN / NEEDS GAME.** 721 Lua tests and the companion tests pass. Deployed as build 20261118-153448-72c872a. A /reload is enough. Gary will test after this round. Nothing here is marked WORKS until it's seen in game.

| Area | What changed | Files | Tests |
|---|---|---|---|
| System | Full-width forms with a scroll bar and bottom fade; stat strip block; ON/OFF switches; clean card titles; cards reserve the button column; scroll bars on every list; sortable table widget; one time formatter (`ns.Ago`); coin-icon money (`ns.Prices.Coins`) | UI/Form.lua, UI/Premium.lua, UI/Widgets.lua, UI/WidgetsExtra.lua, UI/Theme.lua, Core/Init.lua | statstrip_spec, table_spec, prices_spec |
| Bugs from the tour | Sidebar highlight follows the page; rare profiles never key on secret spells (rule 4); fishing HUD no longer blocked in combat (rule 5); the game's quest tracker is hidden while ours shows; login notices go to the Feed; Feed collapses repeats; best quests skip red quests and list each quest once; quest completion decided by objectives (fixes "done at 1/5"); arrow moves to the turn-in when a quest becomes ready | UI/Hub.lua, Modules/RareProfile.lua, FishingHUD.lua, QuestTracker.lua, Feed.lua, Finder.lua, QuestObjectives.lua | questobjectives_spec, finder_spec, herbhelper_spec, rarescan_spec |
| Gallery ideas | Quest pin tooltips grouped by NPC (Questie); two-column Vendor/Auction price rows (Auctionator); rare pins coloured by state and a 3D rare portrait in alerts (RareScanner); Journal page (Questie Journey); grouped settings search with ON/OFF (Leatrix) | Modules/MapPins.lua, Prices.lua, RareAlerts.lua, QuestInfo.lua, UI/Toast.lua, UI/Pages.lua, UI/Form.lua | questtooltip_spec, journal_spec, settingssearch_spec, mappinsmenu_spec |
| Pages | Rares (status rows, star, waypoint), Gear (paper-doll), Status (health line and tiles), Tools (groups and error table), Players & guilds (sortable tables), Advisor (three steps), Crafting (three columns), Modules (one block per group), Map (grouped pins), and stat strips on Quests, My characters, Census, Fishing, Feed, Money, Forecasts, Errands, Professions, Waypoints | Modules/RaresTab.lua, Nearby.lua, Census.lua, Advisor.lua, CraftQueue.lua, MapTab.lua, UI/Hub.lua, UI/Pages.lua | rarestab_spec, gearpage_spec, advisorsteps_spec, layers_spec, hub_spec |
| Art | Batch 4 requests for GPT (page pictures, section banners, 21 map pin glyphs, ornaments, empty states). Pins and banners switch to it automatically when delivered | docs/ART_REQUESTS.md, tools/art.py, Modules/MapPins.lua, UI/Hub.lua | — |

**Still open:**
- Chat word chips, Characters cards, the Help topic grid, the Hunter page layout, Census charts higher up, and Settings sub-tabs.
- Map gathering squares need Gary's decision: hide unless you have the profession, or show only when zoomed in.
- Loot strips and price tables need drop and price data.
- Leftover "..." map circles need Gary to hover one.
