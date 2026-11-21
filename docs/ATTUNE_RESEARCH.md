# Attune (CurseForge) research, for the Dungeons module

Gary, 2026-11-21: "I want our Dungeon module to incorporate this level of
information and usability" (Attune, curseforge.com/wow/addons/attune).
Research only: Attune is **All Rights Reserved**, so nothing of its code or
data is copied. Outrider builds its own chains from cited sources (Wowhead's
Forever dungeon guides, Data/Leveling_DungeonQuests.lua) and in-game capture.

## What it is
- Author CixiDelmont. Flavors: Retail, Forever (1.60.1), MoP Classic, Classic, TBC.
- Forever build Attune-Forever-v16001-44, Nov 20 2026; 26 Forever releases since Oct 2026. 14.8M downloads overall.

## What it tracks (Forever build)
- Every dungeon's prerequisite/quest chain: HoT, RFC, RoL, WC, SFK, ES, BFD, CoD, RFK, Gnomer, SM, DC, RfD, KS, Ulda, ZF, AP, Mara, ST, BRD, BH, DM, LBRS, Scholo, Strat; Krol'dok, Alcaz Prison, Blackmaw Hold, The Shaper's Terrace, The Drowned City.
- Keys: Scarlet Key, Dalaran Sewer Key, Tome of Dalaran. UBRS and LBRS attunements. Raids (MC, Onyxia, BWL, Naxx in Classic).
- Class quest chains for every class (e.g. Druid Bear Form 10, Aquatic Form 16; hunter taming chains; Shaman Call of Fire).
- Misc: Aqual Quintessence, Scepter of the Shifting Sands, Cozy/Lazy Sleeping Bag.
- Character progression goals from the character stats (times camped, profession skill).
- Follow-up chains after a dungeon (v44).

## How it shows progress
- Left: collapsible categories (Dungeons, class, Keys, Raids, Misc) with level tags; optional resizable icon grid.
- Main: zoomable flowchart with dungeon art; each node = icon, quest/item name, type (Quest, Pick Up, Turn In, Item, NPC, Required level), zone. Parallel steps side by side with OR markers; ends in Attuned / Not complete.
- Colours: green done (or items held), yellow in log (or some items), grey not started; v44 tints steps done inside a dungeon orange and raid steps red; level text red when you're too low.
- Click a quest: rewards plus a map with the giver. Tooltips: required level, group size (Solo / Party), objective, guild members on this step.
- Completed chains move to a Completed list; "Will not do" hides a chain (and drops it from Next).
- "Attune: Next": a small floating list by level ("13-15 HoT", "Next attune at level 19").
- Own class's quests by default; option for all classes.

## Sharing
- Survey button (guild / party / raid), optional auto survey at logon; Results grid of characters x attunements (check or %), filters, min-level slider, sort by class/level; Export.
- Option: list your alts instead of guild members on each step.
- Settings: minimap button, sounds, step-complete messages, guild announce (off by default), purge results.
- Detection: quests completed / in log, items held, level, reputation, statistics.
- No waypoints or coordinates: a zone name and a map picture.

## Complaints (comments, Nov 2026)
- Wrong or missing Forever chains: RFD needed Agamaggan's Blood; Rot and Regret missing (Maraudon); Zum'rah's Head starts in Mulgore; DC Horde prerequisites; Krol'dok's Eye of Mugg prerequisites.
- Hard to tell quests done before entering a dungeon from quests done inside.
- No reset for a remade character name; the auto survey runs even when off and freezes the game; the guild announce doesn't fire; profession stats read 0.

## Requirements for Outrider (match or beat)
1. Each dungeon, key, attunement and class chain as ordered steps (parallel/OR branches), each step: quest or item, type, giver, zone, **coordinates and a Go button** (Attune has none), required level.
2. Mark where a step happens: outside, inside the dungeon, in a raid (icon + word, not colour only).
3. Status per step from quest completed/in log, items in bags and bank, reputation, level: done / in progress / not started / too low.
4. Scoped to class, race, faction and level; "won't do" hiding; a completed list; follow-up chains.
5. "Next up" sorted by level inside What now (Next steps), plus "unlocks at level N".
6. Alt view: every character's chain progress without logging in.
7. Guild/party sharing opt-in and throttled, never when off; who's on this step; roster grid; GUILD/PARTY/WHISPER only (hard rule 10).
8. Tooltips: group size, objective, rewards, guild members on the step.
9. Every quest, NPC and coordinate verified=false until seen; a way to report a wrong prerequisite (Attune's biggest complaint is bad chain data).
10. Reset per character, quiet by default, completion toasts after combat.

Sources: curseforge.com/wow/addons/attune (description, gallery: 12 screenshots, files and changelogs v16001-19 to -44, comments page 1); us.forums.blizzard.com/en/wow/t/attune-addon-track-your-attunement-progress/883832.
