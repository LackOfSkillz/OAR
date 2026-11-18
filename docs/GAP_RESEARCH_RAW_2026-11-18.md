# Raw researcher reports behind the deep gap analysis (2026-11-18)

These are the four research passes behind `docs/GAP_ANALYSIS_DEEP_2026-11-18.md`, kept unedited apart from formatting. Each researcher:
- read the addon's CurseForge page, plus GitHub or the wiki where the page was thin;
- grepped and read Outrider's modules at commit a13314b;
- edited no files.

Where a pass worked from known option lists instead of fetching a page, it says so.

**Known errors in these reports:**
- **Pass 2, RareScanner "Every spawn spot":** it says "one pin per rare". That was already fixed on 2026-11-17: MapPins now shows every pack spawn spot.

**Key:**
- **HAS** (or H): Outrider has it.
- **PARTIAL** (or P): Outrider has some of it.
- **MISSING** (or M): missing.
- **CAN'T** (or C): breaks hard rule 1 (it acts for the player) or rule 4 (combat log).
- **UNSURE**: Midnight's secret values may block it.
- **Value**: for a Horde hunter levelling on Forever.

- [Pass 1: interface, bags, mail, maps](#pass-1-interface-bags-mail-maps)
- [Pass 2: rares, navigation, gathering, layers, lockouts](#pass-2-rares-navigation-gathering-layers-lockouts)
- [Pass 3: auction house, gear, alts, professions, levelling](#pass-3-auction-house-gear-alts-professions-levelling)
- [Pass 4: combat side, tooltips, chat, social, hunter](#pass-4-combat-side-tooltips-chat-social-hunter)

---

## Pass 1: interface, bags, mail, maps

Sources: the CurseForge pages for all nine addons. For Leatrix Plus the page lists every option, so its source wasn't needed.

### Leatrix Plus
| Feature | Outrider | Value |
|---|---|---|
| Auto quest accept/turn-in, gossip automation | CAN'T | - |
| Auto-accept summons/res, auto-release in PvP | CAN'T (a one-click prompt would be allowed) | med |
| Auto sell junk / auto repair on vendor open | CAN'T; HAS buttons (Merchant.lua) | - |
| Block duels/party invites/friend requests/shared quests | MISSING (declining automatically is borderline; a one-click "decline" toast is safe) | med |
| Auto-accept invites, invite on whisper keyword | CAN'T | - |
| Recent chat window (copy) | HAS (Chat.lua /ride copychat) | - |
| Restore chat after reload, bigger history | PARTIAL: Tweaks.lua restores 50 lines; history length not raised | low |
| Chat filters (spell links, drunk text, duel spam) | PARTIAL: Chat.lua mutes repeated text only | low |
| Hide chat buttons, unclamp chat, edit box on top, arrow keys, no sticky chat, no fade, more font sizes | MISSING | low |
| Class colours in chat | MISSING (Chat.lua colours keywords only) | low |
| Hide error text, zone text | HAS (Tweaks.lua) | - |
| Hide portrait numbers, keybind text, macro text, raid group labels | MISSING | low |
| Larger quest, mail and book text | MISSING (Setup.lua "larger text" scales our UI only) | med |
| Square minimap, minimap size/border | MISSING | low |
| Minimap button bag | HAS (Tweaks.lua buttonBag) | - |
| Tooltip restyle and scale | PARTIAL: Tooltips.lua styles it; no scale or layout options | low |
| Dress-up enhancements (nude/toggle buttons) | MISSING | low |
| Wider quest log | MISSING | med |
| Bigger profession/trainer windows, "Train all" button | MISSING (TrainShop lists costs; a Train-all click is allowed) | med |
| Flight map extras, flight times | HAS (FlightTimes.lua) | - |
| Volume slider on character frame | MISSING | low |
| Durability on character frame | PARTIAL: info bar and Alts only, not on the character frame | med |
| Ready-check timer | MISSING | low |
| Range colouring on action buttons | MISSING (UnitLook.lua: no safe API verified) | med |
| Screen borders, player frame elite chain | MISSING | low |
| Wowhead links | HAS (Tweaks.lua /ride wowhead) | - |
| Vendor price in tooltips | HAS (Prices.lua) | - |
| Free bag slots | HAS (InfoBar.lua) | - |
| Info cards (hover card, 3D model, ilvl, talents) | PARTIAL: PlayerInfo.lua tooltip lines; no card, no model | low |
| Class-coloured player/target frames | HAS (UnitLook.lua) | - |
| Move/scale widget frame and breath bar | MISSING | low |
| Hide alerts, event toasts, boss banner, stance bar, bag clean-up button, rested sleep animation | MISSING | low |
| Hide talking head, gryphons | HAS (Tweaks.lua, UnitLook.lua) | - |
| Turn off screen glow/effects, weather density | MISSING (game settings, easy) | low |
| Camera max zoom | HAS (Tweaks.lua) | - |
| Mute chosen game/mount sounds, Sound Finder | MISSING | med |
| Silence emotes while resting; audio follows device changes | MISSING | low |
| Faster auto loot | MISSING (a game setting plus a loot-frame speedup; not automation, you still loot) | med |
| Skip movies | MISSING | low |
| Easy item destroy (fills DELETE for you) | MISSING | low |
| No loot warnings (auto-confirm loot) | CAN'T | - |
| Auto-remove transforms | CAN'T | - |
| Search box over all options | MISSING (Find.lua searches tabs, not settings) | med |
| Game music by zone, movie library | MISSING | low |

### Leatrix Maps
| Feature | Outrider | Value |
|---|---|---|
| Reveal unexplored areas, tint | HAS (MapReveal.lua) | - |
| Discovery button: undiscovered areas outlined, numbered, listed | MISSING (we draw them but give no list or count) | med |
| Pins: dungeons, flight points, boats/zeppelins/portals, spirit healers | HAS (MapPins.lua) | - |
| Zone-crossing pins | MISSING | low |
| Opposing faction's points of interest | MISSING | low |
| Level ranges on maps | HAS (ZoneLevels.lua) | - |
| Fishing skill needed per zone on the continent map | MISSING | med |
| Hide town icons | MISSING | low |
| Zone/continent jump menus | MISSING | low |
| Player and cursor coordinates on the map | PARTIAL: player only (Coords.lua, under the minimap); no cursor coordinates | med |
| Switch the map to your new zone | MISSING | low |
| Move, scale, opacity, simple frame, themes | MISSING (one owner per frame) | low |
| Remember zoom, zoom further, centre on player | MISSING | low |
| Bigger player arrow, class-coloured group icons | MISSING | low |
| No map fade while moving, no reading emote | MISSING | low |
| Battlefield (zone) map options | MISSING | low |
| Dungeon interior maps | MISSING (needs map art) | med |
| Gemfall mini-game | MISSING | none |

### Bagnon, Baganator, Syndicator
| Feature | Outrider | Value |
|---|---|---|
| One combined bag window | MISSING (BagExtras.lua marks Blizzard's own bag slots) | high |
| Category view (auto and custom categories) | MISSING | high |
| Bank in the same window | MISSING | med |
| View alts' bags and bank anywhere | PARTIAL: data in Inventory.lua and a search, but no bag-style view | med |
| Owner counts in tooltips | HAS (Inventory.lua) | - |
| Search by name | HAS (BagExtras.lua /ride where) | - |
| Search keywords (type, slot, BoE, junk, food, reagent), ilvl filters, & \| ! | MISSING (name only) | med |
| Search highlights matching slots in the open bags | MISSING | med |
| Overlays: ilvl, upgrade arrow, junk | HAS (BagExtras.lua) | - |
| BoE overlay | MISSING | med |
| New-item glow | MISSING | low |
| Sorting (type, quality; skip some slots) | MISSING (Blizzard's button exists) | low |
| Transfer searched items to vendor, bank or mail | MISSING (allowed as a click) | med |
| Separate stacks at vendor/mail | MISSING | low |
| Gold and currency tracking per character | PARTIAL: gold yes (Alts.lua); currencies no | low |
| Auction listings tracked in item counts | MISSING (Inventory.lua covers bags, bank, mail, worn) | low |
| Remove a character from tracking | MISSING | low |
| Plugins, skins, gamepad | low (Skin.lua is our own skin) | low |

### Postal
| Feature | Outrider | Value |
|---|---|---|
| Alts and recent recipients list | HAS (Mailbox.lua Send-to buttons) | - |
| Autocomplete from friends/guild, fill in last recipient | MISSING | low |
| OpenAll unattended | CAN'T; HAS one item per click (Mailbox.lua) | - |
| Open filters (AH sold/expired/outbid/won, attachments only) | MISSING (Collect takes the first mail it finds) | med |
| Keep N bag slots free while collecting | MISSING | med |
| Select: checkboxes plus open/return selected | MISSING | med |
| Express: Shift/Ctrl-click to take, return, attach | MISSING | med |
| Return-or-delete-on-expiry icon (DoNotWant) | PARTIAL: login expiry warning, no per-mail icon | low |
| Rake: gold-collected summary | HAS (total on button, Ledger.lua) | - |
| QuickAttach trade goods by type | MISSING | med |
| Forward, CarbonCopy | MISSING | low |
| Wire: subject from the money amount | MISSING | low |
| TradeBlock while the mailbox is open | MISSING (auto-decline; borderline) | low |

### Titan Panel
| Feature | Outrider | Value |
|---|---|---|
| Ammo, Bag, Clock, Gold, XP, Performance (fps, latency) | HAS (InfoBar.lua) | - |
| XP per hour, time to level | MISSING (Alts.lua run stats only) | med |
| Location (zone name plus coordinates) on the bar | MISSING (coordinates sit under the minimap) | med |
| Loot type (loot method, instance difficulty) | MISSING | low |
| Regen (HP/mana per second) | MISSING | low |
| Repair cost on the bar | PARTIAL: durability shown; cost only at the vendor | med |
| Volume control | MISSING | low |
| Memory per addon | MISSING | low |
| Two bars, top and bottom; DataBroker plugins | MISSING (one bar; no LDB feeds) | med (LDB lets other addons appear) |

### Rucksack Forever
| Feature | Outrider | Value |
|---|---|---|
| Category rows, packed layout, Tidy sorting | MISSING | high |
| "Always sell" list beyond greys, "sell once", "send to bank" lists | MISSING (Merchant.lua sells greys only) | high |
| Sell on vendor open | CAN'T (our button could sell the lists) | - |
| Explain why an item wasn't sold | MISSING | low |
| Keep N slots free | MISSING | med |
| Special-bag colours (quiver, herb, soul) and a quiver window | PARTIAL: ammo count only | med |
| Quest marks on quest items in bags | MISSING | med |
| Hidden-items bag | MISSING | low |
| Restock cart (buys from vendors) | CAN'T as auto-buy; MISSING as a "buy restock" button (ammo, food, water) | high |
| Auto-delete cheapest junk when bags are full | CAN'T; MISSING "delete cheapest junk" button | med |
| Delete prompt naming what the item is needed for | MISSING | med |
| Auto-open clams and pouches | CAN'T; MISSING click-to-open button | low |
| Deleted-items history | MISSING | low |
| Eat/drink button, use-first order, food level rules | PARTIAL: BagFood.lua {FOOD}/{DRINK} macros, conjured first; no per-food never/first rules | med |
| Delete food below your level | MISSING | low |
| Buff food and Well Fed reminder | MISSING | med |
| Darkmoon Faire tickets, prize planner, farm spots, dates | MISSING (quest data only) | low |
| Mage scroll decipher macro | MISSING | low |
| Pocket summary (bag space, next food, vendor value) | PARTIAL: InfoBar.lua | low |
| Version notice from group members | HAS (Updates.lua, KitShare) | - |
| Bug report export | HAS (/ride errors, export) | - |

### DaylightUI
| Feature | Outrider | Value |
|---|---|---|
| Full unit, party and raid frame replacements | PARTIAL: UnitLook.lua is look-only, on purpose | low |
| Cast bars on frames and plates | MISSING | low |
| Swing / Auto Shot timer | MISSING (no combat log needed: spellcast events) | high (hunter) |
| Action bar layout, cooldown manager | MISSING (Edit Mode) | low |
| Nameplates: cast bars, interrupts, your debuffs, threat | PARTIAL: quest and rare marks only | med |
| Buffs grouped and colour-coded by dispel type | MISSING | low |
| Threat meter | MISSING (already marked Add yesterday) | med |
| Damage meter in the info panel | CAN'T live; Blizzard's meter exists | - |
| Quiet chat that fades when not in use | PARTIAL: Chat.lua spam mute | low |
| Quest tracker and world marker | HAS (QuestTracker.lua, QuestExtras.lua) | - |
| One grouped, searchable bag and bank window | MISSING | high |
| Restyled windows | PARTIAL: Skin.lua | low |
| Loot feed | PARTIAL: LootLog.lua (fishing and herbs only) | med |
| Soft AFK screen, campfire glow | MISSING | low |
| Unlock and drag with grid snapping, one font/accent/scale setting | PARTIAL: Theme.lua, Setup.lua scale | low |
| Profiles per character or spec, share as a string | HAS (/ride export, import) | - |

### Pass 1 top 10
1. **A bag window with categories.** One window for bags and bank, rows by item kind, search that lights up matching slots, a BoE mark, and a view of each alt's bags.
2. **Sell lists beyond greys.** "Always sell" and "sell once", learned from what you sell, sold by the Merchant button you already click.
3. **A restock button.** One click at a vendor buys ammo, food and water up to set amounts, with a gold reserve.
4. **Auto Shot / swing timer.** No combat log needed.
5. **Mailbox upgrades.** Open filters, keep free slots, select-and-return, Shift-click take, QuickAttach.
6. **Info bar additions.** XP per hour and time to level, zone name with coordinates, repair cost, DataBroker feeds.
7. **Faster auto loot and mute chosen sounds.**
8. **Text and window sizes.** Bigger quest, mail and book text, a wider quest log, a bigger trainer window with a Train-all button.
9. **Food rules and a Well Fed reminder.** Delete-old-food and delete-cheapest-junk buttons.
10. **Map additions.** Undiscovered areas list, cursor coordinates, fishing skill per zone.

Beyond yesterday's list, Pass 1 adds these as CAN'T: auto-confirming loot warnings, auto-opening clams, auto-deleting junk, auto-removing transforms, and auto-buying a restock list. For each, a one-click button stays inside the rules.

---

## Pass 2: rares, navigation, gathering, layers, lockouts

Sources: the CurseForge pages for RareScanner, Deathskip, Layer-Swap, Nova World Buffs and Nova Instance Tracker. For TomTom, GatherMate2 and HandyNotes, this pass worked from their well-known option lists without fetching the pages.

### RareScanner
| Feature | Outrider | Value |
|---|---|---|
| Nameplate, target and mouseover detection | HAS: RareScan.lua | high |
| Vignette detection | HAS: RareScan.lua ScanVignettes, logged to test constraint C9 | med |
| Macro mode (one macro that targets every rare) | HAS: RareMacros.lua "Outrider Scan" | high |
| Custom NPC alerts | HAS: `/ride watch`, RareScan watchlist | high |
| Pop-up, sound, Target button, tame button | HAS: RareAlerts.lua | high |
| Choice of alert sound | PARTIAL: `soundName` setting exists; no picker or preview | low |
| Mini 3D model in the alert | MISSING: no PlayerModel or ModelScene anywhere | med |
| Loot list and loot bar in the alert and map tooltip | MISSING: rare packs hold no drops | med |
| Loot filters (quality, usable, upgrade, drop %) | MISSING | low |
| Explorer: find which rare drops an item | MISSING (Journey searches rares, not drops) | low |
| Every spawn spot on the map | ~~PARTIAL: one pin per rare~~ **HAS since 2026-11-17** (see the note at the top) | high |
| Guidance icons (how to force a spawn, open a chest) | MISSING | low |
| Rare route through the map's rares, drawn on map and minimap | MISSING: Journey and Travel route to one target only | high |
| Treasures and containers | MISSING: no chest/treasure capture or pins | med |
| Events | MISSING | low |
| Filters: hide a rare from the map, alerts or alert button | PARTIAL: alert mode is all/pack/watch and map pins can be hidden as a group; no per-rare hide | med |
| Respawn telemetry and export | HAS (no export): Sightings, SpawnLog, RareShare | med |
| Nearby-entity list button (several at once) | PARTIAL: one toast per rare, no stacked list | low |
| Waypoint to the rare | HAS: RareAlerts arrow and map card Waypoint button | high |
| Nameplate range hint | MISSING: no check of `nameplateMaxDistance` (a setting Gary changes himself, never auto) | med |
| Hardcore elite import lists | MISSING | low |

### TomTom
| Feature | Outrider | Value |
|---|---|---|
| `/way x y [title]` | HAS: Waypoints.lua | high |
| `/way <zone> x y` | MISSING: current map only | med |
| Many waypoints at once, a queue, auto-advance | MISSING: one waypoint at a time | high |
| `/cway` (go to the closest waypoint), `/wayback` | MISSING (`/ride near` covers services) | low |
| Waypoints kept across sessions | MISSING: non-persistent | med |
| Crazy arrow (own arrow, colour by heading, distance, ETA) | PARTIAL: uses Blizzard's supertrack marker with distance (the "none" fallback arrow, P3-02, is only a comment); no ETA | med |
| Clear on arrival | HAS: `arrive` 10 yards, `autoClear` | med |
| Arrival sound or message | MISSING | low |
| Click the map to set a waypoint | PARTIAL: map pin card has a Waypoint button; no click-anywhere (the client's own Ctrl-click may do it) | med |
| Waypoint pins and tooltips on map and minimap | PARTIAL: Blizzard's own pin only | low |
| Corpse arrow after you release | MISSING: no GetCorpseMapPosition; on death it points at a spirit healer instead | high |
| Player coordinates | HAS: Coords.lua | med |
| Cursor coordinates on the world map | MISSING | med |
| Coordinate feed and LDB | N/A | low |
| Hand waypoints to TomTom when it's installed | HAS: Waypoints backend | med |

### GatherMate2
| Feature | Outrider | Value |
|---|---|---|
| Record herb and ore nodes when you gather | HAS: LootLog.lua | high |
| Fishing spots and pools | HAS: LootLog, MapPins | med |
| Treasure chests and gas clouds | MISSING | low |
| World map and minimap pins | HAS: MapPins, MinimapPins | high |
| Imported world database | HAS: NodePack.lua (Outrider_Data_Nodes) | high |
| Filter by profession and skill | HAS: NodePack skill-aware, `aboveSkill` | high |
| Per-node-type filter (show only Copper or Peacebloom) | MISSING: only the whole group switches | med |
| Separate world map and minimap switches per type | PARTIAL: one hidden list | low |
| Icon size and transparency | MISSING: fixed size | low |
| Merge duplicate nodes | HAS: merged within 0.6% of the map | med |
| Delete one node, cleanup tool | MISSING | low |
| Import and export, share | PARTIAL: guild sharing only (GatherShare) | low |
| Minimap tracking-circle highlight, edge icons | MISSING | low |
| "Picked recently" state | HAS (beats GM2): LootLog up/picked | med |
| Find Herbs reminder | HAS: HerbHelper | med |

### HandyNotes
| Feature | Outrider | Value |
|---|---|---|
| Your own map notes (title, text, icon), add by clicking the map | MISSING | med |
| Edit and delete notes, notes on the minimap | MISSING | med |
| Plugin data packs (treasures, vendors) | PARTIAL: POI and NPC packs draw pins; no third-party plugin API | low |
| Pin scale and transparency per source | MISSING | low |

### Nova World Buffs
| Feature | Outrider | Value |
|---|---|---|
| World buff timers (Rend, Onyxia, Nefarian, ZG) with warnings | MISSING | low (60s raiding) |
| Buff NPC killed or walking alerts | MISSING (chat yells are readable; no combat log needed) | low |
| Songflower, Tuber and Dragon's Breath timers | MISSING | low |
| World buffs across alts | MISSING (Alts has no buff list) | low |
| Darkmoon Faire location and next dates, buff cooldown | MISSING (only quest categories) | med |
| Layer number per zone | HAS: Layers.lua GUID zone UID, label L### | high |
| Layer always visible | PARTIAL: Hub and Rares page only; not on the info bar or minimap | high |
| Timers per layer | HAS for rares (Sightings) | high |
| Disable old layers after a restart | MISSING | low |
| Guild `!wb`, guild-note controls | MISSING | low |

### Nova Instance Tracker
| Feature | Outrider | Value |
|---|---|---|
| Lockouts: 5 an hour and 30 a day, next free slot | HAS: Alts.lua (estimate) | high |
| Re-entering the same instance ID is not counted again | PARTIAL: same map within SAME_RUN counts once; instance ID not used | med |
| Timer starts on leaving, not entering | PARTIAL: `start = now` on entry | med |
| Delete a wrong entry | MISSING | low |
| Tell the group when you reset, hear when the leader resets | PARTIAL: reads "has been reset"; no group message | med |
| Run log: time, XP, kills, gold | HAS: Alts.lua runs (kills from chat lines) | high |
| Run log: group members, average level, level in and out, reputation | MISSING | low |
| Print run stats on leaving | PARTIAL: logged, no opt-in chat line | low |
| Gold trade log | MISSING (Ledger books money; no trade window log) | low |
| Alt window: rested, gold per realm, bags, durability, professions, ammo | HAS: Alts.lua | high |
| Hunter pet stats per alt, reagent counts | PARTIAL: ammo yes; pet details and reagents no | low |
| Raid lockouts and attunements | MISSING: no GetSavedInstanceInfo | low |
| PvP and battleground log | MISSING | low |
| Lockouts on minimap button hover | MISSING | med |

### Deathskip (Forever graveyards)
| Feature | Outrider | Value |
|---|---|---|
| Respawn graveyard decided by subzone (98% vs 78% for nearest) | PARTIAL, often wrong: Nearest.lua picks the nearest spirit healer by distance | high |
| On-screen "you'd respawn at X" box | MISSING | high |
| Map hover: subzone, graveyard and line | MISSING | med |
| Subzone and graveyard borders on the map | MISSING | med |
| Graveyard markers | PARTIAL: spirit healer pins, only once you've met them | med |
| Other faction or both, neutral graveyards | PARTIAL: faction filter on pins | low |
| Record deaths and respawns, predicted vs actual | MISSING (PLAYER_DEAD only, no PLAYER_ALIVE or UNGHOST) | med |
| Unstuck and logout-skip positions | MISSING | low |
| Death sharing | MISSING (could go over guild comms) | low |

### Layer-Swap
| Feature | Outrider | Value |
|---|---|---|
| Current layer from creature GUIDs | HAS: Layers.lua | high |
| Auto-read by flashing nameplates on and off | CAN'T (by rule): changes CVars on its own. Layers stays passive | n/a |
| Visited-layers list with "seen x ago" | MISSING (Layers keeps only the current window) | med |
| Forever world-refresh countdown | MISSING | med |
| Mini bar with layer and status | MISSING (see the NWB row) | high |
| Swap request over hidden addon messages to zone players | PARTIAL possible: opt-in over GUILD or WHISPER only; zone-wide broadcast goes against rule 10 | med |
| Auto-invite as host, auto-leave the group, auto-kick | CAN'T: acts for the player (an Invite button Gary clicks is fine) | n/a |
| Ask your guild | MISSING (Gary would type or click to send) | med |
| "Only new layers", per-layer request | MISSING | low |

### Pass 2 top 10
1. **Graveyard by subzone and a corpse arrow.** Today's "nearest spirit healer" is wrong about 1 time in 5 on Forever. Add a respawn box, PLAYER_ALIVE or UNGHOST logging of predicted vs actual, and a corpse waypoint after release.
2. **Layer always visible**, plus a visited-layers list with ages and the world-refresh countdown.
3. **Rare route** as a waypoint queue on map and minimap. This needs item 4.
4. **Waypoint queue**: several waypoints, auto-advance, persistence, `/ride way <zone> x y`.
5. **Every spawn spot per rare.** Already done on 2026-11-17 (see the note at the top).
6. **Rare toast model and loot.** The loot list needs a cited drop source (rule 7).
7. **Map notes you write.**
8. **Lockout accuracy**: timer from exit, instance ID, delete an entry, group reset notice, lockouts on hover.
9. **Per-node-type and per-rare filters.**
10. **Darkmoon Faire location and dates, cursor coordinates.**

---

## Pass 3: auction house, gear, alts, professions, levelling

Sources: the CurseForge pages, plus known features of Auctionator, TSM and Altoholic: their pages and wiki were thin, and the Auctionator wiki returned a 404.

### Auctionator
| Feature | Outrider | Value |
|---|---|---|
| Prices in tooltips | H, Prices.lua (AH and vendor, warns when vendor pays more) | high |
| Full scan button | H, Prices:FullScan (15 min gap) | med |
| Auto scan when the AH opens | C (it acts on an event) | n/a |
| Shopping lists: named, saved, "search all", import/export | P: the CraftQueue shopping list is made for you; you can't make your own named lists or import/export them | med |
| Search with filters (level, quality, price), search history | M: only the built-in Training/Weapons/Armor/Bags searches | med |
| Selling tab: list of bag items, click to fill the price | P: AuctionHelper suggests a price for the item in Blizzard's sell slot; there is no bag list | med |
| Post button with too-low guard | P: guard and warnings exist (floor = vendor or craft cost + cut + deposit); posting is still done in Blizzard's own frame | med |
| Posting defaults: duration, per-item memory, stack size | P: undercut % or copper only; the duration is fixed at 12 h; no per-item memory | low |
| Undercut scan | H, AuctionHelper:Undercut | med |
| One-click cancel per undercut auction | M (the list only shows them) | med |
| Multi-buy / buy N of a commodity | P: AHBuy confirm bar, one item per click | low |
| Extra result columns (seller, age) | M | low |
| Tooltip disenchant value, stack price on Shift | M | low |
| Craft view: reagent cost, profit, "search reagents" button | P: profit is on MoneyGuide/ProfExtras; there is no button on the profession window | med |
| Price history graph or table | P: 14 days are stored, nothing shows them | low |
| Journalator: sale, buy and expire ledger | P: Ledger books gold by window; there is no per-item sales record and no "sold" or "expired" tracking | med |

### TSM (the parts that fit Classic+)
| Feature | Outrider | Value |
|---|---|---|
| Crafting profit, cost and queue | P: profitable crafts plus CraftQueue; cost only covers vendor or AH reagents, and there is no cost-to-make in item tooltips | med |
| Groups and operations (post, cancel, restock rules) | M | low |
| Custom price strings (dbmarket, min-buyout...) | P: fixed source order (Auctionator > TSM > own history > vendor) | low |
| Mail operations: send groups to alts in one click per mail | P: Mailbox has Send-to name buttons; there is no "send these items to X" attach | med |
| Open all mail | P: one thing per click, with totals | med |
| Gold tracker: graph over time, per character and realm | P: Ledger keeps the last 30 sessions, Alts has gold per character; no graph or history across days | low |
| Sales and purchase accounting | M | med |
| Destroying (disenchant or mill a list) | M (a click per item would be allowed) | low |
| Vendor ops (sell or restock rules) | P: sells junk only; no restock of ammo or food at the vendor | high |

### Pawn
| Feature | Outrider | Value |
|---|---|---|
| Upgrade % in tooltips, arrows on bags and quest rewards | H: GearScore, BagExtras, QuestRewards | high |
| Built-in scale per class | H: Data/StatWeights.lua | high |
| Scale per spec or role, picked from your talents | M: one scale per class | med |
| Custom weights editor (UI, import/export scale string) | P: `Settings().weights` overrides exist but have no UI; `/ride weights` only shows them | med |
| Several scales shown at once (e.g. levelling and dungeon) | M | low |
| Compare window (two items side by side) | P: `/ride score` prints the verdict | low |
| Copy item text (Alt+click) | P: there is a Wowhead link copy | low |
| Gems and enchants in the score | M (they matter little at Classic levels) | low |

### AtlasLoot
| Feature | Outrider | Value |
|---|---|---|
| Browse any boss's full loot table | P: DungeonGuide shows only the upgrades for you | med |
| Crafting tables (materials, skill, result) | P: only recipes you've seen in your own profession windows | med |
| Faction and reputation reward lists | M | med |
| Item sets and world events | M | low |
| Favourites or wishlist (Alt+click, owned marker, tooltip tag, import/export) | M | high |
| Plan gear with an owned marker | P: the Gear page lists upgrades; there is no saved plan | med |
| PvP rewards | M | low |
| Search loot by name | P: the Find bar and Journey search items in the gear pack | low |

### DungeonJournal
| Feature | Outrider | Value |
|---|---|---|
| Quests per dungeon: givers, map location, rewards | M: DungeonGuide has bosses, loot and the entrance, no quests | high |
| Boss drops | P: only items that score for you | med |
| Dungeon tracker during a run | P: Alts run stats (time, XP, gold) with no quest or boss progress | med |
| Click a quest to see its map spot | M for dungeon quests (H for log quests) | high |
| Spoiler "RPG mode" | M | low |
| Interior maps | M (noted already) | low |

### Altoholic / DataStore
| Feature | Outrider | Value |
|---|---|---|
| Alt summary: level, gold, rested, bags, professions | H: Alts.lua | high |
| Groups of alts, bank-alt marking, filters | M | low |
| Bags, bank and mail per alt, viewable | P: counts in tooltips plus `/ride where`; no browsable container view | med |
| Search across alts | H: BagExtras `where` | med |
| Known and unknown recipes for all alts, with materials | P: stored per character; no view across alts | med |
| Recipe tooltip "known by / learnable by alt X" | M | med |
| Reputation per alt | M: Favor.lua reads only one faction | med |
| Skills (weapon, riding) per alt | M | low |
| Equipment per alt | P: worn gear is stored, not shown | low |
| Quest log per alt | M | low |
| Talents per alt | M | low |
| Auctions and bids per alt | P: own auctions are seen only for undercuts | low |
| Cooldowns per alt | H: ProfExtras | low |
| Calendar or agenda | M | low |
| Guild bank and guild members' professions | M | low |

### SkillUp Forever (and Skillwright)
| Feature | Outrider | Value |
|---|---|---|
| Skill-up chance per recipe | H: ProfExtras (estimated from colour) | med |
| Colour thresholds (orange/yellow/green/grey at which skill) | M: only the colour now; needs recipe data | med |
| Recipe cost in the profession window | P: on the Professions page, not in Blizzard's window | med |
| Cheapest route plus shopping list | H: SkillUp.lua plus TrainShop | high |
| Route steps with recipes not yet learned | P: learned recipes only | med |
| Craft button for the current step | H: CookTrainer / Crafter | high |
| Total materials to max skill | P: only up to a target you give | low |
| Bank stock counted in the route | H: SkillUp counts what's in your bags and bank as free | med |

### What's Training
| Feature | Outrider | Value |
|---|---|---|
| Trainable spells with cost | P: ProfExtras, but only after you visit a trainer once; no class spell data | high |
| Shown inside the spellbook (known at the bottom, category totals) | M | med |
| Right-click to ignore a spell | M | low |
| Recipes from trainers, drops, quests and vendors (Forever tab) | M: no recipe source data | high |
| Weapon skill trainers | P: GearScore knows the weapon skills; no trainer list | med |
| Feed for LDB/Titan | M (the info bar is our own) | low |

### Polestar
| Feature | Outrider | Value |
|---|---|---|
| Step-by-step 1-60 route for each race | M: WhatNow and Journey suggest, they don't follow a route | high |
| Steps that tick off by themselves (quest, kill, loot, place) | M | high |
| Skip with undo, look ahead, step browser | M | med |
| Arrow along real paths with yard countdown | P: Waypoints arrow is straight-line; Travel plans the legs | med |
| Travel with timetables, waits, hearth advice | P: Journey/Travel; FlightTimes measures flights; no boat waits | med |
| "While you're here" nearby objectives | P: QuestObjectives pins, not ranked by distance | med |
| Nearest service | H: `/ride near` | high |
| Lookup that builds a guide to any item or NPC | P: Journey search plus Go | med |
| Dungeon quests button | M | high |
| Abandon list (quests that give no XP or never get turned in) | M | med |
| Quest item glow, timed quest countdown | M | med |
| Level-up card: spells to train and cost | P: Errands "visit trainer", plus ProfExtras after a visit | high |
| Upgrade old ranks on bars | H: RankCheck | med |
| Class quest heads-up (pet abilities, class mount) | M | med |
| Friends' positions and what they need; share a missing quest | P: LocationShare plus PartyQuests progress | low |
| Restock food and ammo | P: Errands reminds you; no buy-N button at the vendor | high |
| Protect quest items and keep-marks from selling | P: only greys are sold; no keep or junk marks | low |
| XP per hour, time to level, on pace | M: run stats per dungeon only | high |
| Auto accept/turn in, auto pick reward | C (a reward hint we HAVE) | n/a |
| Characters overview, skins, hide-all toggle | H: Alts, Skin; hide-all M | low |

### Forever Route
| Feature | Outrider | Value |
|---|---|---|
| Plan that loads at any level and skips done quests | M | high |
| "Where to?" zones with XP left per zone and the level you'd reach | P: ZoneLevels plus Journey XP/min; no XP-left total per zone | high |
| Warning that a carried chain goes grey soon | M | med |
| Hand-ins you finished early, shown as you pass | P: ? turn-in pins | med |
| In a dungeon: its quests with live progress | M | high |
| Targeting key for the step NPC, with a star | P: rare Target and rare macros; not for quest NPCs | med |
| Route avoids hostile camps | M | low |
| Class quest side trips | M | med |

### RestedXP
| Feature | Outrider | Value |
|---|---|---|
| Speed-levelling guides with map and minimap steps | M | high |
| Levelling time tracker | M | high |
| Gold assistant routes | P: MoneyGuide | med |
| Talent guide level by level | H: Talents.lua | med |
| Auto train, auto fly, auto quests | C | n/a |

### TurnInXP
| Feature | Outrider | Value |
|---|---|---|
| XP of the whole quest log | H: QuestExtras plus the info bar | high |
| XP of finished quests only ("ready now") | M | high |
| Projected level and % after turn-ins, per-quest hover list | M | high |

### Pass 3 top 10
1. **XP pace.** XP per hour, time to level, and "ready now" turn-in XP with the projected level. It's cheap because the data is already there.
2. **Dungeon quests.** Per dungeon: givers, chains, rewards, map spot, and live progress inside. QuestieDB, which we already import, has this.
3. **Level-up training card without a trainer visit.** This needs a cited spell, rank and cost data pack.
4. **Restock at the vendor.** A "Buy ammo/food to N" button, one click.
5. **Recipe sources.** Unlearned recipes and where to get them, plus colour thresholds.
6. **Step-by-step levelling route.** A big job: either a route data pack, or a "where to?" view with the XP left per zone, the chains about to go grey, and an abandon list.
7. **Gear wishlist.** Alt+click to save, with an owned marker and a tooltip tag, plus any boss's full loot table.
8. **Auction house selling.** A bag list on the Selling tab, one-click cancel per undercut, and a sales, purchases and expired ledger.
9. **Alt detail views.** Reputations, recipes across alts, a "known by alt" tag, and browsable bags, bank and equipment.
10. **Stat weight editor and spec scales.** Pick or edit weights in the UI and import a Pawn scale string.

---

## Pass 4: combat side, tooltips, chat, social, hunter

Sources: the CurseForge and GitHub pages for ThreatTint, Social Diary, MouseOverTooltip, Chattynator, Quiver and Improved Auto Shot Timer. The rest come from known features of each addon. This pass also read the two constraints docs.

**Two facts that change the plan:**
- **ThreatTint already ships on Forever.** So the threat API is probably readable in combat there, but we still need an in-combat probe.
- **Forever has Blizzard's own swing timers** (SwingTimerMainHand/OffHand/Ranged in Edit Mode, docs/PROBE_RESULTS.md:113). Improved Auto Shot Timer and Shot Window only draw on top of the ranged one. So a "stop moving" mark for hunters is cheap.

### ThreatTint
| Feature | Outrider | Value |
|---|---|---|
| Colour nameplate health by threat (DPS: green, then yellow, orange, red) | MISSING. UNSURE whether threat values are secret in combat: needs `UnitDetailedThreatSituation("player","nameplateN")` and a colour hook on Blizzard's bar (the same hook trick as UnitLook.lua). Safer: our own tint frame on the plate (RarePlates.lua pattern) | high |
| Pet threat colour (blue = pet has it, fades as you near pulling it) | MISSING, same API with "pet" | high |
| Threat % next to each plate | MISSING, UNSURE (secret) | med |
| Pulse when threat climbs fast (pull in about 3 s) | MISSING. Pure maths on threat values: CAN'T if they are secret | low |
| Tank mode, role detection (stance, form, Righteous Fury), `/tint check` | MISSING | low |

### ThreatClassic2
| Feature | Outrider | Value |
|---|---|---|
| Group threat bars on your target | MISSING. UNSURE: `UnitDetailedThreatSituation` for each group unit, plus `UNIT_THREAT_LIST_UPDATE` | med |
| Warning sound or flash at a set threat % | MISSING. CAN'T if the value is secret; the status from `UnitThreatSituation` (0-3) may still work | med |
| Pet in the list, tank mode | MISSING | med |

### Plater / Threat Plates
| Feature | Outrider | Value |
|---|---|---|
| Quest objective on plates | HAS (QuestExtras.lua) | - |
| Rare marker | HAS (RarePlates.lua) | - |
| Threat colours | MISSING (see ThreatTint) | high |
| Custom colour or icon per NPC ID (dangerous mobs, casters) | MISSING. Possible: our own overlay keyed by npcID, which is readable in combat (probe) | med |
| Health % or value text | UNSURE: health is secret in combat. Midnight's `UnitHealthPercent` plus a FontString may display it without maths | med |
| Target highlight, glow, execute-range colour | Highlight MISSING (possible). Execute range CAN'T (compares secret health) | low |
| Bar and font restyle, plate size | MISSING; RarePlates says styling is left to the client. "One owner" risk | low |
| Your debuffs on plates (Serpent Sting timer) | UNSURE: auras secret in combat; Blizzard's plates already show them | med |
| Cast bars on enemy plates | Blizzard has them; UNSURE (`UnitCastingInfo` may be secret) | low |
| Scripts and mods engine | CAN'T in practice (WeakAuras-like) | low |

### ElvUI / DaylightUI (unit frames, bars, castbars)
| Feature | Outrider | Value |
|---|---|---|
| Flat textures, class-coloured health | HAS (UnitLook.lua) | - |
| Window skin | HAS (Skin.lua) | - |
| Own player, target, ToT and pet frames | MISSING. Possible out of combat with secure unit buttons (proven by HealPanel.lua); health goes straight into the bar | low |
| Target-of-target, focus frames | Blizzard's own; Edit Mode | low |
| Health and power text (value, %) | UNSURE (secret in combat); out of combat, yes | med |
| Range fade on frames | PARTIAL: HealPanel fades out-of-range bars, nothing else does | low |
| Castbar restyle, latency zone | UNSURE: PlayerCastingBarFrame is an Edit Mode system; no latency mark | low |
| Buff and debuff filtering and timers | UNSURE (auras secret in combat) | low |
| Layout per context | HAS (ContextLayouts.lua) | - |

### Bartender4 / OmniCC
| Feature | Outrider | Value |
|---|---|---|
| Extra bars, paging, fade out of combat | MISSING. Edit Mode covers most; UnitLook declines the fade on purpose | low |
| Out-of-range button tint | MISSING (UnitLook: "no verified API"). UNSURE: `C_Spell.IsSpellInRange`, `ActionButton` hooks | med |
| Keybind text tidy, hide macro names | MISSING, cosmetic | low |
| Cooldown numbers | Blizzard's built-in countdown; durations secret in combat | low |
| Finish pulse, colour by time left | CAN'T (computes on secret cooldowns) | low |

### Prat 3.0
| Feature | Outrider | Value |
|---|---|---|
| URL copy, timestamps, keyword highlight, spam mute, copy chat | HAS (Chat.lua) | - |
| History after /reload | PARTIAL: only 50 lines (Tweaks.lua) | med |
| Class-coloured names | MISSING. Blizzard's chat setting for class-coloured names may exist; toggle it like timestamps | med |
| Short channel names ([2. Trade] to [T]) | MISSING (Chat.lua: would need to replace AddMessage) | low |
| Alt-click a name to invite | MISSING in chat; only on the Players page (Census) | low |
| Search chat history | MISSING | low |
| Sticky channels, editbox history, arrow-key recall | MISSING | low |
| Sound per channel or keyword | MISSING | low |
| Mouse-wheel scroll, no fade, font size | MISSING | low |

### Chattynator
| Feature | Outrider | Value |
|---|---|---|
| 2,500+ messages saved across sessions | PARTIAL (50) | med |
| Typed-message history across sessions | MISSING | low |
| Replacement chat frame and themes | MISSING. It replaces Blizzard's chat frame, which hard rule 8 avoids | low |

### WIM
| Feature | Outrider | Value |
|---|---|---|
| Whisper windows per person | MISSING | med |
| Saved whisper history per person | MISSING. Cheap: Chat.lua already filters `CHAT_MSG_WHISPER` | med |
| Pop-up or minimap flash and sound on new whisper | MISSING (needs Gary's OK under rule 6) | med |
| Who-info in the window (level, class, guild) | PARTIAL: the data exists in Census | low |

### Social Diary
| Feature | Outrider | Value |
|---|---|---|
| Nearby and last-seen players | HAS (Census.lua, PlayerInfo.lua) | - |
| Duel stats | HAS (PlayerInfo duel record) | - |
| Your own path on the map | HAS (Trail.lua) | - |
| A page per player: grouped, questing, dungeons, trades | MISSING. Possible from group-roster, trade and party events | med |
| Your own notes per player | MISSING | med |
| Known player or foe in view: toast and sound | MISSING. Possible from nameplates and mouseover | med |
| Heatmap of where you meet someone | MISSING | low |
| Who killed you, who watched you die, world PvP kills | CAN'T (combat log) | - |
| Auto diary (close calls, lucky drops, first blue, profession caps) | PARTIAL: LootLog.lua and Journey.lua cover some | low |

### MouseOverTooltip / TipTac
| Feature | Outrider | Value |
|---|---|---|
| Item level, target line, class border, health bar | HAS (PlayerInfo.lua, Tooltips.lua) | - |
| Quest progress on mob tooltips ("4 left") | PARTIAL: tooltips name the quest (QuestInfo); the count is on plates only | med |
| Hide tooltip in combat, Shift shows it | MISSING (easy) | med |
| Anchor at the cursor, scale, font | MISSING | low |
| Targeted by (which party members target it) | MISSING. Possible: compare GUIDs of `partyNtarget`, readable per probe | low |
| Mount being ridden | MISSING | low |
| Item, spell and NPC IDs | MISSING (the Wowhead link exists in Tweaks) | low |
| Guild rank, realm, reaction colour, level coloured by difficulty | MISSING | low |
| Turn each line on or off | PARTIAL: modules can be switched, single lines can't | low |

### Clique / HealBot / VuhDo
| Feature | Outrider | Value |
|---|---|---|
| Click-to-heal bars, Shift-click | HAS (HealPanel.lua) | - |
| Assigned players | HAS (HealPanel.lua) | - |
| Pet bar with Mend Pet | HAS (HealPanel.lua) | - |
| Click-casting on Blizzard's own frames (Clique) | MISSING. UNSURE: needs `ClickCastFrames` or Blizzard's click-casting | low |
| Hover keybinds (cast on the unit under the mouse) | MISSING; needs SecureHandler wrap scripts | low |
| Ctrl and Alt modifiers, middle button | PARTIAL: Shift and left/right only | low |
| Debuff and dispel highlight | UNSURE (auras secret in combat) | low |
| Incoming heals, aggro border | Incoming heals UNSURE (`UnitGetIncomingHeals`); aggro border via `UnitThreatSituation`, UNSURE | med |

### Hunter class addons (Quiver, ZHunterMod, Improved Auto Shot Timer)
| Feature | Outrider | Value |
|---|---|---|
| Auto Shot timer with a "stop moving" mark | MISSING. Blizzard draws the bar; add an overlay from `UNIT_SPELLCAST_SUCCEEDED` (Auto Shot) and `UnitRangedDamage` speed. UNSURE whether the speed is readable in combat | **high** |
| Range and dead-zone marker (green, red, too close) | MISSING. UNSURE: `C_Spell.IsSpellInRange("Auto Shot","target")` in combat | **high** |
| Aspect tracker or "no aspect" warning | PARTIAL: HunterFight.lua reads Hawk and Monkey for its macros; no on-screen indicator | med |
| Ammo count and low warning | HAS (Ammo.lua, InfoBar.lua) | - |
| Pet happiness | MISSING: no API on Forever (PROBE_RESULTS.md:36,59). PetStatus logs auras to find it | high (if it exists) |
| Pet loyalty | UNSURE: the pet window shows it; API unknown | low |
| Feed button, learned diet | HAS (PetStatus.lua) | - |
| Growl autocast left on in a group: warning | MISSING. Possible out of combat with `GetPetActionInfo` (PetStatus already reads autocast) | med |
| Castbar for Aimed and Multi-Shot | Blizzard's castbar; no extra need | low |
| Tranq Shot announce | MISSING. Cast via `UNIT_SPELLCAST_SUCCEEDED`, PARTY/RAID only, opt-in. The miss line is CAN'T (combat log). Level 60 | low |
| Feign Death + trap, pet-action helpers (Lua) | PARTIAL: MacroEngine and RareMacros write macros; Feign Death + trap macro MISSING. One press is fine | low |
| Trueshot Aura reminder | PARTIAL (macros re-add missing buffs) | low |

### Pass 4 top 10
1. **Auto Shot "stop moving" mark plus range and dead-zone marker** on Blizzard's ranged swing timer. Probe `UnitRangedDamage` and `C_Spell.IsSpellInRange` in combat first.
2. **Threat tint on nameplates, with pet threat.** Probe `UnitDetailedThreatSituation` on nameplate units in combat; draw our own tint or use a colour hook, not a restyle.
3. **Pet happiness.** Finish the aura or `C_StableInfo` hunt that PetStatus logs.
4. **Small threat list**: you, your pet, the group on your target, and a warning when status reaches 2-3.
5. **Growl-in-group warning plus an aspect indicator.**
6. **Whisper history and alert.**
7. **Tooltip: hide in combat (Shift shows it), plus the quest "X left" count on mob tooltips.**
8. **Player notes, and a "known or foe player in view" toast.**
9. **Longer chat history plus class-coloured names.**
10. **Custom colour or icon per NPC ID on nameplates.**
