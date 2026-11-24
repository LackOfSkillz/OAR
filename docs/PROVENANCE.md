# Provenance manifest

Every input Outrider ships or builds from, with origin, rights, revision and notices. Kept by
OI01-05 (2026-11-24); update it when a pack, importer or asset changes. This is an engineering
record, not legal advice.

> Owner directive 2026-11-24 ([data preservation override](blueprint/OWNER_DIRECTIVE_DATA_PRESERVATION.md)): this file is a record only.
> No data is removed, moved or redacted because of anything here, and no removal is proposed.

Risk column: informational labels from the 2026-11-24 audit; they carry no action.

## Shipped in the addon folder (`addon/Outrider`)

| Input | Origin | Rights / notice | Revision | Risk |
|---|---|---|---|---|
| Lua code, UI, Advisor | Written for Outrider | GPLv3-only (LICENSE, COPYRIGHT.md, D20) | git | low |
| Art (`Art/`, 192 files) | Made by Gary with image generation | Gary's; no Blizzard art or logos | git | low |
| Fonts, icons, map tiles | WoW client, referenced by path or fileID | Not redistributed | client 1.60.1 | low |
| Data/MapOverlays.lua | WoW Forever client tables via wago.tools (fetched with Gary's OK 2026-11-17) | Blizzard game data; only fileIDs and rectangles, used inside the game | build 1.60.1.70938 | low |
| Data/SpellInfo.lua | foreverchanges.pro class spellbooks (built from the live client) | Facts (spell names, ranks, levels), source cited in file | 2026-11-19 | low |
| Data/Dungeons.lua | foreverdb.net and Wowhead Forever dungeon guides | Facts (level ranges), cited | 2026-11-14, 2026-11-21 | review (W) |
| Data/Leveling.lua, Leveling_Places.lua, Leveling_Facts.lua, Leveling_DungeonQuests.lua | Wowhead WoW Forever guides, read in a browser (D-entry at DECISIONS line 197) | Facts (NPC names, zones, coordinates) with the guide named per entry; short notes in Outrider's words | 2026-11-19 to 2026-11-21 | review (W) |
| Data/Talents.lua, TalentCards.lua | wowhandbook.com (client 1.60.1.70959) and rankedboost.com build pages | Talent point orders (facts), cited per entry | 2026-11-16, 2026-11-23 | review (W) |
| Data/Macros_*.lua, ComboKeys.lua, FightPlans.lua | Patterns from community macro guides (Rankedboost, Kami-Labs, Almar's), written by Outrider | Macro syntax is functional; explanations are Outrider's own words | 2026-11-18 | low |
| Data/Fishing.lua, Herbs.lua, Money.lua, Transports.lua | Community guides (wow-professions.com, others named in each file) | Facts in Outrider's own words, cited | 2026-11-12 to 2026-11-17 | low |
| Data/Rares.lua, Registry.lua | In-game discovery and Warcraft DB page titles (npcIDs) | Facts, cited; `verified=false` until seen | 2026-11-15 | low |
| Data/StatWeights.lua | Community stat-weight guides named in the file | Numbers, cited | | low |
| Modules/GearQuestBridge.lua | Reads the installed GearQuest addon at runtime | GearQuest is All Rights Reserved: nothing copied or saved | n/a | low (read-only) |

## Separate data addons

| Addon | Origin | Rights / notice shipped | Revision | Risk |
|---|---|---|---|---|
| Outrider_Data_Words | SCOWL size 60 (Kevin Atkinson) | its own LICENSE.txt | SCOWL 2026 | low |
| Outrider_Data_Trails | Gary's own characters' walked paths (D24) | GPLv3, original | 2026-11-21 | low |
| Outrider_Data_NPC, _Mobs, _Nodes, _Dungeons, _Quests, _Reagents, _Paths (git-ignored `private/`, built by `tools/import_*.py`) | QuestieDB `0f7d8adc92b2` | GPLv3: LICENSE-DATA.txt + gpl-3.0.md added by `Add-OarDataLicenses` | QuestieDB 0f7d8adc | low (see note Q) |
| Outrider_Data_Gear, _Travel | QuestieDB + ForeverDB `641b78f3d45d8d2d` (incl. Shortest Path Forever GPLv3+, Drop Tables CC BY-SA 4.0, pfQuest MIT) | GPLv3 notice and credits in LICENSE-DATA.txt | ForeverDB 2026-11-23 | review (M) |
| Outrider_Data_Crafting | WoW Forever client tables (wago.tools, build 1.60.1.71037), AllTheThings (MIT), ForeverDB | GPLv3 notice; **AllTheThings' full MIT LICENSE now shipped as LICENSE-AllTheThings.txt** (OI01-05) | 2026-11-23 | low |

Distribution: `tools/curseforge.ps1` and `tools/package.ps1` build the zips. Pack sources are published in
`LackOfSkillz/outrider-releases` (D21, D23).

## Notes (informational, no action)

- Guide-derived facts (W): the leveling, dungeon and talent packs cite Wowhead, wowhandbook and
  rankedboost per entry. They are kept as they are.
- pfQuest credit (M): the credit line ships with the ForeverDB-derived packs.
- QuestieDB contributor caveat (Q): the upstream notice link ships.
- `private/Outrider_Data_Gear/Data.lua` still has its old "private copy" header text; it is left as is.
- No GearQuest database is imported, extracted or shipped; `warcraftitems.json` is never read.
