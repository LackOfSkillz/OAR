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

## Open questions for Gary

| # | Question | Options | Recommendation | Needed by |
|---|---|---|---|---|
| Q2 | Personal use or public release | personal / friends via zip / public on CurseForge and Wago | Personal first, decide at the end of P3 | P3 gate |
| Q3 | License | GPLv3 / MIT / all rights reserved | GPLv3 if we ever study or reuse GPL addon code; MIT if everything is original | Before any public release |
| Q4 | Visual direction for Phase 7 | Clean dark (default theme) / Classic gold trimmed / Minimal | Claude makes mockups in P7-01 | P7 |
| Q5 | Guild sharing on by default for guildmates who install it | yes / opt-in | Opt-in per character | P8 |

- 2026-11-11: Questie and QuestieDB were removed from AddOns at Gary's request. The importers read the saved zip in private/questie-source; Outrider runs without Questie (D10 holds).
