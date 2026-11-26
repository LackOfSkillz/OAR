# Vanguard researched facts: sources (2026-11-26)

Gary asked for the missing data to be found online and pulled in. It now lives in `addon/Outrider/Data/VanguardFacts.lua`, written as facts in our own words with every row naming its source. Nothing in it is `verified` until Gary sees it in game on WoW Forever (CLAUDE.md rule 7). Original pack data is not changed (data preservation override).

## What was pulled

| Data | Count | Main sources | Kind |
|---|---|---|---|
| Boss mechanic tags (interrupt, dispel by type, purge, crowd control, enrage, second tank, resistances, fear, spread, adds) | 29 dungeons, about 210 bosses | warcrafttavern.com/forever/guides, method.gg/wow-forever/dungeons, forever.warcraftdb.com (3 NPC ids) | "forever" for the 9 new dungeons; "classic" for old dungeons (the guides say their boss text is carried over from Classic) |
| Entry requirements (keys, attunements, wings) | 30 places | conquestcapped.com attunements and Dalaran guides, bald.gg, tentonhammer.com, warcraft.wiki.gg (Heart of Disruption), Blizzard raid overview | forever |
| Raids: size, status, boss names | Barrow Deeps (10), Hyjal Summit (20), Onyxia's Lair (40); ZG, AQ20, MC, BWL, AQ40, Naxx marked "not announced for Forever" | Blizzard raid overview (worldofwarcraft.blizzard.com/news/24303009) and roadmap; warcraft.wiki.gg for datamined boss names | forever |
| Vendor buy prices | 40 items (water, bread, meat, arrows, shot, class reagents) | Wowhead Forever item tooltips | forever |
| Enchant ids and stats | 63 flat-stat enchants, 16 proc or weapon-damage enchants | Wowhead Forever spell pages | forever |

## How Outrider uses it

- **Boss matrix:** each boss gets checks for the needs a class can answer (interrupt, dispels, purge, crowd control, tranquilizing shot for enrages), labeled with the guide and whether it's a Forever or Classic source. Other needs (fear, a second tank, resistances, spread, adds) show as "watch:" notes, never scored. Your own `/ride vgboss` rule replaces the guide's for the same need. When a guide lists the bosses, that list is the boss list; the dungeon pack's other named mobs with loot are counted in a note, not shown as bosses.
- **Access:** a key one member can hold (Scholomance, City of Dalaran) is met when you carry it and unknown when you don't (someone else may); an attunement everyone needs (Onyxia's Drakefire Amulet) is a must-have you either carry or don't. A disputed one (Krol'dok Stronghold) waits for your answer. Wing keys (Scarlet Monastery Armory and Cathedral, Dire Maul West and North, Upper Blackrock Spire, Stratholme service gate) are shown as notes; the place itself is open.
- **Prices:** buying food, drink, ammo or reagents now shows a cost (what's missing × the vendor price), labeled "check the vendor". A price still not in the table stays unknown, never free.
- **Gear stats:** a known flat enchant adds its stats; a proc or weapon-damage enchant, or one not in the table, keeps the total "at least".

## Conflicts and doubts (kept, not resolved by guessing)

- City of Dalaran: one source says Alliance needs no key; others say both factions need the Sewer Key.
- Krol'dok Stronghold: sources disagree whether the Compound Key is needed to enter (marked disputed).
- Upper Blackrock Spire: the Seal of Ascension id is 12344 per one source; another says the item isn't in Forever data yet.
- Barrow Deeps: Blizzard says 10 players, one wiki line says 20. Boss names for Barrow Deeps and Hyjal are datamined and their order is unconfirmed.
- Enchants: Forever changed several Classic enchants (chest Health became Stamina, Mana became Intellect, amounts went up, some ids moved above 8000), so the table uses only Forever values.
- Prices: food and drink read as per item and ammo per 200; batch sizes aren't in Forever's data.
- Some dispel types and resistances are our reading of an ability; those reasons say "(our guess)" or "(type not stated)".

## Not found

Boss NPC ids for most bosses; recommended raid makeups (no source publishes tank and healer counts for any Forever raid); requirements for raids not announced on Forever; new Forever-only enchant ids (bracer agility tiers, necklace enchants).

## Blocked sites

mobalytics.gg, icy-veins.com, theclick.gg and metaforge.app refused automated reads (HTTP 403), so nothing comes from them.
