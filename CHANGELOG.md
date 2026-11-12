# Changelog

## Unreleased

- Hunter **Fight** macro: one key to spam. Outrider writes it from your spellbook and ranged weapon and rewrites it out of combat when you learn a spell, level up or swap the ranged weapon. Install it once from the Macros tab or `/ride fight`; `/ride fight concussive|wingclip|pet off` trims it. Each fight's casts are logged so the order can be checked.
- Gear advisor: thrown weapons are never a hunter upgrade; the empty-slot line names the slot.

## 0.3.0 (2026-11-11)

Most of this is built and tested in the mock client but still waits on an in-game check (see TASKS.md, items marked [~]).

- Rares: nameplate, target and mouseover scanning, alerts with a Pull/Tame button, watchlist, sightings per layer with respawn windows and forecasts, Rares tab, star over a rare's nameplate, tame and scan macros, pet panel (secret health and focus shown raw), ammo warnings.
- Maps: waypoints, coordinates, places learned from NPC windows and titles, flight points from the client, world map and minimap pins with cards and a legend, /ride near, spirit healer waypoint on death, quest givers colored by your level (done, too high and grey quests hidden), minimap kept readable (12 nearest, clear centre).
- Optional private data packs built from a local QuestieDB copy (never released): service NPCs and quests, gear sources. Outrider runs without them and without Questie.
- Macros: engine, library tab with a safe installer, packs for all nine classes (unverified), rank check with one-click fix, food and drink placeholders, export and import.
- Professions and gold: inventory across characters, professions, craft queue and shopping list, skill-up planner, prices from your own AH history, auction helper panel, gold ledger, merchant panel (sell junk, repair), mailbox collect, fishing on one key, catch log, herb, ore and fishing spots.
- Gear: stat weights and tooltip verdicts, best quest reward, bag upgrades, gear sets, alt handoffs, Gear tab with nearby upgrades, GearQuest Forever picks when it is installed.
- Interface: notification feed, chat highlights and spam filter, URL copy, copy chat, spell check (SCOWL word list addon, US and GB), command bar (find anything, key binding), town errand list.
- Sharing (all off by default): version hello, rare sightings, gathering spots, over GUILD/PARTY/RAID only.
- Safety and quality: combat log never touched, secure buttons never anchored to our frames, unregistrable events logged quietly, memory budget 3 MB with map places built on demand, 300+ specs.

## 0.2.0 (renamed to Outrider, 2026-11-11)

- The addon is now **Outrider** (was the working name OAR): folder `addon/Outrider`, `Outrider.toc`, SavedVariables `Outrider_DB`, `Outrider_Log`, `Outrider_Snapshots`, advice global `Outrider_Advice`, global handle `Outrider`, frames `Outrider_*`, internal messages `OTR_*`, export strings `OTR1:`, slash commands `/outrider` and `/ride`.
- Done before the first deploy, so no saved settings needed migrating.
- Tools follow the new name (deploy target `AddOns\Outrider`, SavedVariables file `Outrider.lua`, release zip `Outrider-<version>.zip`).
- HANDOFF.md added for the switch from the chat to Claude Code on Gary's PC.
- Entries below this one use the old name.

## 0.1.1 (review fixes, 2026-11-11)

- DB: migrations run on a copy; a missing step, a failing step, or a file from a newer OAR now puts the session in safe mode (saved file left untouched, temporary settings in memory) instead of silently continuing.
- Resets rebind the live settings immediately; reset all writes nothing back.
- Combat queue: capped at 100 jobs, `Combat:Cancel(key)`, and a module toggle queued in combat re-reads the wanted state when it finally runs.
- Advice loader: IDs must be positive integers, coordinates finite 0..1, panels from a whitelist, waypoint maps must exist on this client, WoW escape codes stripped from text, every item carries a confidence (verified / community / inferred / unknown).
- Data packs: optional `confidence` and `verifiedOn` provenance fields, validated.
- 11 new specs (71 total).

## 0.1.0 (build package, 2026-11-11)

- Core: namespace, compat layer, ring-buffer log, error catcher (BugGrabber-friendly), event dispatcher with owners, combat queue, serializer with export strings, account-wide DB with per-character sections and migrations, profiles (export, import, copy from character), module system (class, required addons, step-aside, player choice), conflict detection, API probe.
- UI: theme tokens, widget kit, hub window, minimap button (LibDBIcon when available), Options > AddOns page.
- Advisor groundwork (dormant): `/oar snap` snapshot, advice loader with action whitelist, empty Advice.lua.
- Data: registry with schema checks; hunter macro pack (19 hunter + 2 general macros, unverified except the tame macro).
- Modules: Welcome (reference module).
- Tests: WoW client mock, 60 specs. Tools: find-wow, deploy (build stamp, restart detection), read-logs, backup/restore, screenshots, package, lua.py.
