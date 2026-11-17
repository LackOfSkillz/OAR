# What the top WoW addons have that Outrider doesn't (2026-11-17)

Gary asked: research the top 50 Warcraft addons, find features they have that
Outrider doesn't, and break it down so we can decide what to add ("we want to
have everything the top 50 have").

**How:** the ~55 most-downloaded addons on CurseForge (sorted by total
downloads), cross-checked with 2026 "best WoW Forever addons" guides, compared
with Outrider's 89 modules and the in-game Help.
Sources are at the bottom.

**Key:**
- ✅ = Outrider has it.
- ◐ = partly.
- ✗ = missing.

**What we suggest:**
- **Add**: worth building.
- **Later**: fine, but low value now.
- **Can't**: breaks a hard rule or the client blocks it.

## The short version

- **Outrider already covers more of these addons than you'd think.**
  - Rares (RareScanner), waypoints and travel (TomTom, Shortest Path) and gathering spots (GatherMate2).
  - Gear advice (Pawn, GearQuest), fishing, skill-up planning (SkillUp), the auction shopping helpers (Auctionator, partly), gear sets (ItemRack) and click-heal (HealBot, Clique).
  - Chat highlights and copy (Prat, partly), the dark skin (BetterBlizzFrames) and error capture (BugSack).
- **The biggest real gaps:**
  1. **A bag window.** One combined bag, search, item level, upgrade arrows and junk marks on slots, alts' bags anywhere (Bagnon, Baganator).
  2. **A full mailbox.** Open all with one click per mail, send to alts, a contact list and expiring-mail warnings (Postal).
  3. **An info bar.** Gold, durability, bag space, ammo, XP, clock and latency in one strip (Titan Panel).
  4. **Map extras.** Reveal unexplored areas, dungeon entrances, flight times, zone jump menu, dungeon interior maps (Leatrix Maps).
  5. **An alt overview.** Rested XP, gold, bags, durability, professions, lockouts (Nova Instance Tracker).
  6. **Dungeon lockouts and run stats.** 5 per hour and 30 per day, XP and gold per run (Nova Instance Tracker).
  7. **Quality-of-life toggles.** Hide clutter, camera max zoom, mute sounds, square minimap, minimap button bag, faster loot (Leatrix Plus).
  8. **Quests.** We lean on Questie today. Missing: quest markers on nameplates, quest XP on the XP bar, the best sell price on quest rewards.
- **What we can't copy** (a rule or the client stops it):
  - Anything that acts for you: auto accept quests, auto sell or repair when you open a vendor, auto invite on a whispered keyword, auto release. Outrider gives a one-click button instead.
  - Anything built on the combat log: real-time damage meters, boss timers, WeakAuras-style triggers, enemy player detection like Spy.
- **Not worth building:** retail-only Mythic+ and world-quest tools, and loot council or GDKP tools. Raid tools come later, if ever.

## The full breakdown by category

### Bags, vendor and loot
| Feature | Who has it | Outrider | Suggestion |
|---|---|---|---|
| One combined bag window, bank and alts viewable anywhere | Bagnon, Baganator | ✗ (only tooltip counts) | **Add**: big job, highest-value gap |
| Cross-character counts in item tooltips | Bagnon, Syndicator | ✅ "You have 12 (Torrant 8...)" | n/a |
| Search across all characters' bags, bank, mail | Baganator | ◐ data is stored, no search box | **Add** (easy once bags exist; Find bar can do it now) |
| Item level / upgrade arrow / BoE / junk overlay on bag slots | Baganator, Pawn | ✗ | **Add**: we already score gear |
| Bag sorting | Baganator | ✗ (Blizzard has a sort button) | Later |
| Free bag slot count | Leatrix Plus, OneForAll | ✗ | **Add** (info bar) |
| Sell junk | Leatrix, Scrap | ✅ button, your click | n/a |
| Sell junk *automatically* when the vendor opens | Leatrix, Scrap | n/a | **Can't**: no automation (button instead) |
| Junk beyond greys, learning what you always sell | Scrap | ✗ | **Add** (marks + button sells them) |
| Repair | Leatrix, Scrap | ✅ button | n/a |
| Faster auto loot | Leatrix, Speedy AutoLoot | ✗ | Later (it's a game setting, "auto loot" CVar, we could toggle it) |
| Loot feed (what dropped, value) | OneForAll | ◐ fishing/herb log only | Later |
| Easy item destroy | Leatrix Plus | ✗ | Later |
| Ammo count on quiver | OneForAll | ◐ warnings at 200/50 | Later (info bar) |

### Mail
| Feature | Who has it | Outrider | Suggestion |
|---|---|---|---|
| Collect money and items | Postal, TSM | ◐ Collect button, one item per click | **Add**: "open all" that still goes one click per mail, plus a total |
| Send to alts: contact book of your characters and recent names | Postal | ✗ | **Add** |
| Quick-attach trade goods or a stack type | Postal | ✗ | Later |
| Expiring-mail warning | Titan Panel | ✗ | **Add** (we already read mail) |
| Gold-from-mail summary | Postal | ◐ ledger books it | n/a |

### Info bar and alts
| Feature | Who has it | Outrider | Suggestion |
|---|---|---|---|
| A strip with gold, bags, durability, XP, clock, FPS/latency, location | Titan Panel, OneForAll | ✗ (coords under minimap only) | **Add**: cheap, visible every minute |
| Durability on character frame and a low-durability warning | Leatrix, OneForAll | ✗ (Errands says repair) | **Add** |
| Alt overview: gold, rested XP, bags, durability, professions, ammo, pet | Nova Instance Tracker | ◐ Characters page lists them | **Add**: we already store most of it |
| Total gold per realm | Nova, Titan | ◐ ledger | **Add** (alt overview) |

### Maps and travel
| Feature | Who has it | Outrider | Suggestion |
|---|---|---|---|
| /way waypoints and an arrow | TomTom | ✅ | n/a |
| Corpse and nearest-service waypoints | TomTom, Shortest Path | ✅ spirit healer, /ride near | n/a |
| Route planning over flights, boats, portals | Shortest Path | ✅ Journey | n/a |
| Zone level ranges on maps | Leatrix Maps | ✅ | n/a |
| Coordinates | Leatrix, TomTom | ✅ | n/a |
| Reveal unexplored map areas | Leatrix Maps, OneForAll | ✗ | **Add**: needs map overlay data; check what the Forever client allows |
| Dungeon and raid entrances, boats, zeppelins, portals on the map | Leatrix Maps, MapUtils | ◐ entrances via Dungeons page Go button | **Add** pins |
| Flight times on the flight map | Leatrix Plus | ✗ | **Add**: we can time flights you take |
| Dungeon interior maps with bosses | Leatrix Maps, DungeonJournal | ✗ | Later (needs map art) |
| Move, scale, fade the world map | Leatrix Maps | ✗ | Later |
| Guild members on the world map | OneForAll | ◐ location sharing exists, off by default | **Add** pins for shared locations |
| Map notes you write | HandyNotes | ✗ | Later |
| Boat arrival sound | Shortest Path | ✗ | Later |

### Quests
| Feature | Who has it | Outrider | Suggestion |
|---|---|---|---|
| Quest givers, objectives and turn-ins on the map; a tracker for every quest | Questie | ◐ quest pins (/ride questpins); steps aside for Questie | n/a: Questie does it well and is installed |
| Quest markers over mobs' nameplates | OneForAll, Plater | ✗ | **Add**: nameplate star code already exists |
| Quest XP on the XP bar (how much your log is worth) | OneForAll | ✗ | **Add** |
| Best vendor price on quest rewards | OneForAll | ◐ we name the best reward for you | **Add** "else take the most valuable" |
| Auto accept and turn in quests | Leatrix, OneForAll | n/a | **Can't**: no automation |
| Step-by-step leveling route | RestedXP | ◐ What now? and Journey | Later (big content job) |
| Tint quests that are new on Forever | Forever Quest Tint | ✗ | Later (needs a source list) |
| Dungeon quest share check (who can still take it) | OneForAll | ✗ | Later |
| Quest text read aloud | Spoken | ✗ | Later (needs AI voice files) |

### Rares and world
| Feature | Who has it | Outrider | Suggestion |
|---|---|---|---|
| Rare detection, alert, spawn spots, custom NPC alerts, respawn timing | RareScanner | ✅ all of it | n/a |
| Rare's 3D model and loot in the alert | RareScanner | ◐ name and Target button | **Add** model + loot list |
| Route through every rare on a map | RareScanner | ✗ | **Add**: Journey can chain them |
| Layer display | Layer-Swap, Nova | ✅ | n/a |
| Layer swap requests between players | Layer-Swap | ✗ | Later (guild feature) |
| World buff timers, Darkmoon Faire | Nova World Buffs | ✗ | Later (60s and raiding) |
| Nearby beasts that teach higher pet ranks | OneForAll | ◐ tame helper, beast tooltips | **Add** (hunter, Gary's main) |

### Professions and money
| Feature | Who has it | Outrider | Suggestion |
|---|---|---|---|
| Cheapest skill-up route, shopping list | SkillUp, OneForAll | ✅ | n/a |
| Skill-up chance per recipe | SkillUp | ◐ recipe colours | **Add** % chance |
| Unlearned recipes and where to get them | SkillUp, What's Training | ✗ | **Add** |
| Who in your guild or alts knows a recipe | OneForAll, Profession Master | ◐ alts only (stored) | **Add** guild via sharing |
| Craft profit right now | TSM, OneForAll | ◐ prices known | **Add** "profitable crafts" list |
| Disenchant value in tooltip | OneForAll | ✗ | Later |
| Craft cooldown reminders (mooncloth, transmutes) | TSM | ✗ | **Add** (Khreos's alchemy later) |
| AH: undercut detection, cancel, post with too-low guard | Auctionator | ◐ price suggestion, undercut setting | **Add** "you've been undercut" list |
| AH: shopping lists, search history | Auctionator | ◐ Training/Bags tabs | Later |
| AH price history graph | TSM | ◐ 14 days stored | Later |

### Gear, class and dungeons
| Feature | Who has it | Outrider | Suggestion |
|---|---|---|---|
| Upgrade arrows, stat weights, best per slot, drop toast | Pawn, GearQuest | ✅ | n/a |
| Loot tables and BiS lists | AtlasLoot | ◐ dungeon loot for you only | Later |
| Item set bonuses you own | OneForAll | ✗ | Later |
| Gear sets | ItemRack | ✅ | n/a |
| Trainer spells coming next, with cost | What's Training | ◐ errands remind you to train | **Add** list with costs |
| Old spell rank warning | OneForAll, Glowing Bars | ✅ | n/a |
| Talent planner | Talents Forever | ✅ advisor | n/a |
| Dungeon lockouts: 5 per hour, 30 per day | Nova Instance Tracker | ✗ | **Add** |
| Run stats: XP/hr, gold, mobs per run | Nova Instance Tracker | ✗ | **Add** |
| Attunement chains | Attune | ✗ | Later (60s) |

### Interface, minimap, tooltips, chat
| Feature | Who has it | Outrider | Suggestion |
|---|---|---|---|
| Hide clutter: gryphons, zone text, error text, talking head | Leatrix, OneForAll | ◐ gryphons | **Add** the rest (toggles) |
| Camera max zoom out | Leatrix, OneForAll | ✗ | **Add** (a game setting) |
| Mute chosen sounds | Leatrix | ✗ | Later |
| Move or resize any Blizzard frame | MoveAny, BlizzMove | ✗ (Edit Mode only) | Later: "one owner per frame" risk |
| Square minimap, minimap button bag | Leatrix, MinimapButtonButton | ✗ | **Add** button bag |
| Action bar replacement, cooldown numbers on buttons | Bartender4, OmniCC | ✗ | Later; Blizzard's bars and cooldown numbers are decent now |
| Glow on buttons for missing buffs or low reagents | Glowing Bars | ◐ macros rewrite for missing buffs | Later |
| Nameplate restyle, threat colours | Plater, Threat Plates | ✗ (rare star only) | Later; Midnight cut what's allowed |
| Threat meter | ThreatClassic2 | ✗ | **Add** small one: the threat API exists (probe) |
| Vendor price and boss drop source in tooltips | Leatrix, OneForAll | ◐ AH and vendor price | **Add** drop source |
| Copy a Wowhead link | Leatrix | ✗ | **Add** (cheap, helps when asking for advice) |
| Chat class colours, URL copy, history across reloads, search | Prat | ◐ copy last 100, highlights | **Add** URL copy and history |
| Whispers as chat windows | WIM | ✗ | Later |
| Alt-click a name to invite | Prat | ◐ Players page | n/a |
| Block duels and invites from strangers | Leatrix | ✗ | **Add**: declining is a click Blizzard allows; check it's allowed |
| Auto accept invites from friends, summons, res | Leatrix | n/a | **Can't**: no automation (we could show a one-click prompt) |

### Can't do, and why
| Feature | Who has it | Why not |
|---|---|---|
| Real-time damage/healing meter | Details | The combat log is closed; Blizzard's own meter exists (we read it after fights) |
| Boss timers and warnings | DBM, BigWigs | No boss timers in Forever; Blizzard's Boss Warnings replace them |
| Custom aura and cooldown triggers | WeakAuras | Doesn't load on Midnight; buffs and cooldowns are secret in combat |
| "Stop standing in fire" | GTFO | Combat log |
| Rotation helper | Hekili | Dead on Midnight; Blizzard has Assisted Highlight; our Fight macros cover it |
| Enemy player detection, kill-on-sight list | Spy | Combat log |
| Anything that acts for you | Leatrix and others | Hard rule 1 (advice only, D18) |
| Mythic+, world quests, Raider.IO scores | MDT, WQT, Raider.IO | Retail-only content |

## Built on 2026-11-17 (Gary: "build the top eight")

| # | What | Where in game |
|---|---|---|
| 1 | Info bar: gold (all characters on hover), bag space, durability (worst item), ammo, XP with rested and quest XP, clock, latency, a landing countdown on flights | top of the screen; Settings > Info bar; /ride bar |
| 2 | Alt overview, dungeon lockouts (5 an hour, 30 a day), run stats | My characters page; /ride runs |
| 3 | Dungeon entrance pins, flight times (timed as you fly) | world map and minimap; flight map tooltip |
| 4 | Quest marks with what's left beside quest mobs' nameplates, quest log XP, reward value incl. auction house | nameplates; info bar; quest turn-in |
| 5 | Mailbox: totals on Collect, Send to your alts and recent names, expiring-mail warning | mailbox; login line; My characters |
| 6 | Bag slots: item level, upgrade arrow, junk coin; find an item on any character | Blizzard's bags; My characters; /ride where |
| 7 | Small switches: hide zone names, error text, talking head; camera zoom; gather minimap buttons; keep chat after a reload; Wowhead link | Settings > Small switches; key binding; /ride wowhead |
| 8 | Trainer list (learn now, next, cost), skill-up chance, craft cooldowns, profitable crafts, undercut auctions | Professions page |

Not covered by these eight and still open: a full bag window replacement, reveal
unexplored map, dungeon interior maps, unlearned recipes from drops and vendors
(needs a recipe data source), and everything marked Later above.

## What we'd build first

Biggest daily payoff for the least work:
1. **Info bar**: gold, bag space, durability, ammo, XP, clock, latency.
2. **Alt overview, dungeon lockouts and run stats**: most of the data is already stored.
3. **Map extras**: dungeon entrances, boats and portals as pins, flight times, guild members' shared locations.
4. **Quest add-ons**: nameplate quest markers, quest XP on the XP bar, the most valuable reward to sell.
5. **Mailbox**: open all (one click per mail), send to alts, expiring-mail warning.
6. **Bag window**: one bag, search across characters, item level and upgrade marks on slots. This is the biggest job.
7. **Small switches**: hide clutter, camera zoom, minimap button bag, Wowhead link copy, chat URL copy and history.
8. **Professions**: % skill-up chance, unlearned recipes with sources, profitable crafts, craft cooldowns, "you've been undercut".

The rest stays "Later" until you pick it.

Note from the research: on live Forever realms, addons apparently can't post in chat, and in instances they can't send chat messages at all. That doesn't affect Outrider today, since we never post in chat. If we build guild features, they should use hidden addon messages, as Sharing already does.

## Sources

- CurseForge, all WoW addons by total downloads: https://www.curseforge.com/wow/search?sortBy=total-downloads
- Addon pages on CurseForge: Leatrix Plus, Questie, Auctionator, RareScanner, Details, Baganator, TSM, Bagnon, Pawn, Plater, GatherMate2, TomTom, Postal, DBM, OneForAll Forever, Leatrix Maps, Nova World Buffs, GearQuest Forever, DungeonJournal, SkillUp Forever, What's Training, Shortest Path Forever, Forever Fishing, Glowing Bars, Nova Instance Tracker, Titan Panel, Spy, Dialogue UI, Scrap, OmniCC, All The Things, Prat 3.0, Layer-Swap, Attune
- Conquestcapped, WoW Forever addons: https://conquestcapped.com/guides/wow-forever/wow-forever-addons/
- Mein-MMO, the 10 most important WoW Forever addons: https://mein-mmo.de/en/wow-forever-the-10-most-important-addons-and-how-to-install-them,1593699/
- Blizzard, Midnight combat addon changes: https://news.blizzard.com/en-us/article/24246290/combat-philosophy-and-addon-disarmament-in-midnight
- Community Midnight addon status table (March 2026): https://wow-midnight-addon-template.vercel.app/cutting-edge/
