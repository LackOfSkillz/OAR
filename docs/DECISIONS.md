# Decisions

## Made (with reasons)

| # | Decision | Why | Date |
|---|---|---|---|
| D1 | One addon with switchable modules, not a bundle of separate addons | One settings model, one UI, no addon conflicts; modules still off by default where another addon does it better | 2026-11 |
| D2 | Hook Questie, TomTom, Auctionator/TSM, GearQuest instead of copying them | They hold large maintained datasets; copying means maintaining it forever | 2026-11 |
| D3 | Skin Blizzard frames (Phase 7) instead of replacing them; step aside for ElvUI/EllesmereUI | Replacing unit frames and bars is where taint and breakage live | 2026-11 |
| D4 | Account-wide SavedVariables with per-character sections | Cross-character copy, inventory totals, single file for the companion app | 2026-11 |
| D5 | Self-building data (discovery mode) plus small verified packs | Forever redrew zones; old Classic coordinates can't be trusted | 2026-11 |
| D6 | No automation; advice never acts | Blizzard ToS; Gary's account | 2026-11 |
| D7 | AI advisor parked until Phase 9; snapshot and advice loader shipped dormant | Don't hold up the core; make the later step cheap | 2026-11 |
| D8 | Name: **Outrider** (was the working name OAR). Globals and frames `Outrider_*`, internal messages `OTR_*`, export strings `OTR1:`, slash `/outrider` and `/ride` | A scout who rides ahead, spots what is coming, maps the land and reports back; fits every class; no CurseForge collision found on 2026-11-11 (Lodestar, Wayfarer, Vigil, Kindred, Hearthside were taken) | 2026-11-11 |
| D9 | Place data: flight points come from the client (`C_TaxiMap`, every node on the zone map, verified); Questie's NPC database is read at runtime if Gary installs Questie (hook, never copied, zones Forever left unchanged only); discovery covers Forever's new and redrawn zones and confirms the rest. No bulk import from Wowhead or fan sites | Classic databases lack Forever's new zones (map 2521) and redrawn Mulgore; copying third-party data raises licence questions; the client's own data is exact | 2026-11-11 |
| D10 | Questie data: Gary chose a **private copy** (2026-11-11). A tool extracts service NPCs from QuestieDB into a separate, git-ignored data addon that stays on Gary's PC and out of any public release; Outrider loads it only if present and never needs Questie. Questie and QuestieDB v12.6.5 (official GitHub release, Forever interface 16001) were installed into AddOns with Gary's explicit OK, a one-off exception to hard rule 2 | Gary wants Questie's data without depending on Questie; its licence only allows copying under GPLv3 and is unclear for old contributors, so the copy stays private until the licence question (Q2) is settled | 2026-11-11 |
| D11 | Our own data addons `InterfaceAddOnsOutrider_Data_*` may be written by their generator tools (e.g. `py tools/import_questie.py --deploy`), in addition to `Outrider` via deploy.ps1. Installing anyone else's addon still needs Gary's OK each time | The private NPC pack (D10) is a separate load-on-demand addon so Outrider never depends on it | 2026-11-11 |
| D12 | Chat spell check uses the SCOWL / English Speller Database size-60 list, US + GB spellings, downloaded once from app.aspell.net with Gary's OK and built by `tools/build_words.py` into the load-on-demand addon `Outrider_Data_Words` (kept in the repo with its LICENSE.txt; deploy.ps1 copies `addon/Outrider_Data_*`) | Gary chose "Full list" and "Both" spellings; the licence allows redistribution with the copyright notice | 2026-11-11 |
| D13 | Gear sources (P6-05) come from the same private QuestieDB copy (D10) through `tools/import_gear.py`, into the load-on-demand addon `Outrider_Data_Gear` (git-ignored, deployed with `--deploy`, never released). Only sources are copied (quest, vendor, named drop with positions); stats are read in game. Dungeon drops are missing until Questie dungeon areas map to client maps | Spec asked for a gear pack from cited sources; Questie is the cited source Gary already approved | 2026-11-11 |
| D14 | Creatures and rares for the Finder come from the same private QuestieDB copy (D10) through `tools/import_mobs.py`, into the load-on-demand addon `Outrider_Data_Mobs` (git-ignored, deployed with `--deploy` per D11, never released): hostile NPCs with level range, rank and up to 4 spread spawn points per map | Gary asked for a finder over "available data, not only places I know" (2026-11-13) | 2026-11-13 |
| D15 | Herb and ore spawns come from the same private QuestieDB copy (D10): its Forever objects carry every herb and ore node with spawn points in Forever's own areas (Zephras Isle included). `tools/import_nodes.py` writes the load-on-demand addon `Outrider_Data_Nodes` (git-ignored, deployed with `--deploy` per D11, never released). GatherMate2's Classic dump was not used: no licence, 2019 coordinates, and Questie already had Forever data | Gary asked to pull the node map into Outrider (2026-11-13) | 2026-11-13 |
| D14 | Visual direction: **Clean dark** (flat dark panels, 1px borders, blue accent; the existing Theme.lua tokens) | Gary picked it from the three-way mockup (Clean dark / Classic+ / Minimal), 2026-11-11 | 2026-11-11 |
| D15 | Fonts: keep the game font (Fonts\FRIZQT__.TTF); no bundled font, so no font licence to carry. Textures stay WHITE8x8 (own flat bars and 1px borders), registered with LibSharedMedia when it is loaded | Gary chose "Keep the game font" over Inter / Roboto Condensed, 2026-11-11 | 2026-11-11 |
| D16 | Companion app (P9-03) in Python, standard library only (Gary chose Python). It reads Outrider.lua as plain data (never executed) and may write exactly one file, `Interface\AddOns\Outrider\Advisor\Advice.lua`, as the P9 design says; that is the one planned exception to "only deploy.ps1 writes there". Off until companion/config.json says enabled; no network | Gary picked Python, 2026-11-11 | 2026-11-11 |
| D17 | Advisor model: Claude in the Claude Code app (Gary chose it over a local model). The companion is a project MCP server (`.mcp.json`, `py -I companion/run.py`); `/advise` (.claude/commands/advise.md) tells Claude how to read the snapshot and write advice. No API key, no extra install; companion/config.json enabled on this PC. Watch mode (ask automatically on every snapshot) is not used: Gary asks with /advise | 2026-11-11 | 2026-11-11 |

## Open questions for Gary

| # | Question | Options | Recommendation | Needed by |
|---|---|---|---|---|
| Q2 | Personal use or public release | personal / friends via zip / public on CurseForge and Wago | Personal first, decide at the end of P3 | P3 gate |
| Q3 | License | GPLv3 / MIT / all rights reserved | GPLv3 if we ever study or reuse GPL addon code; MIT if everything is original | Before any public release |
| Q5 | Guild sharing on by default for guildmates who install it | yes / opt-in | Opt-in per character | P8 |

- 2026-11-11: Questie and QuestieDB were removed from AddOns at Gary's request. The importers read the saved zip in private/questie-source; Outrider runs without Questie (D10 holds).

- 2026-11-11: P6-07 GearQuest bridge skipped: GearQuest Forever is not installed on Gary's PC. If he installs it, check for a public API and add a read-only bridge.
- 2026-11-11: GearQuest Forever v1.1.3 installed at Gary's request (zip kept in private/gearquest-source). Its licence is All Rights Reserved, so Outrider only reads its global table in game (GearQuestBridge) and never copies its data. Outrider's nearby-upgrade toast yields to GearQuest's own toasts.

- 2026-11-12 (Claude): thrown weapons are never a hunter upgrade (Auto Shot and hunter shots need a bow, gun or crossbow). Rule from Classic; check on Forever if Gary ever wants thrown for a hunter.
- 2026-11-12 (Claude): hunter Fight macro is a priority list, not logic. A macro can't read cooldowns or debuffs, so line order decides: melee strikes before shots (range makes one set fail), once-per-target spells as `/castsequence reset=target X,null`, Serpent Sting `reset=15/target`. Created only from Gary's click, then kept current automatically (it is our own macro). Unverified on Forever: that a failed line falls through to the next, and the reset=15 timing; the per-fight cast log checks both. Blizzard's own one-button rotation (C_AssistedCombat) is in the probe; if Forever has it, it's an alternative.
- 2026-11-12 (Claude, Gary had no preference): hunter macros split into Fight (ranged) and Strike (melee), two keys, because Forever allows one spell attempt per press and a macro can't see range (C16b). Supersedes the one-key design above.

## One-press profession macros (2026-11-12, Claude, Gary asked)
- "Cook", "Brew", "Herb" macros run `/ride make <Profession>`. One press = one `C_TradeSkillUI.CraftRecipe(id, all you can make)`, the same as Blizzard's Create All button, only from Gary's press (hard rule 1).
- Picks the learned recipe you have every reagent for, best skill-up colour first (orange, yellow, green, grey last). Grey is still made when nothing better is possible, because Gary asked for "whatever you have ingredients for".
- The window opens on the first press if it is closed (`OpenTradeSkill` with the skill line from `GetProfessions`, no typed-in IDs); crafting needs the window loaded, so that press may only open it.
- Herbalism in Classic is gathering only; its macro says "no recipes" unless Forever gives it recipes. Unverified on Forever.
- Cooking is not in GetProfessions on Forever (measured 2026-11-12: /ride make made Brew and Herb only); Crafter also counts professions whose window was opened. Herbalism's window lists 196 gathering entries, nothing craftable.

## Herbalism helper (2026-11-12, Gary asked to borrow from herbalism addons)
- Looked at GatherMate2 (node map + Wowhead data import) and the skill-tooltip addons (Can I Gather It?, GatherSkillTooltip, NodeInfo). Borrowed ideas only: no code (licences not checked) and no imported node data (Classic coordinates are wrong on Forever, hard rule 7).
- Built: Find Herbs off reminder (once per session), pin a node on mouseover (not only after gathering), object tooltip lines logged to learn Forever's wording.
- Not yet: required-skill line on herb tooltips. Needs a cited skill table (Icy Veins blocked the fetch) or Forever's own tooltip text; the logged tooltips decide which.

## Journey: best gear and XP quests anywhere, with a route (2026-11-13, Gary)
- Gary's choices: travel data from guides + learning; XP ranked by XP per minute; a new Journey hub tab.
- Travel graph: walk on one continent (7 yd/s), fly between flight points this character knows (30 yd/s + 20 s), rides from Data/Transports.lua (guides, zones by name, docks only where cited) plus rides learned from loading screens that were not a flight, teleport, hearthstone or death. All times are estimates for ranking.
- The guide re-plans from where Gary stands after each leg (arrival, landing, loading screen, new zone), so it never needs a step counter and fixes itself after a detour. Flights and rides are Gary's to take; the guide names them once in chat.
- Quest XP is not in the pack: estimated from quest level (1.5 q^2 + 55 q + 120), cut for quests 6+ levels below like Classic. Red and grey quests are left out.
- Zephras Isle (Alliance): the only listed exit is the Valanaar skycutter, first ridden in The Magical City of Dalaran. Until a ride off the isle is known, off-island targets show "no known way yet".

## Finder (2026-11-13, Gary: "feature-rich map, searchable and sortable, use available data")
- Journey tab = Finder: search box, kinds (All, Gear, Items, Quests, Rares, Creatures, NPCs, Places), Sort button cycling nearest / XP per minute / most XP / best gear / your level / name / zone. Each kind opens on its most useful sort.
- Sources: gear and item packs (D13), NPC pack quests and NPCs (D10), creature pack (D14), plus what Gary met (Discovery, POIs, gathering nodes, marked "seen").
- To stay quick, "All" without a search shows gear, quests, rares and places; creatures show around your level unless searched; the whole NPC pack only when searching. Up to 300 rows shown.

## Hub redesign: everything in the window (2026-11-13, Gary)
- Gary's choices: grouped sidebar, dark look with the class color as accent (now the default; Settings can turn it off), resizable window (860x520 to 1400x1000, saved per character).
- Sidebar groups: Home; Explore (Journey, Map, Waypoints, Rares, Rare alerts); Character (Hunter for hunters, Gear, Gear sets, Professions, Crafting, Macros); Town (Errands, Forecasts, Feed); Social (Chat, Sharing); Outrider (Settings, Modules, Characters, Advisor, Status, Tools, All commands).
- Controls run the same code as the typed command (UI.Run -> ns.Slash:Run), so a button and a slash command can never behave differently. All commands lists every /ride command with a box for its arguments, so nothing needs the chat line.
- The top bar's search box opens Journey with that search. Home opens first.

## Suggestions suit the character (2026-11-13, Gary: race, level, faction and class aware, all classes)
- Quests: faction, class mask, race mask (new 9th pack field from Questie's requiredRaces; bit = raceID from UnitRace) and level, everywhere quests are suggested (Finder, Journey, quest pins, zone report).
- Zones (new Finder kind): maps with quests open to this character at green-to-orange level, so the other faction's zones never appear.
- NPCs and places: Discovery now stores each NPC's faction; the Finder hides NPCs and places of the other faction (NPC's own faction, else the NPC pack's, else the finder character's). Neutral ones show for everyone.
- Gear: faction and level in Nearby, class (armor, weapons, stat weights for all nine classes) in GearScore. Herbs: the guide's skill vs yours.
- Class tools: macro library packs exist for all nine classes; the Fight/Strike/Pet rotation generator is hunter-only so far.

## Class aware everywhere (2026-11-13, Gary: "dynamic, relevant to the character being played")
- One Class page per character, named and iconed for its class (Hunter, Mage...). It shows only that class's sections: Fight macros (hunter, mage, priest so far), hunter-only taming, pet and ammo, and a link to the class's macro library.
- Fight macros are data-driven per class (Modules/HunterFight.lua keeps its file name): HUNTER Fight/Strike/Pet, MAGE Fight (Frostbolt, else Fireball) and Strike (Frost Nova, Fire Blast, Arcane Explosion), PRIEST Fight (Shadow Word: Pain once per pull, Mind Blast, Holy Fire, Smite) and Heal (best heal on mouseover, friendly target or you). Mage and priest orders are unverified until their fight logs are read.
- Other classes' modules are hidden on the Modules page; Home shows the pet card only for classes with a pet; Professions shows only professions the character has.

## Hunter Fight order follows the guides (2026-11-13, Gary chose "guide order")
- Researched: warcrafttavern.com Forever hunter guide (BM: Aspect of the Hawk, Auto Shot with the pet sent in, Serpent Sting, Arcane Shot on cooldown; Wing Clip/Concussive when the pet loses threat), Classic/Forever leveling guides (Mark first; Serpent only when the mob lives long enough).
- Fight is now: pet in every press, Aspect of the Hawk before the pull, Hunter's Mark, Auto Shot, Serpent Sting, then Arcane Shot on cooldown. Concussive left the spam key (off by default; the Class page toggle puts it back after Mark). Distracting Shot stays out (pulls the mob off the pet).
