# Task audit, 2026-11-15

Evidence audit of every TASKS.md entry that is not `[x]` (tasks and gate lines). Read-only. Nothing else was changed.

Sources: `git log` (252 commits), `docs/PROBE_RESULTS.md`, `docs/FOREVER_CONSTRAINTS.md`, `docs/DECISIONS.md`. Also a copy of Gary's `SavedVariables\Outrider.lua` (saved 2026-11-15 08:11, loads 188, 0 errors saved, 600-line log ring) plus two older copies already in the scratch folder (2026-11-13, 2026-11-14). The deployed `Advisor\Advice.lua` was read but not changed. One `mcp__outrider__list_characters` call was made, and `tools/test.ps1` was run (485 passed, companion tests OK).

Rule used: **done** only when in-game evidence matches the task's "Done when". "(equiv.)" means the check was met with different names, because Gary plays Skyborne characters on Zephras Isle (map 2521): Mystmane instead of The Rake, Alchemy/Cooking instead of Leatherworking/First Aid. P8-01 and P9-05 have Done-when checks that are specs only, so specs count for them.

## Proposed: done

| Task | Current | Proposed | Evidence | Still missing |
|---|---|---|---|---|
| G0 | [ ] | done | P0-01..11 all [x]; 49f9e37 "SavedVariables round trip confirmed in game"; PROBE_RESULTS filled | – |
| P1-01 | [ ] | done (equiv.) | SV: Gul-Dukkot "switched off: Ammo, PetStatus, TameHelper" kept across logins; log "login complete: 78/78 modules on", 0 errors | literal Welcome off/on reload test not run (not needed) |
| P1-02 | [ ] | done | SV: 11 char sections, class/race/level right; log "first login greeting shown" (Littlesword 06:35); 85a7db5 "checked on all 8 characters" | – |
| P1-05 | [~] | done | a49a5f0 "one-click Feed works" (secure button); log "queued secure:place until combat ends" + "combat queue ran after combat 1"; autocheck.buttonDone=true | – |
| P2-05 | [~] | done (equiv.) | SV: Khreos + Torrant watch {mystmane=true}, priest Gul-Dukkot watch {} | – |
| P4-02 | [~] | done | log "spellbook: 25 spells via C_SpellBook"; Fight macro built from it casts Mark/Serpent/Arcane in real fights (HunterFight log) | – |
| P5-02 | [~] | done (equiv.) | log "profession Alchemy 30/75: 7 recipes via C_TradeSkillUI", "Cooking 38/75: 8 recipes" | rank-ready alert (extra, not in Done-when) |
| P5-04 | [~] | done | ee850c0 "training button verified (Alchemy 20 -> 30, estimate +10)"; PROBE_RESULTS profession row | – |
| P5-08 | [~] | done | log "session gold -58s 70c: auction house" = 39s + 16s + 80c + 2s 90c buys (PROBE AH buying row) | it was a buying session, not selling; loot value detail |
| P5-12 | [~] | done | SV global.fishing[2521] {6289=90, 6291=154, 6294=2}; moneyLog.fish value 2454 over 4438 s | gear sets, bait reminders (extras) |
| P5-13 | [~] | done | SV: 29 gathered node groups; 72b442a "hollow squares so Find Herbs' live dot shows inside" (pins line up with live dots) | – |
| P6-02 | [~] | done (equiv.) | log "bag upgrade Agile Boots (+86% upgrade (Ranged (levelling)))"; e93a466/d6ecf84 stat-by-stat lines replace `/ride score` | – |
| P6-05 | [~] | done | log "gear pack loaded: 2954 items ..., memory +4413 KB" on first use | dungeon drops (now in the P6 dungeon pack) |
| P6-07 | [~] | done | DECISIONS 2026-11-11 GearQuest entry; Advice.lua item "GearQuest's pick for your waist slot" came from the bridge's in-game data | – |
| P6-08 | [~] | done (equiv.) | SV handoffs: Khreos -> Torrant Elunar Longstaff +59%; log toast "Mail Elunar Longstaff to Torrant" | priest variant not tested |
| P7-06 | [~] | done | 975b36a "Verified in game: unit look (P7-06)"; log "4 health bars flat, 1 art pieces faded, class color hook true"; combat sessions with 0 errors | screenshots not filed |
| P8-01 | [~] | done | Done-when is specs only: dedb883 hardening; 485/485 green 2026-11-15 | real send covered by G8 |
| P9-03 | [~] | done | 2026-11-15: this Claude Code session called `outrider.list_characters` over MCP and got 11 characters with snapshot times | – |
| P9-05 | [~] | done | Done-when is "all safety tests pass": test.ps1 485 passed + 16 companion tests OK (2026-11-15) | – |

## Proposed: superseded

| Task | Current | Proposed | Evidence | Still missing |
|---|---|---|---|---|
| P1-07 | [~] | superseded | widget kit restyled twice from Gary's choices: 6f1542b UI fixes from screenshots, 9301091/f2bf79c Expedition look | approval now belongs to G7 |
| P2-02 | [ ] | superseded | no Data/Rares pack; rares come from the QuestieDB creature pack (D14, d93e555, efc62fd); log "creature pack loaded"; Mystmane measured in PROBE_RESULTS | – |
| P3-08 | [!] | superseded | b65bfe5 "Questie removed from AddOns at Gary's request"; private QuestieDB copy (D10) feeds NPC/quest packs | – |

## Proposed: blocked

| Task | Current | Proposed | Evidence | Still missing |
|---|---|---|---|---|
| P8-02 | [~] | blocked | needs a second Outrider client | second player |
| P8-03 | [~] | blocked | needs a second player in guild/party | second player, under 5 s |
| P8-04 | [~] | blocked | needs a second player in the guild | second player on the map |
| P8-05 | [~] | blocked | needs a second gatherer | second player |
| P8-09 | [ ] | blocked | depends on P8-02..05 | second player |
| G8 | [ ] | blocked | as P8-09 | second player |

## Proposed: keep in progress

| Task | Current | Proposed | Evidence | Still missing |
|---|---|---|---|---|
| P1-03 | [ ] | keep | no "applied profile from" line in any saved log | export/import/copy run; broken-string refusal |
| P1-06 | [~] | keep | log "[selftest] toast shown"; feed holds real toasts | sound heard, drag, position after /reload |
| P1-09 | [ ] | keep | SV global.minimap angle=200, hide=false (button exists) | settings page in Esc > Options > AddOns |
| P1-13 | [ ] | keep | 31-min session 9a826cc7 with 0 errors; restart round trip (P0-07) | needs P1-03, P1-09 |
| G1 | [ ] | keep | as P1-13; Q1 name settled (Outrider) | P1-03, P1-09 |
| P2-04 | [~] | keep | feed "Rare: Mystmane" 11-15 06:19; PROBE "rare alert fired 12:54:53" | toast's Target click; toast screenshot |
| P2-06 | [~] | keep | logs "layer L001", "L003"; sightings carry layers 1, 8, 11, 13 | stable-then-one-change test; C12 still "Reported" |
| P2-07 | [~] | keep | SV sightings: Mystmane 10, 2 others; respawnObs {} | Rares tab after a kill (window or "no data yet") |
| P2-08 | [~] | keep | tame macro verified (3f06c4b, Mystmane tamed) | a tame started from the toast's button |
| P2-09 | [~] | keep | panel seen; a49a5f0 one-click Feed works; stable info happinessLevel=3 | unhappy warning fired once |
| P2-10 | [~] | keep | c6d7786 attack speed on beast tooltips (code) | beast tooltip screenshot; non-beast unchanged |
| P2-12 | [ ] | keep | – | field test: 3+ rares, one-click target/tame, 1 h 0 errors |
| G2 | [ ] | keep | – | as P2-12 |
| P3-01 | [~] | keep | a3e1841 Journey sets marker + arrow; log "world axes ... SWAPPED" | log line naming the backend while a waypoint is set |
| P3-03 | [~] | keep | 704f6a8 Slydris pin moved (pin seen); b78eaa1 map readability fix | toggling a kind hides pins; screenshot |
| P3-05 | [~] | keep | – | click a rare pin (Mystmane/Slydris instead of The Rake), card + Waypoint |
| P3-06 | [~] | keep | SV 127 places (vendor 18, trainer 14, repair 9, mailbox 3, AH 2, bank 1, spirit 1) | Nearest finds a vendor/trainer Gary talked to |
| P3-07 | [~] | keep | 1 spirit healer captured; acb0a49 Home Nearest buttons | death -> spirit-healer waypoint confirmed |
| P3-10 | [~] | keep | Coords module loads | coords shown and match the map; world-map cursor coords |
| P3-11 | [ ] | keep | Slydris Questie point "was in the lake" (704f6a8): one data point | C14 per-zone measurement (Mulgore not visited) |
| P3-12 | [ ] | keep | – | 5 NPC pin checks, near spirit, cards, minimap |
| G3 | [ ] | keep | – | as P3-12 |
| P4-03 | [~] | keep | Macros tab became the Class page (37ada30) | Class page screenshot with greyed entries |
| P4-04 | [~] | keep | SV installed: Fight, Strike, Pet, Cook, Brew, Herb; Fight/Strike pressed (fight log) | Pet key press; `verified = true` set in the pack (only the tame macro has it) |
| P4-05 | [~] | keep | log "best food Red Delicious Stormapple, drink Crisp Spring Water" | food switch after the last stack is eaten |
| P4-06 | [~] | keep | log "rank check (login): 27 spell buttons, 0 old" | trainer visit with a new rank, Fix click; C13 |
| P4-07 | [~] | keep | – | scan macro rebuilt on zone change (Mulgore check is obsolete) |
| P4-08 | [~] | keep | packs validate (specs) | Class page on priest and mage |
| P4-09 | [~] | keep | – | export Khreos macros, import on Torrant (both hunters) |
| P4-10 | [ ] | keep | – | gate |
| G4 | [ ] | keep | – | 5 macros on Torrant + priest, rank fix |
| P5-01 | [~] | keep | SV inventory bags/worn for 11 chars; bank {} for every char | open the bank on two characters; tooltip counts |
| P5-03 | [~] | keep | training shopping bought goods (aa44652, AHBuy log) | queue 5 crafts; tick-off |
| P5-05 | [~] | keep | log "auction house: recorded 8773 prices"; SV 1221 priced items | price lines in an item tooltip |
| P5-06 | [ ] | keep | not started | Favor balance, crate plan |
| P5-07 | [~] | keep | – | post 3 items with suggestions; undercut list |
| P5-09 | [~] | keep | – | sell junk + repair clicks |
| P5-10 | [~] | keep | – | collect mail; COD untouched |
| P5-11 | [~] | keep | fishSession 26 catches / 799 s on key F; efa1208 "the interact key hooks the bobber" | sound settings restored after; DECISIONS note |
| P5-14 | [ ] | keep | – | gate |
| G5 | [ ] | keep | – | shopping across 2 chars, Favor, 15-min fishing |
| P6-01 | [~] | keep | – | spec detection from talents |
| P6-03 | [~] | keep | 0db8cbd/8c1ea09 verdict fixes | screenshot: upgrade, downgrade, future |
| P6-04 | [~] | keep | bag upgrade toasts in log | quest turn-in with choices; highlight matches |
| P6-06 | [~] | keep | log "nearby scan (zone): 10 candidates" | Gary judges 5 entries; one toast not repeated |
| P6-09 | [~] | keep | SV GearSets sets {} | save 2 sets, swap |
| P6-10 | [ ] | keep | – | gate |
| G6 | [ ] | keep | – | 10 items x 2 chars |
| P7-04 | [~] | keep | logs "skinned GameMenuFrame/LootFrame/ContainerFrameCombinedBags/StaticPopup1"; 5bd82f5 parchment fix | before/after screenshots; frames opened in combat |
| P7-05 | [~] | keep | – | player, NPC, beast, item tooltip screenshots |
| P7-07 | [~] | keep | Mystmane nameplate read in combat (probe 06:19) | star on her nameplate, screenshot |
| P7-08 | [~] | keep | log "spell check flagged 'GhostFang'" | URL copy works; screenshot |
| P7-09 | [~] | keep | log "context crafting (no layout assigned)"; SV layouts {} | assign layouts; walk questing -> city -> AH |
| P7-10 | [~] | keep | partly replaced by top-bar search/Finder (c44a928, efc62fd) | queries tried in game |
| P7-11 | [~] | keep | SV feed holds 50 (feedN 367) | Feed page opened, shows them |
| P7-12 | [~] | keep | SV Setup done=true on Gul-Dukkot; false on Littlesword, Khreos | new char sees it once; settings apply |
| P7-13 | [ ] | keep | – | gate |
| G7 | [ ] | keep | – | screenshots sign-off; 1 h session incl. dungeon |
| P8-06 | [~] | keep | errands on Home side cards (74ac962) | accurate list in a city |
| P8-07 | [~] | keep | log "LFG chat tab created" | busy city: highlights + spam collapse |
| P8-08 | [~] | keep | SV respawnObs {} | panel with ranges and counts |
| P9-01 | [~] | keep | snapshots for all 11 chars in SV | **Khreos snapshot has gear {}, money 0, no mapID** |
| P9-02 | [~] | keep | Advice.lua for Torrant present (written 11-11) | Advisor tab shows items; one harmless button |
| P9-04 | [~] | keep | companion wrote Advice.lua (answersSnapshot 1794443553) | advice seen in game after the round trip |
| P9-06 | [ ] | keep | – | gate |
| G9 | [ ] | keep | – | as P9-06 |
| R-03 | [ ] | keep | Q3: releases are public (outrider-releases, 60fcbc7) | Gary's formal Q2/Q3 call (licence) |

## Regressions seen in ticked tasks (not re-rated)

- P1-10 [x]: current snapshots show `map nil` for all characters and Khreos's has `gear {}`, `money 0`. That is weaker than the P1-10 check (mapID + gear IDs).
- P1-11 [x]: logout perf now says "mem 6746 KB live ... WARN over budget: memory" (budget 3 MB; 2.7 MB when ticked).
- P1-12 [x]: GearQuestForever is enabled in AddOns.txt, but login logs "0 addons detected".
