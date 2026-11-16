# Outrider: one addon for WoW Forever

One character-aware addon for World of Warcraft Forever instead of ten. It knows which character you're on (class, race, level, professions, gold) and shows only what applies to that character. It works on its own: no Questie, TomTom, Auctionator or TSM needed (if they're installed, Outrider uses their data or steps aside).

Built by Claude Code on Gary's PC and tested by Gary in game. Every action in the game is a key press or click by the player; Outrider never plays for you.

## Install (players)

1. Close World of Warcraft.
2. Download **Install-Outrider.cmd** from the newest release: https://github.com/LackOfSkillz/outrider-releases/releases/latest
3. Double-click it. It finds WoW Forever and installs Outrider with all its data (if Windows warns, click **More info**, then **Run anyway**).
4. Start the game, log in and type `/ride`.

**Updates:** double-click **Update Outrider** on your desktop (WoW closed). In game, Outrider tells you when your build is two weeks old or another Outrider user has a newer one.

A new install also gets Gary's shared world knowledge (NPCs met, places, gathering spots, rare sightings, prices). It's merged once and never overwrites what you've collected. It holds no character names, gold or logs.

## What it does

Open the hub with `/ride` (or the minimap button). Pages are grouped in the sidebar; Home shows the nearest places, where you're headed, best quests, upgrades, rare watch, errands and your pet.

**Rares and hunters**
- Rare alerts from nameplates, target, mouseover and minimap markers: sound, red screen-edge flash, arrow to the exact spot, Pull/Tame button.
- Watch list, sightings per layer, spawn log at a rare's spot (what spawns there, in what order), rare profiles (level, attack speed, spells).
- Tame macro, pet panel (one-click Feed, diet learned per family, DPS, attack speed, XP), beast attack speed on tooltips, ammo warnings with the nearest ammo vendor.
- Fight macro written from your spellbook and weapon, rewritten out of combat when you learn a spell.

**Maps and travel**
- Waypoints with an arrow, coordinates, quest givers colored by your level, service NPCs, flight paths, rare spawn spots, herb, ore and fishing spots (picked nodes dim for 15 minutes, nodes seen up show green).
- Finder: search gear, items, quests, rares, creatures, NPCs and places. Journey: best quests anywhere and the quickest route, including flights, boats and portals.

**What now?**
- The next 3 to 5 steps worth doing, picked for your goal (level up, gold, gear, professions, explore, a bit of everything) from your quests, gear, dungeons, training, rares, gold methods, gathering and errands. Each says why and where, with Go, Details, Not useful and an alternative. Unchecked data is labelled.

**Dungeons**
- Dungeons page: which dungeons fit your level now, the upgrades for you in each, the next tier, an arrow to the entrance, and a ready check (repairs, food, bag space, ammo).
- Loot roll advice on the item tooltip: Need, Greed for one of your alts, Greed or Pass. You still click the roll.

**Professions and gold**
- Training button for every crafting profession: one key makes what still gives skill. For cooking it makes the campfire, places it and cooks (never a second campfire).
- Fishing: one key to cast and hook (auto loot), lure applied on the same key, a HUD with skill, lure timer, what bites here, silver per hour, and rare catch sounds.
- Auction house: one panel with **Training** (ingredients and recipes, ranked by cost per skill point), **Weapons** (top 10) and **Armor** (best per slot). Only what your class and skills can use, never above the gold you carry, stat-by-stat comparison and an overall change. Buying is one confirmed click per item. **Scan all prices** gives you prices without other addons.
- Money guide by level, professions and faction, learning your own gold per hour. Gold ledger, merchant panel (sell junk, repair), mailbox collect, inventory across characters.

**Gear**
- Tooltip verdicts weighted for your class, best quest reward, bag upgrades, gear sets, nearby upgrades and where to get them.
- Gear for alts and family: upgrades you loot are offered to your alts first, then family and friends, then other Outrider users, with the mailbox address filled in.

**Interface and sharing**
- Notification feed, chat highlights and spam filter, URL copy, spell check, command bar, errand list, a cleaner skin that steps aside for ElvUI and similar addons.
- Sharing with other Outrider users is **off by default**. When switched on: version hello, rare sightings, gathering spots, gear cards and (separately) your map position, over guild, party, raid or whisper only.

## Safety and privacy

- No automation: every cast, target, buy and craft comes from your key press or click.
- No combat log reading and no protected frame changes in combat.
- Nothing leaves your PC except addon messages for the sharing features you switched on. The updater only asks GitHub for the newest release.

## Data and licence

The NPC, gear, creature, node and dungeon data packs are converted from [QuestieDB](https://github.com/Questie/Questie) and shared under GPLv3 (`gpl-3.0.md` and `LICENSE-DATA.txt` in each data folder). Outrider is not made by or affiliated with the Questie team. New-in-Forever game data is captured in game and stays marked unverified until checked on WoW Forever. Outrider's own licence is still open (docs/DECISIONS.md, Q3).

## Developers

- `CLAUDE.md`: the rulebook (hard rules, the build, test and deploy loop, commands). Read it first.
- `TASKS.md` and `phases/`: the engineering plan, Phase 0 to 9, with acceptance checks.
- `docs/`: architecture, Forever constraints, probe results, conventions, data formats, the test loop, decisions.
- `addon/Outrider/`: the addon. `addon/Outrider_Data_*` and `private/Outrider_Data_*`: data addons (the private ones are built from a local QuestieDB copy by `tools/import_*.py`).
- `tests/`: 466 specs that load the addon in a fake WoW client. `tools/test.ps1` runs them.
- `tools/`: deploy, log reader, screenshots, SavedVariables backup, `family.ps1` (one-file installer) and `publish.ps1` (public release).

First-time setup on a new PC: double-click `Setup.cmd` (installs Git, the GitHub CLI, Python with lupa for Lua 5.1 tests, and Claude Code; finds WoW), then run `claude` in this folder and say `Read CLAUDE.md`. Recommended in game for error capture: BugGrabber and BugSack.

In-game commands: `/ride` hub, `/ride help` everything, `/ride status` character and save state, `/ride errors` Outrider errors.
