# Player feature requests worth borrowing (2026-11-18)

Gary asked what players have *requested* from other addons that nobody has built yet. There were three research passes:
1. **GitHub issue trackers**: Questie, Polestar, GatherMate2, ItemRack, Details, and the Auctionator family. Auctionator, Baganator, RareScanner, TomTom, Pawn, Postal, Leatrix and the Nova addons have no public tracker.
2. **CurseForge comments** (newest 20 per addon, about Nov 15–18): Polestar, Forever Route, DaylightUI, Social Diary, RareScanner, Quest Companion, MouseOverTooltip, GearQuest Forever, Talents Forever, ForeverPlus, Easy Controller Forever, FrameWorks. Questie, Auctionator, ThreatTint, Deathskip, TurnInXP and Rucksack had no comments to read.
3. **Community**: the WoW Forever Blizzard forums (US and EU). Reddit was blocked for the fetcher, and WoWInterface's request board is dead.

Every idea was checked against `addon/Outrider/Modules/*.lua` and the three gap docs. Anything Outrider has or already plans was dropped. Demand numbers are small (the Forever boards are a week old), so treat them as signals, not votes.

---

## 1. Ideas nobody has built (Outrider-only chances)

| # | Idea | Where it came from | Demand | Why it fits Outrider |
|---|---|---|---|---|
| 1 | **Quest-item drop meter.** Count your own kills and loots per quest item and mob, show "≈ N more kills", and keep Forever-measured rates (opt-in guild sharing) | Forever forums "World of Waiting" (14 likes, many replies, Nov 14–16) and "quest item drop rates" | Loudest complaint of launch week | Questie's drop % is old Classic data and nobody measures Forever. Our own play fills it in (rule 7 friendly) |
| 2 | **Crowd gauge per objective.** Count players seen near each quest's objective area; "contested, do [Quest Y] 400 yd away first" | Forever forums "questing is miserable, layers overcrowded", "30 zones impossible to quest" | Top launch-week complaint, 3+ pages | Combines QuestObjectives, Census and the zone quest list. No addon does this |
| 3 | **Pet XP catch-up.** Mobs that still give *pet* XP, pet XP per hour, kills to the next pet level, best zone for the pet | Forever forums "Hunter pet leveling needs change" | OP 40 likes, 96 on page 1 | Fits Torrant directly. PetStatus already reads pet XP |
| 4 | **Shared or solo drops per quest.** Learn which Forever quests drop the item for the whole party, from party members running Outrider; "group it / solo it" hint | Forever forums, 3+ threads ("group quests changed to not share drops") | Rules changed during beta and aren't documented | Forever-only facts you can only learn in game |
| 5 | **Escort ready-check.** Before an escort, list who can accept it (on quest, prerequisites), warn at 25+ quests in the log (the escort-fail bug) | Forever forums "RFD escort still isn't shareable", "remove escort prerequisites" | 2–3 active threads | Read-only and cheap: IsUnitOnQuest plus QuestieDB prerequisites |
| 6 | **Layer age for camps.** Estimate each layer's age, flag "too young for Humar (~8 h)", camp timers per layer, warn before a merge/refresh | Forever forums "layering effectively disables rare pet taming" | OP 26 likes, 2 pages | The rule-safe answer to the layer-hop addons hunters use now. Builds on Layers, RareTimer, Sightings |
| 7 | **"Ask to group" whisper button.** When another player is killing the same quest mobs, a prefilled whisper Gary sends himself | Forever forums "why does grouping up feel like a penalty" | Ties to #2 and #4 | One click, Gary's click; turns competition into a group |

## 2. Requested from other addons, not built there yet

| # | Idea | Where it came from | Demand | Outrider status |
|---|---|---|---|---|
| 8 | **Shift-gated tooltip extras.** Outrider lines show only with Shift held (option), a toggle per line, a cap ("top 2 drops") | GearQuest Forever comments (~9 people call the tooltip cluttered); CraftInfoAnywhere #2 | **Clearest demand found** | Partial: only combat hide checks Shift. Outrider stacks rare, beast, price, gear and quest lines, so this matters most for us |
| 9 | **Item tooltip "starts a quest (done / not done)" and "used by quest X"**, even when the quest isn't in your log | Questie #2830, #7015, #8052, #7288, #5243 (5 issues, 2021–2026) | Top 10 by reactions | New. The quest pack is already loaded; tells you to keep, sell or bank a drop |
| 10 | **Trainer filter.** Hide talent-locked spells (Forever lists them) and spells you know, including at the pet trainer | Talents Forever comments | 2, Forever-specific | New. TrainShop has no filter |
| 11 | **Feign Death guard on death logging.** Don't count Feign Death or "nearly dead after a big heal" as deaths | Social Diary comments (61 false close calls in a day) | 4+ | New guard. **Needed before the graveyard map learns from deaths**, or hunters spoil the data |
| 12 | **Quest gold requirement** in the tracker, plus an Errands line "need Xg before turn-in" | Questie #3244 | 7 comments, open since 2021 | New (no GetQuestLogRequiredMoney anywhere) |
| 13 | **Pin one objective** (not the whole quest) as the waypoint, plus Shift-click to hide a map icon | Questie #8270, #8214 (Forever-tagged, Nov 2026) | Both top 5 by reactions | Partial: focus-quest exists, per-objective doesn't |
| 14 | **Leftover quest items** flagged after turn-in, with a sell/junk action on your click | Polestar #2534, Questie #5385 | Recent | New |
| 15 | **Preview objectives on the map** from the quest-offer window, before accepting | Questie #8183 | Nov 2026 | New (no QUEST_DETAIL handling) |
| 16 | **"Report wrong spot."** Log "expected here, found there" for quest/POI targets Forever moved (Ancient Egg in Hinterlands, Sunken Temple pointed at Hillsbrad) | Polestar comments | 3 | Partial: POICapture exists. Fits rule 7 (verified=false until seen) |
| 17 | **Party quest-share results and spare items.** Who couldn't take a shared quest and why; "you have 3 spare Goretusk Livers, Bob needs 2" | Questie #6977, Polestar #2566 | 2025–2026 | Partial: PartyQuests shows progress only |
| 18 | **Self buff and consumable bar**, silent in rested areas, choose which aspect/shield per spec | ForeverPlus comments (author plans it) | 3 | Partial (aspect warning exists; no bar) |
| 19 | **Party buff check out of combat.** Who's missing Fortitude, Intellect, Mark, Well Fed | Forever forums "reconsider the addon API restrictions" (19 replies) | Moderate | Partial (self only). Helps the priest and mage alts |
| 20 | **Route danger.** "Detour around Tarren Mill", risky stretches coloured on the route | Polestar #1493 (7 comments, in progress there) | Moderate | New. Travel draws straight legs |
| 21 | **Known and unknown flight masters** in different colours, per character | Questie #6044 | 3 comments | Partial: Travel stores known taxis; pins aren't coloured |
| 22 | **Panels hide until relevant**, with a maximum height and scroll | Polestar comments (top UI complaint there) | 2 | Partial (ContextLayouts). A lesson for all our panels |
| 23 | **"What now" stays in a level band** and scores detours by minutes per XP | Forever Route comments (a player uninstalled over it) | 1 | Partial (WhatNow) |
| 24 | **Daily tracker.** Done today, reset countdown, lifetime count per repeatable | Questie #3176, #5989 | #3 by reactions | Partial (daily tag only). Only matters if Forever has dailies (verify) |
| 25 | **Quest text history.** Accept and turn-in text saved and searchable | Questie #3542 | 4 comments | New, local only |
| 26 | **Lore book pins** with a filter and "already read" hiding | RareScanner comments | 2 | New |
| 27 | **Nameplate range setting.** Forever has no vignettes, so rares are found by nameplates; offer the larger `nameplateMaxDistance` as a setting Gary clicks | RareScanner comments | Several | New. Gary's click changes the setting, never automatic |
| 28 | **Lock/unlock each Outrider frame** separately | DaylightUI comments | 1 | Partial |

## 3. Forever-specific pain points players reported

- **No vignettes on Forever**: rares come only from nameplates, which is why #27 matters.
- **Nameplates vanish until /reload** (2 reports): RarePlates should recover by itself and log it.
- **The gamepad UI taints addon frames** until patch 1.60.2. "Train all" on a controller throws ADDON_ACTION_FORBIDDEN. Avoid hooking the trainer while the gamepad UI is on.
- **Talent-locked spells appear at trainers** (#10).
- **Feign Death counted as death** (#11).
- **Possibly new race/class combinations** ("Skyborne Shaman", "Windshaper", 56 combinations per Forever Route): don't hard-code the Classic class list in data packs. Unverified.
- **Addon messages on custom channels are blocked on Forever** (Forever Bestiary page). Our GUILD/PARTY/WHISPER-only model is fine.

## 4. Popular requests that break our rules, and the safe version

| Request | Seen in | Safe version |
|---|---|---|
| Auto-accept and turn-in quests (dailies only, or "never auto-accept these") | Questie #3165/#4669 (#1 by reactions), ForeverPlus, Forever Route | Highlighted one-click Accept/Complete button |
| Auto-share quests on entering a dungeon | Questie #6978 | "Share dungeon quests (n)" button inside with a group |
| Mount gear (carrot) auto-swap | ItemRack #39, #53 | "Carrot still on" toast plus a one-click swap button |
| Train all in one go | Polestar #1895 | Cost total and one click per confirmed batch |
| Auto-sell/auto-discard junk, auto-buy | Rucksack, ForeverPlus | Sell, Restock and "delete cheapest grey" buttons (built or planned) |
| Layer hopping by auto-invite/leave | Layer-Swap, Forever Layer Hop | Passive layer reading, layer age (#6), "ask guild for layer X" message Gary sends |
| Scrolling combat text, enemy cooldowns, death logs from the combat log | Forever forums API thread | Post-fight `C_DamageMeter` and the death coach (planned) |
| Sending gameplay data to an outside server | Deathskip, Polestar Recorder | Opt-in sharing over guild/party addon messages only |

## 5. Suggested picks

Ranked by value for Gary per hour of work:
1. **#8 Shift-gated tooltip extras.** The clearest demand found, and our tooltips are the most crowded.
2. **#11 Feign Death guard.** Small, and it protects the graveyard map that's being built now.
3. **#9 "Starts a quest / used by quest" on item tooltips.** The data is already loaded.
4. **#3 Pet XP catch-up.** Strongest forum signal, and Torrant's daily need.
5. **#1 Quest-item drop meter.** Unique to Outrider, and it grows into the Forever change log.
6. **#10 Trainer filter**, including the pet trainer.
7. **#5 Escort ready-check** and **#12 quest gold requirement**: both cheap.
8. **#2 Crowd gauge**, then **#6 layer age**: bigger, and unique.
