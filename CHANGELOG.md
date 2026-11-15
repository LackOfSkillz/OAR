# Changelog

## Unreleased

- **Expedition look on every page:** every hub page now opens with its title in the display font over the header scene and a gold rule; settings-style pages put each section in a card that stretches with the window; lists stretch to the window; the Macros and Crafting side panels are cards.
- **Merchant's Favor:** Outrider reads your Favor balance, depot standing, any Waylaid Crate's contents and the quartermaster's Favor prices from the game, then shows per crate which bundle you can fill from bags, bank and alts or what the shortfall costs (Money page, `/ride favor`). It never fills, buys or turns in anything.
- **Rare pack:** Mystmane, Den'dralass, Snapbeak the Quick (from your own captures), The Rake and Ghost Howl (ids only until seen).
- **Faster advice:** two new keys (Key Bindings > AddOns > Outrider): **Ask** shows the snapshot code ready to copy, **Paste advice** opens the paste box, where Ctrl+V applies the answer at once and opens the Advisor tab (`/ride paste` too). The Ask Outrider window can answer by itself when you copy a code in game and puts the answer on the clipboard. Every step is still a key you press.
- **Ask Outrider (Outrider Intelligence, Gary's spec, all phases up to his approvals):** a question and minutes box in the Advisor tab; answers from Claude (MCP), a local model or, opt-in, Anthropic/OpenAI/Gemini; plans that fit your time, compare answers, source chips, evidence tooltips, Useful/Wrong data/Done feedback with plan progress. The model only chooses among What now?'s steps; every card is rebuilt from Outrider's data and checked again in game. Names never sent; keys in Windows Credential Manager; consent, preview and a daily token cap for cloud models; an Ask Outrider desktop window; 120 golden scenarios, contract fixtures and security checks. See docs/intelligence/.
- **Sharing hardened:** long messages between Outrider users carry a message id, so two from one sender never mix; limits on pieces, size and half-received messages, 30-second expiry, duplicate and malformed pieces ignored, sending paced. Older builds' messages are still read.
- **What now? (Pathfinder Lite):** a new page right under Home (`/ride now`) with the 3 to 5 steps worth doing next, each with what, why, where, a Go button and an alternative. Pick a goal (level up, make gold, better gear, professions, explore, a bit of everything) and the same candidates are weighed differently. Draws on errands, quests, gear, dungeons, profession training, watched rares, gold methods and gathering spots; scores by benefit, goal, distance and how sure the data is, and says so when a step rests on unchecked data. Quests several levels up count for less; battleground quests are left out. Not useful hides a step for a day. The suggestions for every goal are logged at logout. `tools/whatnow_check.lua` runs it against a copy of the saved data.
- **Expedition look from Gary's concept picture:** the game's fantasy font (Morpheus) for page and card titles, a gold window edge with the Outrider emblem, a settings button in the title bar, sidebar headings in small capitals with a rule, every form page titled in the display font with gold section headings, lists with stripes and a gold hover, gold chip tabs, toasts with a coloured edge. What now? has picture cards (Go, Details tooltip, Not useful, Recommended and Unchecked tags, no made-up percentages), goal chips with icons, and side cards for errands, rare watch, this session (XP, gold, time) and a character card with portrait, XP bar and item level. Home opens with "Welcome back", the next step, Nearest and six cards in two stretching columns. The window opens at 1080 x 720.
- **Gary's GPT art:** emblem, a castle header scene and eight step pictures, converted by `tools/art.py` (plain-Python PNG to TGA, crop and scale; `docs/ART_REQUESTS.md` has the specs). Missing art falls back to game icons.
- **What now? plans a little:** steps in the same zone as the top step count 15% more and say "same area as step 1"; it logs only when its steps change.
- **Loot roll advice:** Need for your usable upgrades, Greed for an alt (mailable), Greed or Pass otherwise, on the item tooltip while the roll is open. It never rolls for you.
- **Dungeon ready check** on the Dungeons page: repairs, food and drink, bag space, hunter ammo.
- **Smaller save:** zone quest reports are kept compact (they were about 0.9 MB across ten characters).
- **New look, first step (Gary chose the Expedition mockup):** darker window and sidebar, the current page marked with a gold strip, a gold main button, cards and goal chips in the widget kit (`UI:Card`, `UI:Chip`, `UI:Tag`, `UI:PrimaryButton`). What now? is rebuilt on them: your character in class colour with level, zone and gold, goal chips, step cards with an icon, time, an "unchecked" or "guess" tag for unsure data, Go, Not useful and a clickable alternative, and a side column with errands, rare watch and this session's gold. Class-colour accents stay as Gary set them.
- **Safer installs and updates:** the installer waits until WoW is fully closed (Retry or Cancel; nothing changes before that), backs up the old Outrider folders to `%LOCALAPPDATA%\Outrider\backup` (last 3 kept) and puts them all back if anything fails. Releases carry a SHA-256 checksum; the updater refuses an installer that doesn't match it. `tools/test-installer.ps1` checks install and rollback in a scratch folder.
- **Sharing outbox capped** at 96 pieces (a message that won't fit is refused), emptied when sharing is switched off; a failed send doesn't stop the rest.
- **Licence files:** every data folder built from QuestieDB carries the full GPLv3 text and an attribution note.

## Family builds (2026-11-14, release build-20261114-1625)

- **Install and update:** one-file installer (`Install-Outrider.cmd`) that finds WoW Forever and installs Outrider with every data pack and Gary's shared world knowledge (merged once, never overwriting; no player names). Releases on LackOfSkillz/outrider-releases; an **Update Outrider** desktop shortcut; in-game notice when a build is 14 days old or another user has a newer one.
- **Dungeon guide:** Dungeons page with the dungeons that fit your level now, your upgrades in each, the next tier and an arrow to the entrance (34 dungeons, Forever level ranges).
- **Auction house:** one Shopping panel with Training (ingredients and recipes ranked by cost per skill point), Weapons (top 10) and Armor (best per slot). Class armor type and weapon skills follow Forever's rules for every class and race; never above the gold you carry; stat-by-stat change in green and red with an overall percentage; buying through a confirm bar; one-click full price scan so prices don't need Auctionator or TSM.
- **Gear for alts and family:** gear cards (alts saved at login, others over guild or party when sharing is on); upgrades you loot go to alts first, then family and friends, then other Outrider users, with mailbox addressing.
- **Profession training:** a training button and key for every crafting profession (best gain first). Cooking makes a campfire, places it, then cooks, and never crafts a second campfire. Press-a-key setters in the hub.
- **Fishing:** HUD (skill, lure timer, what bites here, silver per hour, goal, advice), lure on the fish key, soft targeting so the same key hooks the bobber, auto loot while fishing, too-hard warning, session summary, rare catch sound, Weapons button, pool pins. The session survives a reload.
- **Money guide:** gold methods ranked by level, professions and faction, learning your own gold per hour.
- **Rares:** screen-edge flash and an arrow to the exact spot, minimap-marker detection, spawn log at a watched rare's spot, rare profiles, map pins at every spawn spot. The Mystmane 3-hour timer was tested and switched off (she missed both windows).
- **Herbs and ore:** hollow node pins; nodes you picked dim for 15 minutes, nodes you saw up show green.

## Earlier unreleased work (2026-11-12 to 13)

- **New Outrider window:** grouped sidebar with icons, your class color, resizable, a search box at the top, and a Home page (nearest places, where you are headed, best quests, upgrades, rare watch, errands, pet). Every /ride command now has a button, toggle or field (new pages: Waypoints, Rare alerts, Hunter, Gear sets, Professions, Chat, Sharing, Settings, All commands).
- **Cook / Brew / Herb** macros (`/ride make` creates them): one press makes everything you have ingredients for, best skill-up recipe first. The first press opens the profession window if it is closed.
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
