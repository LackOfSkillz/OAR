# Outrider — competitive parity and feature gap backlog

**Audit date:** 2026-11-18  
**Repository:** [LackOfSkillz/OAR](https://github.com/LackOfSkillz/OAR) (private), branch main  
**Inspected head:** `a13314b9a29ff4d0988a2cf1fc9cfc33bc2b7cef`  
**Scope:** WoW Forever 1.60.1, not retail; competitor benchmark = leading 2–3 representative addons *per capability*, plus specialist tools when useful. **Not** claiming a validated numeric ranking of all CurseForge addons.

## Important caveats

- This is a **repo/source inspection plus public competitor documentation**, not an Outrider live client test and not a full review of third-party source or runtime behavior. `GAP` means no sufficient implementation was found in the inspected relevant Outrider modules; `PARTIAL` means some implementation exists but falls short of the described benchmark; `VERIFY` means coverage or capability cannot be confirmed from the accessible code and requires private data packs, probes or game testing. Treat every item as a task candidate until validated, *not* a universal assertion that a feature is broken.
- `docs/ADDON_GAP_ANALYSIS.md` (2026-11-17) remains historical. Its **top eight were built** and should not be recreated: info bar, alts/lockouts, map entrances/flight times, quest nameplate markers/quest XP/reward values, mailbox, bag overlays/search, UI toggles, profession extras. This file evaluates their **remaining depth gaps**.
- Some Outrider data packs are **generated privately** (e.g. `Outrider_Data_Quests` and `Outrider_Data_Dungeons`), not included in the GitHub tree. An absence in the tracked tree is NOT proof the installed addon has no data; compare actual local generated packs against candidate fixtures.
- Many popular addon download counts represent **lifetime downloads across all WoW versions**, not Forever-only installations. A CurseForge 'Forever' file is compatibility metadata, not proof of full functionality.
- Do not copy proprietary or paid leveling guides, UI assets, Boss Mod data or addon source without checking licenses. Existing imported QuestieDB material is GPLv3 and requires the related distribution obligations to be reviewed before shipping. Reference functionality, not private source.
- The hard rules in `CLAUDE.md` still apply: no automated player actions or screen/memory reading, no combat log registration, no protected frame modifications in combat, data-only AI advice, no unsupported secret-value branching, no silent off-box network traffic, and player-triggered actions with secure buttons/macros only.
- Client probe `docs/PROBE_RESULTS.md` confirms `C_DamageMeter` with readable out-of-combat sessions and lists `C_EncounterTimeline` as available. **The data shape and useful event coverage for boss timeline are not yet established**; investigate rather than assuming DBM or real-time parity.

## Baseline and selection

Starting catalog: [CurseForge WoW addons filtered to Forever, ranked by all-time downloads](https://www.curseforge.com/wow/search?class=addons&gameVersionTypeId=88568&page=1&pageSize=50&sortBy=total+downloads). For module-specific comparisons, prefer the relevant current addon project page rather than a global top-ten list. See linked benchmarks below.

**Statuses:** `GAP` no comparable implementation found in scoped modules; `PARTIAL` existing code but not full competitor depth; `VERIFY` confirm in-game/with missing packs.  
**Priority:** `P0` blocks 'one addon to rule them all' parity, `P1` valuable depth, `P2` specialization/polish. Priority is feature importance, not permission to violate WoW rules.

**Source files reviewed** include: `README.md`, `CLAUDE.md`, `CHANGELOG.md`, `docs/ADDON_GAP_ANALYSIS.md`, `docs/FOREVER_CONSTRAINTS.md`, `docs/PROBE_RESULTS.md`, `docs/USER_GUIDE.md`, `docs/TASK_AUDIT_2026-11-15.md`, `Outrider.toc`, and the quest, rare, pet, macro, dungeon, map, auction, inventory, healer, profession, chat, alt and UI modules referenced below.

## Verified CurseForge Forever-filter benchmark snapshot — 2026-11-18

The direct [CurseForge WoW Forever results page](https://www.curseforge.com/wow/search?class=addons&gameVersionTypeId=88568&page=1&pageSize=50&sortBy=total+downloads) currently lists these ten highly downloaded **Forever-labeled** projects in this order (total lifetime downloads across all supported game flavors, **not Forever-specific installations**):

1. **DBM – Deadly Boss Mods (DBM-Core)** — dungeon/raid encounter warnings, boss timer benchmark.
2. **Details! Damage Meter** — combat analytics benchmark.
3. **Questie** — quest objectives and map database benchmark.
4. **Auctionator** — auction research, price lookup and buying/selling benchmark.
5. **BigWigs** — boss warnings/role filtering benchmark.
6. **Bagnon** — account-wide inventory and unified bag benchmark.
7. **RareScanner** — rare discovery and alert benchmark.
8. **LittleWigs** — dungeon-specific mechanic alerts benchmark.
9. **Pawn** — stat-weight item comparison benchmark.
10. **Plater Nameplates** — nameplate appearance and quest/target information benchmark.

These ten are **not** the whole target list: use 2–3 specialized competitors for *each Outrider module* (as indexed below), including relevant niche addons such as DungeonJournal, Baganator, RestedXP, HandyNotes, HealBot, TSM and GatherMate2. A Forever label does not prove that its advanced feature set works on Forever. Record a specific supported-game-version check and actual in-game behavior before implementing parity claims. A plugin may also be unsuitable for Outrider's strict anti-automation and no-combat-log rules.

## Master gap register

Each ID is stable and can become an issue/micro-task. `Done when` is **minimum acceptance**, not proof that the competitor will be worse.

### A. Questing, Questie parity and leveling guides

**Benchmark:** Questie; RestedXP Guide; Guidelime.  
**Outrider baseline:** QuestTracker.lua, QuestObjectives.lua, QuestInfo.lua, QuestExtras.lua, PartyQuests.lua, Finder.lua, WhatNow.lua, Journey.lua. Outrider's tracker has a 45-row hard cap, right-click folds, left-click routes; it yields to Questie. QuestObjectives requires the separately generated Outrider_Data_Quests pack.

| ID | Priority | Status | Deficiency / proposed feature | Done when / verification gate |
|---|---|---|---|---|
| Q01 | P0 | VERIFY | Audit coverage of all available/active/completed quests, objective NPCs/items, prerequisite chains and zones independent of Questie | Two installs with Questie disabled; 50-quest golden matrix across 10 zones, original/Forever quests, factions, and levels; count missing/incorrect pins and labels |
| Q02 | P0 | GAP | A real Questie 'Quests by Zone' browser with available, completed, locked, and why-locked states | Zone explorer with level/class/race/faction/profession/chain filters, reward XP, and provenance; five tested zones |
| Q03 | P0 | PARTIAL | Questie tracker interaction parity: focus quest/dim other pins, click-through to journal, objective-level context menu and dynamic scroll beyond 45 rows | All controls reachable with 50+ quest/objective lines; no lost interactions in combat |
| Q04 | P0 | GAP | Continuous 1-60 ordered leveling route instead of only 3-5 What Now suggestions | Versioned faction/class/race guide packs; initial 1-20 route passes uninterrupted dry-run and two in-game sessions |
| Q05 | P1 | GAP | Guide-authoring engine like Guidelime: typed steps, prerequisites, skips, backtracking, routes and shareable custom guides | Original DSL/schema compiler, schema/error tests, one self-contained sample guide; no copying paid guides |
| Q06 | P1 | PARTIAL | Quest objective clusters, patrol uncertainty, drops, escort path execution and map-density overlays | Choose ranked locations for 25 quests with explicit confidence, not an arbitrary single pin |
| Q07 | P1 | GAP | Group quest coordination: who has/needs prerequisites, synchronized shared quest objectives and target distribution | Multi-client tests with Outrider and Questie clients; respectful rate limits and privacy |
| Q08 | P1 | PARTIAL | Forever-specific quest correction/verification queue and discrepancy reporting | Report a wrong quest pin with automatic client snapshot; corrected records stay provenance-tagged |
| Q09 | P2 | GAP | Dedicated side-by-side leveling efficiency dashboard by XP/hr, deaths, distance, and quest completion | Session history and guide-path comparisons with timestamps and optional display |

### B. Dungeons, raids, attunements and encounters

**Benchmark:** DungeonJournal (Forever); AtlasLoot/Forever loot equivalents; DBM; BigWigs/LittleWigs; Attune; Nova Instance Tracker.  
**Outrider baseline:** DungeonGuide.lua ranks eligibility and class-weighted upgrades, a readiness checklist, entrance route and group readiness; Alts.lua estimates run stats and lockouts. No encounter database or AtlasLoot-style full journal found.

| ID | Priority | Status | Deficiency / proposed feature | Done when / verification gate |
|---|---|---|---|---|
| D01 | P0 | GAP | Complete DungeonJournal-style directory: every boss, interior map, entrance, quest giver, dungeon quests, rewards, loot and prerequisites | For three dungeons, cross-check all bosses, quests, loot, maps and rewards; data-pack and freshness labels |
| D02 | P0 | GAP | AtlasLoot-style searchable full loot tables (not only gear upgrades for this character), with bosses, currencies, recipes and collection sets | Search by item/boss/dungeon; at least three dungeons and one raid, all drops linked to provenance |
| D03 | P0 | GAP | Boss-mechanic encyclopedia with class/role actions, interrupt/dispel assignments and quick guide | Boss details show each mechanic, response and source; class-relevant short checklist |
| D04 | P0 | VERIFY | Encounter timelines and role-filtered warnings using C_EncounterTimeline official API (not combat log) | Probe event shape in a real encounter; if unsupported, disable feature gracefully; never claim DBM parity without fight coverage |
| D05 | P0 | VERIFY | Post-fight damage/healing/threat analytics from C_DamageMeter and supported threat APIs | Collect 10 fight sessions; reconcile totals to Blizzard UI; ensure secret values never enter unsafe comparisons |
| D06 | P1 | GAP | Attune-style graph of keys, dungeon/raid unlock quests, and class/Forever progression requirements | Show dependency graph, current checkpoint, missing prerequisites, how-to-reach, test 3 chains |
| D07 | P1 | PARTIAL | Full instance journal: boss kill state, raid lockout IDs, reset windows, per-character run and loot history, group status | Compare to Blizzard lockout state, handle 5/hr 30/day estimates explicitly as estimates |
| D08 | P1 | GAP | Group tactical panel: pull roles, ready check extensions, raid assignments, interrupt roster and optional sync | No automatic casting; player-initiated notes; 5-player and 20-player mock tests |
| D09 | P2 | GAP | Boss-specific configurable alerts, sound packs, encounter-specific settings and after-action review | Five experimentally proven Forever encounters with reliable only-if-observable warnings |
| D10 | P2 | GAP | Targeted dungeon route/planning support: objectives, route checkpoints, quest collection, teleport/return path | One complete dungeon journey covers quest prerequisites, entrance, bosses, return and turn-ins |

### C. Combat, macros, rotations, and action feedback

**Benchmark:** Details!; DBM encounter alerts; OmniCC; Hekili as feature reference only; class macro packs.  
**Outrider baseline:** MacroEngine validates/explains 255-character macros; MacroLibrary installs/removes owned macros; HunterFight and ClassFight generate class spellbook macros; combat logs are forbidden and class implementations include unverified paths.

| ID | Priority | Status | Deficiency / proposed feature | Done when / verification gate |
|---|---|---|---|---|
| C01 | P0 | PARTIAL | Class/spec/build-specific macro intelligence rather than one fixed spell-order template per class | All 9 classes x leveling milestones x roles tests, generated macros fit 255 characters, in-game spell availability verified |
| C02 | P0 | VERIFY | Macro correctness/performance: priority failures, first-invalid-spell behavior, target switches, buffs and ranges | Per-class real-combat trace with failures categorized and known-client constraints; no 'best DPS' claims absent evidence |
| C03 | P0 | GAP | Integrated combat meter drilldowns: DPS/HPS, avoidable damage when available, casts, deaths, threat and comparison to previous fights | Post-fight dashboard and role comparison relying only on supported C_DamageMeter data |
| C04 | P1 | GAP | Macro variants for solo/group/dungeon/PvP, consumable/interrupt/defensive sets, per-encounter readiness | Versioned templates per class and role; protect any user-authored macro and allow rollback |
| C05 | P1 | PARTIAL | Real macro editing workbench: searchable templates, preview simulation, explain condition conflicts, hotkey mapping, conflict report | Representative 100-macro corpus validation and user-visible diff before installation |
| C06 | P1 | GAP | Cooldown and proc visibility using documented permitted CooldownViewer UI/APIs, rather than forbidden WeakAuras combat secrets | In-game permission/API gate then customizable watch display; no forbidden protected logic |
| C07 | P1 | GAP | Post-fight suggestion engine that recommends player-initiated macro changes based on observed outcome | Suggestions expose measured evidence and never rewrite active macros while combat-locked |
| C08 | P2 | GAP | Action-bar presentation choices: cooldown digits, missing reagent indicator, keybind/conflict help without taking ownership of protected Blizzard frames | Bench against OmniCC/Bartender on Forever, off-by-default, zero taint |

### D. Rares, spawns, world discoveries

**Benchmark:** RareScanner; SilverDragon; rare-route and collection explorers.  
**Outrider baseline:** RareScan.lua, RareAlerts.lua, RarePlates.lua, RaresTab.lua, RareProfile.lua, RareTimer.lua, Sightings.lua, SpawnLog.lua, RareShare.lua implement detection, alerts, layer evidence and timed windows. RareScan's header says no vignettes observed in Forever.

| ID | Priority | Status | Deficiency / proposed feature | Done when / verification gate |
|---|---|---|---|---|
| R01 | P0 | GAP | RareScanner-style rare details/loot explorer: all known drops, rarity, upgrade suitability, required level and wishlist | At least 20 rares with inspectable verified/unverified drops and search |
| R02 | P0 | GAP | Rare route builder for filtered wanted rares, dynamically optimized across travel time and layers | Route 10 visible spawn locations, recompute after sighting and filter changes, explicit uncertainty |
| R03 | P0 | PARTIAL | Detection coverage benchmark across nameplates, target, mouseover, death, layers and missing vignettes; false positives | 20 NPC scenarios and live sessions, dedupe and alert sensitivity metrics |
| R04 | P1 | GAP | Rare model preview and high-clarity details window (where the API and art permit) | Model gracefully degrades to creature icon; no protected API calls |
| R05 | P1 | PARTIAL | Respawn confidence and telemetry quality: sample sizes, layer independence, censored sightings and stale data | Only report probability/window when samples justify it; never present claimed timers as measured truth |
| R06 | P1 | GAP | WhatNow integration by rare value: upgrades, tame skills, unique rewards vs distance and contest risk | Top rare recommendations explain 'why' and show route, loot and data confidence |
| R07 | P2 | GAP | Treasures and non-NPC events as first-class scanner targets only where Forever supports their identification | Item/object discovery events mapped without false promises of inaccessible detection |
| R08 | P2 | GAP | Rare-specific configurable sounds, sounds by rarity/watch tier, snooze and alert history | No duplicate spam, per-character accessible sounds/visual cues |

### E. Hunter and pet intelligence

**Benchmark:** PetTracker; Beast Lore / beast databases; pet-taming guide addons.  
**Outrider baseline:** PetStatus.lua handles secure feeding, basic stats, diets and some ability info; TameHelper writes one-target macros; BeastInfo and rare profiles store observed traits.

| ID | Priority | Status | Deficiency / proposed feature | Done when / verification gate |
|---|---|---|---|---|
| H01 | P0 | PARTIAL | Searchable beast and pet-skill training database (who teaches which rank, location, beast family, level, attack speed) | For level-10-to-60 hunter, search wanted ability and find minimum reachable candidates, with provenance |
| H02 | P1 | GAP | Pet stable roster and comparison: abilities, loyalty/happiness where client exposes it, best pet for role, training upgrade path | Account-safe snapshots and role comparison, unknown fields shown as unknown |
| H03 | P1 | PARTIAL | Tame safety plan incorporating interrupts/knockdowns, pet sacrifice, trap, emergency fallback and macro verification | One-click-per-action secure macros; real test on three creature ability profiles |
| H04 | P1 | GAP | Hunter leveling pet recommendation graph, keyed by level/zone and tested damage/survivability | Recommend top pets and learnable ranks, show route and observed evidence |
| H05 | P2 | GAP | Pet happiness, diet, food inventory and restock forecast integrated with Errands and AH | No unsupported loyalty promises; restock prompts configurable |

### F. Maps, travel, waypoints and gathering paths

**Benchmark:** TomTom; Leatrix Maps; HandyNotes; GatherMate2/Routes.  
**Outrider baseline:** MapPins.lua, MinimapPins.lua, MapReveal.lua, Waypoints.lua, Travel.lua, Journey.lua, Trail.lua, NodePack.lua; flight/boat/portal route graph, filters and data overlays exist.

| ID | Priority | Status | Deficiency / proposed feature | Done when / verification gate |
|---|---|---|---|---|
| M01 | P0 | VERIFY | All Forever maps, portal/boat paths, zone changes, interior maps, reveal overlays and Forever-redrawn geography | Test per-continent map coords and 10 redrawn-zone checkpoints; no Classic coordinates silently treated as verified |
| M02 | P1 | GAP | HandyNotes custom player notes: icons, freeform notes, import/export, editing and per-character/global categories | Create/edit/move/export/import notes; never collide with existing pin groups |
| M03 | P1 | PARTIAL | Route planner accuracy using terrain, obstacles, transport schedules and unknown taxi connections rather than straight-line only | Compare ETA/route for 15 real trips, record error and offer fallback if inaccessible |
| M04 | P1 | GAP | GatherMate2-style editable and importable prefilled node database, with visibility filters and confidence per node | Dataset attribution/license review; filter herbs/ores/fish, versioned schema, mislocated nodes marked |
| M05 | P1 | GAP | Route optimization through selected gathering nodes with current-node state and density overlays | 20-node walk/flight route supports replan, hide harvested and route summary |
| M06 | P2 | GAP | World-map customization: zoom/move/opacity, dungeon interior map and transport line overlays where supported | Do not replace Blizzard protected frames; per-control compatibility tests |
| M07 | P2 | PARTIAL | Waypoints interchange with TomTom/other addon data and conflict-free takeover when competitors are present | Import/export coordinates and preference setting, validated for Forever maps |

### G. Gear, itemization, equipment sets

**Benchmark:** Pawn; ItemRack Classic; Loadout; gear-source/best-in-slot guide tools.  
**Outrider baseline:** GearScore.lua uses static stat weights and compare; GearSets.lua is a 71-line named-set save/equip/list/delete, no visual flyout; GearShop and GearQuestBridge cross-reference upgrades.

| ID | Priority | Status | Deficiency / proposed feature | Done when / verification gate |
|---|---|---|---|---|
| G01 | P0 | PARTIAL | Correct role/spec/level stat-weight profiles, weapons and 2H/offhand, hit caps, weapon speeds, resistances and set bonuses | At least 15 gold-standard comparisons per class and role, display assumptions and limits |
| G02 | P0 | GAP | Equipment set manager UI with saved icons, preview, slot flyouts, missing item report, single click to equip out of combat | Five sets with user-confirmed swaps; never autoequip or touch gear in protected combat |
| G03 | P1 | GAP | Pawn-style editable named stat scales, export/import and user selected role emphasis | Per-character scales and validated strings, no numerical overflow and deterministic ratings |
| G04 | P1 | GAP | Complete targeted gear wishlist/BiS planning by slot, source, raid/dungeon/quest/AH price and upgrade size | Search source and action route from item card, 30-item test matrix |
| G05 | P1 | PARTIAL | Live upgrade advice must distinguish potential item, eligible item, affordable item and equipped item | Clear verdicts across AH, quest reward, dungeon loot, alt storage; no 'can use' hallucinations |
| G06 | P1 | GAP | Set variants and action-bar/talent links with explicit one-click switch (Loadout comparison) | Save/import/copy, non-destructive rollback, combat queue status visible |
| G07 | P2 | GAP | Resistance and consumable preparations for raids/roles plus upgrade value by encounter | Class and encounter view reports missing pieces, conservative costs |

### H. Bags, inventory, banking and mail

**Benchmark:** Baganator; Bagnon; BetterBags; Postal/Mailwright.  
**Outrider baseline:** Inventory.lua stores per-item count per container and character; BagExtras.lua decorates native bags and searches names, deliberately no combined window; Mailbox.lua collects one thing per click and offers simple contacts and expiry hints.

| ID | Priority | Status | Deficiency / proposed feature | Done when / verification gate |
|---|---|---|---|---|
| B01 | P0 | GAP | Actual Baganator-grade combined bags/bank window, categories or single-pane view, clean item icons and tooltips | Remote inventory views without touching Blizzard bank protected state; normal bag interactions when available |
| B02 | P0 | PARTIAL | Search by item attributes, slot, quality, binding, level, category and bool AND/OR/NOT, across bags/bank/mail/auctions/alts | 20 queries with correct category and item-level matching; include provenance and freshness |
| B03 | P1 | GAP | Inventory index with item-instance details, equipment sets, bank tabs, guild storage where accessible, auction listings, expiry | Account-wide counts stay consistent after transfers and reloads |
| B04 | P1 | GAP | Custom category rules, sorting preferences, filtered transfers and confirmation before moves/sells | Human confirmation on each protected action per policy; avoid fighting installed bag addons |
| B05 | P1 | PARTIAL | Postal-style inbox type filters/selective collect, quick attach, richer contact autocomplete and attached-item classification | Mock inbox 100 mails; skip COD/GM; respect user-click rule |
| B06 | P1 | GAP | Mail queue previews with alt supply goals, material shipment planning, reserve space and expiry alerts | Queue identifies target and contents before each user-initiated send |
| B07 | P2 | GAP | Bank organization/cleaning and item cleanup safety (user designated junk, 'never sell' list) | No auto-deletion; undoable labels and confirmation flows |

### I. Auctions, gold, economy and accounting

**Benchmark:** Auctionator; TradeSkillMaster (feature reference; Forever support check); Journalator.  
**Outrider baseline:** Prices.lua records lowest price per day for 14 days + scans, AuctionHelper.lua recommends price and flags undercut, AHBuy.lua queues purchases with user confirmation; Ledger.lua records activity.

| ID | Priority | Status | Deficiency / proposed feature | Done when / verification gate |
|---|---|---|---|---|
| A01 | P0 | PARTIAL | Auctionator search parity: saved shopping lists, query filters, session history, multi-search, sortable results | 20 standardized searches, full-scan performance and rate limits |
| A02 | P0 | GAP | Market price engine: historical median/volatility, sale velocity proxy, outlier rejection, freshness and confidence | Unknown sale volume shown as unknown; 14+ day history and tests for bad quotes |
| A03 | P1 | PARTIAL | Posting workflow with safe undercut, minimum profit, deposit and auction house cut plus one-click cancel per allowed action | No misleading default and no unapproved posting or canceling |
| A04 | P1 | GAP | TSM-style item groups/operations and policy presets (craft/sell/buy/hold) without automation | User configures price rules and previews exact action before click |
| A05 | P1 | GAP | Craft-versus-buy arbitrage planner with full reagent chain and opportunity cost | Use latest known quotes, calculate fees and losses; 50 deterministic test cases |
| A06 | P1 | GAP | Profit/loss dashboard by item, profession, dungeon, fishing, alt and time period | Reconcile gold ledger against known transactions without implying invisible sales data |
| A07 | P1 | GAP | Smart restock, shopping target, inventory handoffs and vendor comparison | Only shows buy candidates within budget; costs and stale quotes explicit |
| A08 | P2 | GAP | Auction pricing histograms/trend graphs, deal alerts and user-configurable watch thresholds | Sound/notifications opt-in and no automated purchases |

### J. Professions, recipes, crafting

**Benchmark:** What's Training?; SkillUp; TSM Crafting.  
**Outrider baseline:** Professions.lua, ProfExtras.lua, Crafter.lua, CraftQueue.lua, SkillUp.lua, MoneyGuide.lua: trained recipe capture, chance estimates, queue, shopping list and one-press craft controls. Trainer list depends on trainers already visited.

| ID | Priority | Status | Deficiency / proposed feature | Done when / verification gate |
|---|---|---|---|---|
| P01 | P0 | PARTIAL | Full unlearned recipe catalog, trainers, drops/vendors/quests, weapon skills, rank costs and next learnable spells without prior trainer visit | Verify 3 professions x tiers, provenance and price from sources |
| P02 | P1 | PARTIAL | Skill-up planner models recipe availability, material alternatives, expected successes and total budget not just colors | Calculate route with remaining mats, AH buy cost, skill chance uncertainty |
| P03 | P1 | GAP | TSM-like recursive crafting queue and craftability dependency graph for intermediate materials | Queue nested recipes, reserve existing stock, correctly aggregate supplies |
| P04 | P1 | PARTIAL | Actual craft profitability ranking accounts for reagent sources, auction cut, deposits, vendor prices, cooldown scarcity | 50 recipes with unit tests and cost provenance |
| P05 | P1 | GAP | Discovery and profession recipe collection tracker with acquisition route and completion percentage | Missing recipe filters per character and account, 30 verified source entries |
| P06 | P1 | PARTIAL | Alt/guild crafter directory with learned recipes, optional opt-in sharing, cooldown availability | No public broadcasts; freshness and privacy controls |
| P07 | P2 | GAP | Profession-specific optimizer for disenchant returns and crafting specialization where Forever permits | Strict feature gating by profession and game availability |

### K. Fishing and gathering

**Benchmark:** Fishing Buddy Forever; GatherMate2; Routes.  
**Outrider baseline:** Fishing.lua, FishingHUD.lua, FishingGuide.lua, LootLog.lua, HerbHelper.lua, Fishing data; extensive catch stats, one-key cast/hook, gear swap and zone advice exist.

| ID | Priority | Status | Deficiency / proposed feature | Done when / verification gate |
|---|---|---|---|---|
| F01 | P0 | VERIFY | Fishing skill route and zone/fish database accuracy for Forever new fish, catch chances, special conditions | 40-catch sample in 3 zones, confidence and price timestamps |
| F02 | P1 | PARTIAL | Fishing session analytics: catch distribution, hourly gains, lure/gear impact, best-time estimates and rarity | Distinct session vs lifetime stats, no inferred drop-rate claims from tiny samples |
| F03 | P1 | PARTIAL | Gathering node map completeness and prefilled node imports, observed respawn state and rare pool detection | No falsely precise 'available now'; complete per-type filter and sample nodes |
| F04 | P1 | GAP | Integrated gold/XP gathering route generator across professions and fishing with AH cost trends | 10 locations and route rerank, conflict-free with normal quest route |
| F05 | P2 | GAP | Fishing tournament schedule and collection/completion log where events exist in Forever | Game time/cycle provenance, manual verification |

### L. Healing and raid frames

**Benchmark:** VuhDo; HealBot Continued; Cell/other supported raid-frame addons.  
**Outrider baseline:** HealPanel.lua uses secure player-initiated clicks and assigned bars, M.MAX=10, fixed binds and a few status indicators. Yields to established healing addons.

| ID | Priority | Status | Deficiency / proposed feature | Done when / verification gate |
|---|---|---|---|---|
| HE01 | P0 | PARTIAL | Raid-size coverage, flexible group/role sorting and assigned target selection: fixed 10 bars currently | 40-member test, configurable visible subset and safe secure frame updates |
| HE02 | P1 | GAP | VuhDo-style click binding editor per class, modifier combinations, mouseover keys and profile import/export | All bindings only changed out of combat; preview before apply |
| HE03 | P1 | PARTIAL | Debuff/buff/HoT/shield/incoming-heal/threat/aggro indicators where Forever allows readable data | Unknown secrets never evaluated for conditional coloring; 15 status test cases |
| HE04 | P1 | GAP | Group buff, dispel, resurrection and role reminders (advice only) | No automatic actions, context explains eligible spell and target |
| HE05 | P2 | GAP | Raid-frame layouts/role presets, accessibility tests and multi-monitor scaling | Test priest/paladin/druid/shaman, no taint |

### M. UI, chat, mailbox, social and quality of life

**Benchmark:** Leatrix Plus/Maps; ElvUI; Prat 3.0; Postal/Mailwright; Titan Panel.  
**Outrider baseline:** InfoBar.lua and Tweaks.lua implement basic bar, camera, clutter, minimap buttons and history; Chat.lua supports keywords/links/spam; Hub/Premium supply shared theme.

| ID | Priority | Status | Deficiency / proposed feature | Done when / verification gate |
|---|---|---|---|---|
| UI01 | P1 | PARTIAL | Leatrix-grade modular options catalog: individually configurable convenience toggles and searchable settings | Feature comparison grid, on/off persistence, zero unexpected behavior |
| UI02 | P1 | GAP | Customizable info bar/data broker plugins, placement and per-stat display, zero clutter by default | 15 data fields, per-character export, 1-second refresh cost measured |
| UI03 | P1 | PARTIAL | Prat features: advanced chat search, user-defined channels, class/level coloring, abbreviations, edit-box behavior and copied history | Search returns exact lines after /reload; modules independently toggle |
| UI04 | P1 | GAP | Theme consistency: consistent page navigation, scrollable responsive tables, standardized status chips, gamepad-friendly focus | Small/large resolution screenshot set, no text clipping |
| UI05 | P2 | GAP | Minimap scale/shape and map UI customization without competing owner of protected frames | Settings tested in combat and with Leatrix/ElvUI on |
| UI06 | P2 | GAP | More robust cross-addon detection and user-facing conflict screen: who owns bag/map/quest/raid frames | One owner per frame, modules independently yield; explicit diagnostics |

### N. Alts, progression, account, friends and guild

**Benchmark:** Nova Instance Tracker; Altoholic; Attune; Titan Panel.  
**Outrider baseline:** Alts.lua stores gold/rested XP/bags/durability/professions and dungeon-run estimate; Inventory.lua counts items; KitShare, Favor, Census, Comm support opt-in info.

| ID | Priority | Status | Deficiency / proposed feature | Done when / verification gate |
|---|---|---|---|---|
| AL01 | P1 | PARTIAL | Account character roster: skills, rested cap, money, inventory, mail, lockouts, exact freshness and actionable tasks | Show 10 characters, 'last updated' per category and no stale total disguised as current |
| AL02 | P1 | GAP | Account-wide progression/checklist dashboard: keys, rare collection, recipe completion, exploration, attunement | Character-level and account-level progress independently tracked |
| AL03 | P1 | GAP | Optional party/guild attunement and quest readiness checks, sharing only explicitly approved metadata | Consent per channel/category, deny unknown add-on payloads |
| AL04 | P2 | GAP | Guild utility directory: recipes/crafters and verified instance readiness, opt-in and no server-wide census broadcasts | Permissioned sharing and opt-out support |
| AL05 | P2 | GAP | Cross-character errands orchestration: optimal character to log into, mail or craft next | Actionable steps with no automation |

### O. Outrider-only differentiation and platform engineering

**Benchmark:** Outrider differentiation beyond single-purpose addons; no exact competitor.  
**Outrider baseline:** WhatNow, Advisor/companion and modules combine multi-domain data; optional AI uses saved snapshots/codes; safety prohibits screen scraping, runtime game injection and auto-play.

| ID | Priority | Status | Deficiency / proposed feature | Done when / verification gate |
|---|---|---|---|---|
| X01 | P0 | PARTIAL | True goal planner with 30/60/120-minute itinerary, prerequisites, gold, XP, group requirements, route and actual reassessment | Plans persist, are correct after quest turn-in/zone change and contain reason/confidence/source per step |
| X02 | P0 | GAP | Every module publishes an explicit capabilities/coverage contract, data freshness and known limitations to advisor | No suggestions citing disabled modules/missing data; deterministic fallback |
| X03 | P0 | GAP | Automated parity regression fixtures against competitors: Questie quest coverage, DungeonJournal loot, RareScanner rare data | License-safe separately sourced fixtures, expected counts and change reports |
| X04 | P0 | GAP | CI/static acceptance gate: Lua syntax, mocked events, newly added files/TOC, private pack absent and secret-value handling | CI passes without local private packs; sensitive paths absent; no forbidden COMBAT_LOG event registration |
| X05 | P1 | GAP | Module interoperability test matrix (Questie, Auctionator, Baganator, HealBot, ElvUI) | No double overlays, no frame ownership conflicts, one on/off switch per integration |
| X06 | P1 | PARTIAL | User-visible source provenance & accuracy ratings for every recommendation, including Forever map coordinate changes | Trace source and timestamp in every actionable card |
| X07 | P1 | GAP | Low-resource certification with peak RAM, idle/active CPU, frame/timer caps and load-on-demand packs | Measured before/after in 30-minute gameplay; hard caps, pooled frame tests |
| X08 | P1 | GAP | Automatic addon feature coverage report and release notes generated from manifests and tests | No claims of parity until in-game verified |
| X09 | P2 | GAP | Data pack updater/verification workflow on desktop, explicit consent, versioned snapshots, no in-game network calls | Works offline when not updating; no surprise traffic or unlicensed data imports |
| X10 | P2 | PARTIAL | Accessible onboarding: presets for solo/leveling, hunter, dungeon, raid healer, trader, gatherer | 10-minute first-use test per persona, opt-in settings and rollback |

## Benchmark source index (primary feature documentation)

1. [Questie](https://www.curseforge.com/wow/addons/questie): tracker focus, quest-by-zone, maps and search.
2. [RestedXP Guide](https://www.curseforge.com/wow/addons/restedxp-guide): guided route engine, step tracking and leveling timing. **Paid guides are not reusable assets.**
3. [DungeonJournal — Forever](https://www.curseforge.com/wow/addons/dungeonjournal): dungeon boss loot, quests and rewards.
4. [AtlasLootClassic](https://www.curseforge.com/wow/addons/atlaslootclassic): loot UI, wishlists; classic flavor rather than verified Forever support.
5. [Deadly Boss Mods](https://www.curseforge.com/wow/addons/deadly-boss-mods) and [BigWigs](https://www.curseforge.com/wow/addons/bigwigs): role warnings and timers; **Forever encounter scripts must be separately verified**.
6. [RareScanner](https://www.curseforge.com/wow/addons/rarescanner): scan alerts, loot explorer, routes and respawn telemetry.
7. [Auctionator](https://www.curseforge.com/wow/addons/auctionator): shopping lists, full scan, search history, undercut scan.
8. [TradeSkillMaster](https://www.curseforge.com/wow/addons/trade-skill-master): groups, crafting and multi-character economy; **Forever availability not asserted from its main project page**.
9. [Baganator](https://www.curseforge.com/wow/addons/baganator) and [Bagnon](https://www.curseforge.com/wow/addons/bagnon): combined, searchable categorized inventories and remote character data.
10. [GatherMate2](https://www.curseforge.com/wow/addons/gathermate2) and [HandyNotes](https://www.curseforge.com/wow/addons/handynotes): discovered/prefilled nodes and map annotation.
11. [VuhDo](https://www.curseforge.com/wow/addons/vuhdo): raid frame, modifiers, debuff and assignments.
12. [Pawn](https://www.curseforge.com/wow/addons/pawn) and [Loadout](https://www.curseforge.com/wow/addons/loadout): tunable scoring and equipment set handling.
13. [What's Training?](https://www.curseforge.com/wow/addons/whats-training): trainer, recipe-source and weapon skills lookups.
14. [Fishing Buddy Forever](https://www.curseforge.com/wow/addons/fishing-buddy): fishing gear, watcher, lure and session data.
15. [Prat 3.0](https://www.curseforge.com/wow/addons/prat-3-0) and [Postal](https://www.curseforge.com/wow/addons/postal): chat/mail depth.
16. [Leatrix Plus](https://www.curseforge.com/wow/addons/leatrix-plus): UX conveniences (not all allowed by Outrider's no-auto-action rule).
17. [Attune](https://www.curseforge.com/wow/addons/attune): dungeon/raid unlock graphs and guild summaries.
18. [WoW Forever compatibility survey](https://www.wofwforever.com/en/guides/wow-forever-addon-compatibility/): caution that current Forever packages may support the platform without complete encounter content.

## Implementation order (avoid another 'Questie surprise')

**Phase 0 — evidence and capability gates (do this before claiming parity)**
- Preserve baseline SHA. Regenerate module inventory and comparison fixture mapping.
- Validate generated private quest, NPC, item and dungeon data packs actually installed; calculate entity/zone coverage and freshness.
- Test Questie alone and Outrider alone in the *same* level, zone, faction and character conditions. Save screenshots and deterministic behavior notes; compare factual results, not just UI screenshots.
- Probe C_DamageMeter and C_EncounterTimeline during/after real fights, no combat log. Document secret-value gating, returning schemas, supported encounter types, and output against Blizzard's display.
- Add a capability table showing `available`, `partial`, `unverified` or `blocked` and mark data packs/source licenses.

**Phase 1 — mandatory parity**, independently shippable vertical slices:
1. `Q01/Q02/Q03/Q04`: Questie coverage, zone browser and complete first leveling route; build own guide engine `Q05` after basic source coverage.
2. `D01/D02/D03/D04/D05`: DungeonJournal + loot browsing + permitted boss/combat intelligence.
3. `R01/R02/R03`: rare loot explorer, routes, detector reliability.
4. `B01/B02`: category/search-enabled bag experience, keeping existing BagExtras in interoperability mode.
5. `G01/G02/C01/C02`: trusted gear and class-specific macro tests before adding more strategies.

**Phase 2 — strongest daily-use depth:** AH/TSM-style operations and crafting dependencies, pet skill database, advanced travel and notes, 40-player healing frames, richer chat/mail, profession collections, account dashboard.

**Phase 3 — Outrider's unique advantage:** cross-module `What Now` itinerary plus optional explainable intelligence, measured personalization, evidence and correctness gates.

## Acceptance contract for every item

1. **Research evidence:** link precise competitor behavior with date/flavor; document where Forever diverges.
2. **Source audit:** identify existing Outrider implementation and dependencies, update status after checking local private data packs.
3. **Design:** define data schema, API availability, permission boundaries, fallback and screen ownership.
4. **Tests:** add `tests/spec/` mocks, bad-data/secret-value cases, performance and no-taint tests; `tools/test.ps1` green.
5. **Play-test:** deploy via `tools/deploy.ps1`; gather saved client probe/log/screenshot evidence for acceptance.
6. **Documentation:** update generated HelpData/USER_GUIDE, CHANGELOG, TASKS and notes with exact task ID; leave failing/unverified cases open.
7. **Competitor absent test:** show Outrider actually delivers the behavior *with that specialized addon disabled*.
8. **Competitor present test:** show Outrider cleanly yields/integrates, no double frame or duplicate alert, while the other addon is enabled.

## Explicitly out of scope or conditional

- Automation that acts without a player click/key press: auto quest accept/turn-in, auto purchases/sales/repair, background macro execution, automated rotation or world interaction. Player-assisted UI is allowed; the model cannot override Outrider's policy.
- Combat-log processing or private engine data/external capture. Do not attempt to bypass secret-value or restricted-action systems.
- Claims that a third-party addon is fully functional on Forever based only on its CurseForge flavor flag. Validate it in game.
- Retail-only Mythic+ features, transmogs, events or professions not present in Forever.
- A full 'all addons replaced' claim until each capability is scored **feature present**, **data complete**, **behavior verified in-client**, **no conflicts**, and **supported version**. We should report parity **per module**, not as a fabricated overall percent.

## Claude Code starting instruction

> Read CLAUDE.md, docs/ADDON_GAP_ANALYSIS.md, this roadmap, and docs/PROBE_RESULTS.md. Do NOT recreate the November 17 top-eight features. First add a machine-readable parity matrix keyed by task IDs and source files; audit generated private packs on the local PC; run baseline tests. Then implement Phase 0 and begin Q01–Q04, D01–D05 as independent gates. Update the matrix with exact proof, leave unverified items open, and deploy only through documented tools. Never run game automation or bypass Blizzard client restrictions.
