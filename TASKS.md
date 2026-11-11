# TASKS

Master checklist. Details, steps and acceptance checks for each task are in the phase file linked in each heading.
Claude Code: work top to bottom, skip tasks whose deps are not done, and update the status here when a task closes.

Status: `[ ]` to do · `[~]` in progress · `[x]` done · `[!]` blocked. Append ` — <date>: <note>` when closing or blocking.
Owners: **Claude** works alone · **Gary** needs Gary · **Both** code first, then a short in-game check.

Already built in this package (verify in P0/P1, don't rebuild): module loader, per-character settings, export/import/copy,
error catcher, debug log, API probe, hub window, minimap button, settings page, snapshot + advice loader (dormant),
data registry, hunter macro pack (unverified), test harness, deploy/read-logs/backup/package tools.

Regenerate the list after editing phase files: `python tools/build_tasks.py` (keeps statuses and notes).

## Phase 0: Setup and ground truth  ([phases/P0_setup.md](phases/P0_setup.md))

- [x] P0-01 Prepare the PC · Gary · deps: none — 2026-11-11: Setup.cmd ran on Gary PC (it-lt-01): Git 2.56, gh 2.103, Python 3.12.10 + lupa, Claude Code 2.1.322
- [x] P0-02 Find WoW · Claude · deps: P0-01 — 2026-11-11: WoW at C:\Program Files (x86)\World of Warcraft, client folder _forever_, account folder found; tools/local.json written
- [x] P0-03 Tests green on Gary's PC · Claude · deps: P0-01 — 2026-11-11: 71/71 green on Gary PC
- [x] P0-04 Git repository · Claude · deps: P0-03 — 2026-11-11: private repo LackOfSkillz/OAR (rename to Outrider pending, see HANDOFF.md), noreply commit identity
- [x] P0-05 First deploy and login · Both · deps: P0-02, P0-03 — 2026-11-11: build bd98a54 loaded, version line + login complete, greeting shown, 0 errors (first try missed: WoW was started before the deploy)
- [x] P0-06 Real interface number · Both · deps: P0-05 — 2026-11-11: client reports iface 16001, build 1.60.1.70888; TOC already 16001, no change; C1 confirmed
- [x] P0-07 SavedVariables round trip (critical) · Both · deps: P0-05 — 2026-11-11: PASS. loads rose over 3 reloads and a full restart (client 10:51:24), sv=yes, debug kept; C4 confirmed fixed
- [x] P0-08 API probe · Both · deps: P0-05 — 2026-11-11: auto probe 78 present / 21 missing; unit samples out of and in combat (target + nameplate fully readable, no secrets); PROBE_RESULTS and C3/C5/C6 updated. Classic pet APIs missing → P2-09 redesign
- [x] P0-09 Error pipeline check · Both · deps: P0-05 — 2026-11-11: deliberate error recorded once with stack; combat queue held during a real fight (11:28:51) and ran after it (11:29:03), test button macro deferred; taint from the forbidden-event probe was caught and logged. BugGrabber not installed (optional)
- [x] P0-10 Name and rename · Gary decides, Claude renames · deps: none — 2026-11-11: renamed to Outrider in v0.2.0; GitHub repo rename + remote update left for Claude Code on the PC
- [x] P0-11 Screenshot loop · Both · deps: P0-05 — 2026-11-11: Gary pastes screenshots into the chat (in-game Print Screen saved none); Claude read the hub Modules tab correctly (Torrant Mcluvin, 13 modules, ammo 1139)
- [ ] **G0** gate: a code change goes from Claude's edit to Gary's screen and back into Claude's log reader in under two minutes; SavedVariables round trip is confirmed (or the fallback is chosen); `docs/PROBE_RESULTS.md` is filled in and committed.

## Phase 1: Foundation  ([phases/P1_foundation.md](phases/P1_foundation.md))

- [ ] P1-01 Module loader in game · Both · deps: P0-07
- [ ] P1-02 Character awareness · Both · deps: P1-01
- [ ] P1-03 Export, import, copy in game · Both · deps: P1-02
- [x] P1-04 Throttle and timer helpers · Claude · deps: none — 2026-11-11: Core/Timer.lua (After, Ticker, Throttle with trailing run, OnUpdate fallback idle when empty); 8 specs
- [~] P1-05 Secure button pool · Claude · deps: P1-04 — 2026-11-11: UI/SecureButtons.lua (pool of 4 prewarmed, combat-deferred SetMacro/Show/Place/Release), mock flags protected calls in combat; 8 specs. Waiting on Gary: /ride selftest button
- [~] P1-06 Toasts · Claude · deps: P1-04 — 2026-11-11: UI/Toast.lua (3-stack, drag saves anchor per char, hover holds, sound, pooled secure button parented to UIParent); 7 specs. Waiting on Gary: /ride selftest toast
- [~] P1-07 UI kit additions · Claude · deps: P1-06 — 2026-11-11: UI/WidgetsExtra.lua (ScrollList virtualized, Tabs, own Dropdown, Slider, throttled SearchBox), class accent setting; 8 specs. Waiting on Gary: /ride selftest widgets screenshot
- [x] P1-08 Hub with tabs · Claude · deps: P1-07 — 2026-11-11: five tabs render in game (Gary screenshot of Modules tab with live status lines); Esc and position as before
- [ ] P1-09 Minimap button and settings page · Both · deps: P1-08
- [x] P1-10 Snapshot stays dormant but works · Both · deps: P0-07 — 2026-11-11: snapshot taken automatically at logout, no reload by itself
- [x] P1-11 Performance check · Claude · deps: P1-08 — 2026-11-11: auto perf at logout: 577 KB, 25 handlers, 0 timers, no idle OnUpdate, slowest handler 1.36 ms (login); within budget
- [x] P1-12 Installed addons check · Claude · deps: P0-02 — 2026-11-11: AddOns folder holds only Outrider (no BugGrabber/BugSack yet); no overlaps, KNOWN list unchanged. Recheck folder names when Gary installs addons (Forever Data Protect folder name unverified)
- [ ] P1-13 Gate G1 run · Both · deps: all P1
- [ ] **G1** gate: settings survive a full game restart; two characters (hunter + priest or mage) have independent settings and the hub shows only what applies to each; a 30-minute normal play session produces zero Outrider errors and zero taint reports; the name question (Q1) is settled.

## Phase 2: Hunter tools and rares  ([phases/P2_hunter_rares.md](phases/P2_hunter_rares.md))

- [x] P2-01 Discovery: record what Gary meets · Claude · deps: P1-04 — 2026-11-11: in game 17+ NPCs captured on map 2521 by mouseover/nameplate/interact; vendor (Railee Thriceforged), banker, stable master tagged with quality interact; 7 specs
- [ ] P2-02 Rare data pack seed · Both · deps: P2-01
- [x] P2-03 RareScan · Claude · deps: P2-01 — 2026-11-11: verified in game: Mystmane (npcID 259388) seen by nameplate at 12:54:53, layer 1, map 2521 59.8,34.4; sighting logged; 8 specs
- [~] P2-04 RareAlerts · Claude · deps: P2-03, P1-05, P1-06 — 2026-11-11: Modules/RareAlerts.lua (toast + sound + Target secure button /targetexact, 5 min per-NPC cooldown, modes all/pack/watch, yields to RareScanner); 6 specs. Waiting on Gary: a real rare
- [~] P2-05 Watchlist and Rares tab · Claude · deps: P2-04, P1-08 — 2026-11-11: hub Rares tab (pack + sightings + discovered rares, zone/all, window per layer, Watch toggle), /ride watch per char; 3 specs. Waiting on Gary: screenshot with a real rare
- [~] P2-06 Layer detection · Both · deps: P2-01 — 2026-11-11: Modules/Layers.lua (zone UID majority over last 20 distinct creatures, min 3, 60% share, OTR_LAYER_CHANGED, L### label in hub Overview); 5 specs. Waiting on Gary: play in one zone, then a layer change
- [~] P2-07 Sightings and respawn windows · Claude · deps: P2-03, P2-06 — 2026-11-11: Modules/Sightings.lua (50 per NPC, pack or learned windows per layer, 3+ observations before showing a learned range, tamed via UNIT_PET npcID); 5 specs. Rares tab display comes with P2-05
- [~] P2-08 TameHelper · Both · deps: P2-04, P1-05 — 2026-11-11: Gary TAMED MYSTMANE with the /ride tamemacro macro (Concussive pull, Tame Beast, Wing Clip restart): macro verified in game. 2026-11-11: /ride tamemacro writes pull+tame macro (Shift re-pull) and watches the beast; rare toasts show Pull/Tame (same macro) for tameable rares at or below your level, else Target; 7 specs. Waiting on Gary: a real tame via the toast
- [~] P2-09 PetStatus · Claude · deps: P1-07 — 2026-11-11: panel verified in game (Dog, Cat 12, XP 694/2525, Health 380/380 and Focus 100 shown from secret values, Feed button placed right); 7 specs. Still to see: Feed click, happiness representation from the buff log
- [~] P2-10 BeastInfo tooltips · Claude · deps: P2-02 — 2026-11-11: Modules/BeastInfo.lua via TooltipDataProcessor post-call (family, level vs yours, tameable for hunters, rare sighting line, Shift = pack details marked unverified); 4 specs. Waiting on Gary: screenshot of a beast tooltip
- [x] P2-11 Ammo · Claude · deps: P1-06 — 2026-11-11: ammo slot reads in game (1139, Gary screenshot); warns once <200 and once <50; 3 specs
- [ ] P2-12 Gate G2 field test · Both · deps: all P2
- [ ] **G2** gate: in the field, alerts fire for The Rake, Mystmane and Ghost Howl (or whichever of the three Gary can reach, plus two other rares); the target/tame button works with one click; sightings show the right zone, position and layer in the Rares tab; no errors or taint in a 1-hour hunting session.

## Phase 3: Navigation and map  ([phases/P3_navigation.md](phases/P3_navigation.md))

- [~] P3-01 Waypoint service · Claude · deps: P0-08 — 2026-11-11: Modules/Waypoints.lua (Blizzard user waypoint + supertrack, TomTom fallback, arrival clear checked 1/s only while active, /ride way); 3 specs. In-game check comes with pin cards/Nearest (no typing)
- [x] P3-02 Fallback arrow · Claude · deps: P3-01 — 2026-11-11: not needed: Blizzard user waypoints + supertrack exist on Forever (probe), so the arrow backend is never used; revisit only if that changes
- [~] P3-03 World map pins · Claude · deps: P0-08 — 2026-11-11: Modules/MapPins.lua (own frames on WorldMapFrame canvas, redrawn on show/map change, places + rares, faction filter, per-char hidden kinds); 3 specs. Waiting on Gary: open the map after a town visit
- [x] P3-04 Minimap pins · Claude · deps: P3-03 — 2026-11-11: verified in game by a walk test (Railee Thriceforged: 21, 14, 7, 0 yards, dot to centre; away and back smooth). Offsets = map coords x map size in yards; hover tooltip + click card; 5 specs
- [~] P3-05 Pin cards · Claude · deps: P3-03 — 2026-11-11: click a pin: card with kind, coords, visits or rare window, Waypoint + Watch buttons (no secure actions); 1 spec
- [~] P3-06 POI capture · Claude · deps: P2-01 — 2026-11-11: Modules/POICapture.lua (vendor+repair, trainer, flight, bank, AH, stable, spirit healer, mailbox; averaged position; faction of capturer); 2 specs. Waiting on Gary: a town visit
- [~] P3-07 Nearest · Claude · deps: P3-01, P3-06 — 2026-11-11: /ride near <kind>, nearest on continent by world yards, faction filter, auto spirit-healer waypoint on death; 3 specs. Hub quick buttons still to do
- [!] P3-08 Questie bridge · Claude · deps: P3-03 — 2026-11-11: blocked: Questie is not installed on Gary's PC, and its API must be read from its own source. Resumes if Gary installs Questie
- [x] P3-09 Discovery privacy and controls · Claude · deps: P3-06 — 2026-11-11: hub Map tab: per-char pin kind filters, Discovery and place recording toggles, counts, two-click clear; data stays local; 3 specs
- [~] P3-10 Coordinates · Claude · deps: P3-01 — 2026-11-11: Modules/Coords.lua (coords under minimap, ticking only while moving; /ride coords prints + logs); 2 specs. Cursor coords on world map still to do
- [ ] P3-11 Redrawn zone check · Both · deps: P3-06
- [ ] P3-12 Gate G3 · Both · deps: all P3
- [ ] **G3** gate: for five known NPCs, pins land where the game shows them (screenshot check: within a small distance on the map); `/ride near spirit` sets a waypoint to the nearest known spirit healer; pin cards open and show correct info; minimap pins appear and disappear with distance; no errors.

## Phase 4: Macro library  ([phases/P4_macros.md](phases/P4_macros.md))

- [x] P4-01 Macro engine (pure logic) · Claude · deps: none — 2026-11-11: Modules/MacroEngine.lua: Fill, Validate (255, unknown command, brackets, !Auto Shot/!Aspect, #showtooltip), Explain in plain English; all pack macros validate; explanations for the hunter pack reviewed; 5 specs
- [~] P4-02 Spellbook resolver · Claude · deps: P0-08 — 2026-11-11: Modules/Spellbook.lua (C_SpellBook with classic fallback, highest rank per name, saved per char, /ride spells); 3 specs. Waiting on: the saved list from Gary's next login
- [~] P4-03 Library window · Claude · deps: P4-01, P4-02, P1-08 — 2026-11-11: hub Macros tab: class + general macros, state from spellbook/level/placeholders, filled body, plain-English explanation, notes; 1 spec. Waiting on Gary: screenshot
- [~] P4-04 Installer · Both · deps: P4-03 — 2026-11-11: Install/Update/Remove/Pick up out of combat, per-char tracking, never touches macros Gary made, slot checks, TARGET from watchlist; 5 specs. Waiting on Gary: install Pull, AutoShot, PetCare and press them
- [~] P4-05 Live placeholders · Claude · deps: P4-04 — 2026-11-11: Modules/BagFood.lua ({FOOD}/{DRINK} from bags by use-spell Food/Drink/Refreshment, highest usable level, conjured first; installed macros auto-update out of combat, max once per 10 s); 3 specs. {PET_FOOD} waits on a diet source (GetPetFoodList missing on Forever); {MOUNT} picker still to do
- [~] P4-06 Rank-check · Both · deps: P4-02 — 2026-11-11: Modules/RankCheck.lua (action slots vs highest known rank, toast with Fix button out of combat, logs findings at every login); toast gains plain action buttons; 3 specs. Waiting on: login log (does Forever auto-upgrade?) and a trainer visit
- [~] P4-07 Rare-aware macros · Claude · deps: P4-04, P2-05 — 2026-11-11: Modules/RareMacros.lua (tame target follows newest watched tameable rare; scan macro = watched + map rares as /targetexact lines within 255; rebuilt on zone change, never in combat); 2 specs. Waiting on Gary: install Outrider Scan, change zone
- [~] P4-08 Class packs · Claude · deps: P4-01 — 2026-11-11: priest (11) and mage (11) packs from Rankedboost/Kami-Labs/Warcraft Wiki Forever guides, all unverified; validate in spec; C13 community-confirmed. warrior (11), rogue (10), warlock (11), druid (11), shaman (10), paladin (11) added (Rankedboost, Kami-Labs, Almar's Guides, Warcraft Wiki; unverified); macropacks_spec checks every pack (engine, 255 chars, ids, names, tags); Forever spell notes in FOREVER_CONSTRAINTS
- [~] P4-09 Export, import and context sets · Claude · deps: P4-04 — 2026-11-11: Export/Import buttons in the Macros tab (OTR1 string of library ids; importer fills text locally, skips other-class macros, refuses broken strings); 2 specs. Context sets wait for P7-09 layouts
- [ ] P4-10 Gate G4 · Both · deps: all P4
- [ ] **G4** gate: on Torrant, five library macros installed and each works when Gary presses it; on the priest, five priest macros; the rank-check finds an outdated button after a trainer visit and fixes it with one click out of combat; no macro over 255 characters; macro slot counts correct.

## Phase 5: Professions, auctions and fishing  ([phases/P5_professions.md](phases/P5_professions.md))

- [~] P5-01 Inventory across characters · Claude · deps: P1-04 — 2026-11-11: Modules/Inventory.lua (bags throttled, bank while open, mail, worn, money; item tooltip "You have N (Char n, ...)", Shift for bags/bank/mail); 2 specs. Waiting on: opening the bank on two characters
- [~] P5-02 Profession scanner · Claude · deps: P0-08 — 2026-11-11: Modules/Professions.lua (C_TradeSkillUI with classic fallback, skill/max, recipes + reagents per char, shape logged on first open); 1 spec. Waiting on: Gary opens a profession window. Rank-ready alert still to do
- [~] P5-03 Craft queue and shopping list · Claude · deps: P5-01, P5-02 — 2026-11-11: hub Crafting tab (recipes from Professions, queue per char, shopping list need/have/buy with alts apart and price estimate); 1 spec. AH-side list and tick-off still to do
- [~] P5-04 Skill-up planner · Claude · deps: P5-02, P5-06 · 2026-11-11: Modules/SkillUp.lua + /ride skillup [prof] [target] + Crafting tab lines: cost per expected point from the client recipe color (Professions now stores relativeDifficulty; orange 1, yellow 0.6, green 0.25 = estimates), owned bags/bank free, unpriced last; greedy route to N using owned first. P5-06 favor part not needed for this. 2 specs. Waiting on: Gary opens a profession window, sanity-checks numbers
- [~] P5-05 Prices · Claude · deps: P0-08 — 2026-11-11: Modules/Prices.lua (Auctionator/TSM if present, else own lowest-per-day AH history from browse/commodity results for 14 days, vendor price; tooltip AH + vendor + below-vendor warning); 2 specs. Waiting on: an AH visit
- [ ] P5-06 Merchant's Favor planner · Both · deps: P5-01, P5-05
- [~] P5-07 Auction helper · Claude · deps: P5-05 · 2026-11-11: Modules/AuctionHelper.lua: own panel beside the AH (never touches Blizzard/Auctionator/TSM frames): suggested price = market minus /ride undercut rule, floor = max(vendor, craft cost) + 5% cut + deposit, warnings (under vendor, deposit > profit); undercut list from owned auctions vs lowest seen today. No price pre-fill, no repost button (Gary uses Blizzard's); crate stacks wait on P5-06. 3 specs
- [~] P5-08 Ledger · Claude · deps: P5-05 — 2026-11-11: Modules/Ledger.lua (money changes booked to vendor/AH/mail/training/flights/bank/loot, session net + gold per hour logged at logout, last 30 sessions per char); 1 spec. Loot value and AH mail detail still to do
- [~] P5-09 Merchant helper · Claude · deps: P5-05 — 2026-11-11: Modules/Merchant.lua (panel beside the vendor: Sell junk greys only, 12 per click for buyback; Repair with cost, guild repair if allowed; never on open); vendor goods recorded by POICapture; 2 specs. Waiting on: Gary sells junk and repairs
- [~] P5-10 Mailbox collect · Claude · deps: P5-08 — 2026-11-11: Collect button beside the mailbox, one thing per click, COD skipped, ledger books it as mail; 1 spec. Waiting on: Gary collects mail
- [~] P5-11 Fishing: one key · Both · deps: P1-05 — 2026-11-11: Modules/Fishing.lua (pole equipped = fishing mode; chosen key casts via pooled secure button, switches to INTERACTTARGET while the Fishing channel runs, out of combat only; loud splash with volumes restored); /ride fishkey; 3 specs. Waiting on: Gary picks a key and fishes. Lure step still to do
- [~] P5-12 Fishing: gear, log, cooking · Claude · deps: P5-11, P5-01 — 2026-11-11: catch log by zone + session value (Modules/LootLog.lua); 1 spec. Gear sets, cooking links, bait reminders still to do
- [~] P5-13 Gathering map · Claude · deps: P3-03 — 2026-11-11: herb/ore nodes from loot after Herb Gathering/Mining, merged within 0.6%, pins in a "Herbs & ore" group with filters; 2 specs. Waiting on: Gary gathers
- [ ] P5-14 Gate G5 · Both · deps: all P5
- [ ] **G5** gate: shopping list for a chosen craft shows the right missing materials across two characters; a Favor crate shows how to fill it from bags/bank/alts; prices appear in tooltips from the installed auction addon; a 15-minute fishing session logs every catch; every buy, post, craft and cast is Gary's click.

## Phase 6: Gear advisor  ([phases/P6_gear.md](phases/P6_gear.md))

- [~] P6-01 Stat weights · Claude · deps: none — 2026-11-11: Data/StatWeights.lua starting points for all 9 classes (labelled as such), per-char overrides, /ride weights. Spec detection from talents still to do
- [~] P6-02 Item scoring · Claude · deps: P6-01 — 2026-11-11: GearScore (C_Item.GetItemStats x weights, ranged DPS for hunters, weaker ring/trinket, 2H vs MH+OH, required level, armor type by class and level 40), /ride score; 5 specs
- [~] P6-03 Tooltip verdict · Claude · deps: P6-02 — 2026-11-11: one line on item tooltips (upgrade green, downgrade muted, usable at N amber, cannot wear). Waiting on: Gary checks 10 items; other-character verdicts still to do
- [~] P6-04 Bags and quest rewards · Claude · deps: P6-02 — 2026-11-11: Modules/QuestRewards.lua (best choice = biggest usable upgrade else best vendor value; toast + glow on the reward button; bag upgrades toast once per session, never in combat/instances); 3 specs. Waiting on: a quest turn-in with choices
- [~] P6-05 Upgrade sources pack · Claude · deps: P3-06 · 2026-11-11: tools/import_gear.py -> private load-on-demand Outrider_Data_Gear (D13): 2954 items, 4439 sources (quest giver, vendor, named drop with positions) from the private QuestieDB copy; loads the first time the Gear tab or a zone scan needs it, memory logged. Dungeon drops missing (no map for dungeon areas)
- [~] P6-06 Nearby upgrades · Claude · deps: P6-02, P6-05, P2-07, P3-01 · 2026-11-11: Modules/Nearby.lua + Gear tab + /ride nearby: candidates on this map, faction, level -6..+3, scored in game, gain then effort (vendor, alt, quest, drop); click = waypoint; one toast per item at 10%+, not in combat/instances. AH and crafter sources not yet; 2 specs
- [x] P6-07 GearQuest bridge · Claude · deps: P6-06 · 2026-11-11: skipped: GearQuest is not installed (AddOns has only Outrider folders); nothing to bridge. Nearby (P6-06) covers upgrade picks. Revisit if Gary installs it (DECISIONS)
- [~] P6-08 Alt handoffs · Claude · deps: P5-01, P6-02 · 2026-11-11: Modules/Handoffs.lua: at login finds BoE upgrades in other characters' bags/bank (once per item toast, "if still unbound" since Inventory keeps IDs only); at the holder's mailbox a toast with Address (fills the name; Gary attaches and sends). C.ItemInfo now returns bindType. Waiting on: BoE item on the priest
- [~] P6-09 Gear sets · Claude · deps: P6-02 — 2026-11-11: Modules/GearSets.lua (/ride gear save|<name>|list|delete; per char; out of combat; missing items reported); covers the P5-12 fishing outfit; 1 spec
- [ ] P6-10 Gate G6 · Both · deps: all P6
- [ ] **G6** gate: on Torrant and on the priest, the tooltip verdict agrees with Gary's own judgment on 10 test items each; quest reward highlight picks the item Gary would pick (or the best vendor value when nothing is usable); the Nearby list shows at least five sensible upgrades in the current zone with where to get them; no toast in combat or instances.

## Phase 7: Interface modernization  ([phases/P7_interface.md](phases/P7_interface.md))

- [ ] P7-01 Visual direction · Both · deps: P1-07
- [ ] P7-02 Fonts and textures · Claude · deps: P7-01
- [ ] P7-03 Edit Mode survey · Both · deps: P0-08
- [ ] P7-04 Skin Blizzard frames · Claude · deps: P7-02, P7-03
- [ ] P7-05 Tooltips · Claude · deps: P7-04
- [ ] P7-06 Unit frames and bars, look only · Claude · deps: P7-04
- [ ] P7-07 Nameplates · Claude · deps: P2-03
- [~] P7-08 Chat · Claude · deps: P1-07 · 2026-11-11: Modules/Chat.lua via Blizzard chat message filters only: keyword highlight (your name, watched rares, shopping list, /ride chat word add), feed entry per keyword per 5 min, repeat spam hidden 60 s (channel/say/yell), URLs clickable to a copy box, /ride copychat, /ride chat time on|off. Short channel names and LFG tab not done (need AddMessage replace / a layout change: ask Gary); chat spell check (Modules/SpellCheck.lua + Outrider_Data_Words, D12); 1 spec
- [ ] P7-09 Context layouts · Both · deps: P7-06
- [~] P7-10 Command bar · Claude · deps: P3-07, P6-06 · 2026-11-11: Modules/Find.lua + Bindings.xml (Key Bindings > Outrider > Find anything) + /ride find: rares (card + waypoint), /ride near words, NPC names (waypoint), gear (Gear tab filtered), macros, hub tabs; ten sample queries in find_spec. Crates waits on P5-06
- [~] P7-11 Notification center · Claude · deps: P1-06 · 2026-11-11: Modules/Feed.lua: every toast also kept (last 50, account-wide, newest first), Feed hub tab + /ride feed, unread count on the minimap button tooltip; 1 spec. Waiting on Gary: open the Feed tab
- [ ] P7-12 First-run setup and accessibility · Claude · deps: P7-09
- [ ] P7-13 Gate G7 · Both · deps: all P7
- [ ] **G7** gate: Gary signs off on before/after screenshots for the main screens; a one-hour session including combat, a dungeon or group, a city and fishing produces zero taint reports and zero Outrider errors; with ElvUI or EllesmereUI installed, the skin steps aside and only Outrider's own panels remain.

## Phase 8: Sharing and social  ([phases/P8_sharing.md](phases/P8_sharing.md))

- [~] P8-01 Comm layer · Claude · deps: P1-04 · 2026-11-11: Modules/Comm.lua, prefix Outrider, v1|TYPE|base64, 240-byte chunks, GUILD/PARTY/RAID/WHISPER only; sends nothing unless a sharing feature is on
- [~] P8-02 Version check · Claude · deps: P8-01 · 2026-11-11: HELLO on login when /ride share hello on (off by default); one chat line when a guildmate runs newer
- [~] P8-03 Rare sightings sharing · Both · deps: P8-01, P2-07 · 2026-11-11: Modules/RareShare.lua, /ride share rares guild|party on|off (off by default); receivers record to Sightings (pins), toast watched rares with layer; drops whispers and bad data. Needs a second player
- [ ] P8-04 Location sharing (opt-in) · Both · deps: P8-01, P3-03
- [~] P8-05 Gathering and fishing sharing · Claude · deps: P8-01, P5-13 · 2026-11-11: Modules/GatherShare.lua: /ride share nodes on (off by default) sends each new herb/ore/fishing spot to the guild (6/min max); receivers merge them into LootLog nodes marked sharedBy, pins say "from <name>"; GUILD only, bad data dropped. LootLog now records fishing spots (where Gary stands) as kind fish. Needs a second player
- [~] P8-06 Town errand list · Claude · deps: P5-01, P5-02, P4-06, P2-11 · 2026-11-11: Modules/Errands.lua + Errands tab + /ride errands: repair, junk, ammo, trainer (even level since last visit), AH shopping list; toast on entering a rest area, row click = waypoint. Reagents and alt mail later
- [ ] P8-07 Chat triage · Claude · deps: P7-08
- [~] P8-08 Forecasts · Claude · deps: P8-03, P5-08 · 2026-11-11: Modules/Forecasts.lua + Forecasts tab + /ride forecast: respawn range (middle 80% once 5+ gaps, min-max at 3-4, "N of 3 needed" below), median and observation count, from own + shared sightings; gold per hour over 10+ min ledger sessions with trend after 8 sessions, labelled estimate; 2 specs
- [ ] P8-09 Gate G8 · Both · deps: all P8
- [ ] **G8** gate: with a second player (a friend or a second account) in the same guild, each sees the other's rare sightings within five seconds and as a pin; location sharing is off until switched on, and when on shows the other player on the world map; trial accounts don't break anything; chat triage and the errand list work for Torrant.

## Phase 9: AI advisor (parked; start only when Gary says so)  ([phases/P9_ai_advisor.md](phases/P9_ai_advisor.md))

- [ ] P9-01 Richer snapshots · Claude · deps: P2–P6 modules
- [ ] P9-02 `/ride ask` · Claude · deps: P9-01
- [ ] P9-03 Companion app · Claude · deps: P9-02
- [ ] P9-04 Model wiring · Both · deps: P9-03
- [ ] P9-05 Safety tests · Claude · deps: P9-04
- [ ] P9-06 Gate G9 · Both · deps: all P9
- [ ] **G9** gate: Gary types `/ride ask`, reloads, and within a minute sees 3 to 8 relevant options for Torrant; malformed or stale advice files are ignored safely; nothing leaves the PC unless Gary configured a cloud model; no option can cast, target, buy or move anything.

### Release (any time after G3, Gary's call)

- [ ] R-01 Packaging · Claude · deps: none
- [ ] R-02 Changelog and version · Claude · deps: none
- [ ] R-03 Public release decision · Gary · deps: none

## Totals

| Phase | Tasks |
|---|---|
| Phase 0: Setup and ground truth | 11 |
| Phase 1: Foundation | 13 |
| Phase 2: Hunter tools and rares | 12 |
| Phase 3: Navigation and map | 12 |
| Phase 4: Macro library | 10 |
| Phase 5: Professions, auctions and fishing | 14 |
| Phase 6: Gear advisor | 10 |
| Phase 7: Interface modernization | 13 |
| Phase 8: Sharing and social | 9 |
| Phase 9: AI advisor (parked; start only when Gary says so) | 9 |
| **All** | **113** |
