-- UI/HelpData.lua  (data only)
-- The user guide: what every part of Outrider does, in plain words. The Help
-- tab shows it in game; tools/build_guide.lua writes the same text to
-- docs/USER_GUIDE.md, so the two never drift apart. Keep entries short:
-- what it does, where to find it, what you do.
-- { section, intro, { { title, text }, ... } }

local _, ns = ...

ns.HelpData = {
  { icon = "INV_Misc_Book_09", "Getting started", "Outrider is one addon for WoW Forever that replaces a stack of others. It advises and informs; you press every key.", {
    { "Open Outrider", "Type /ride (or /outrider), or click the minimap button. The window has a sidebar of pages, grouped Explore, Character, Town, Social and Outrider. The search box at the top finds any rare, place, NPC, item, macro or page.", page = "home" },
    { "First-run setup", "The first time a character logs in, a short setup asks about rare sounds, font size and colour-blind options. Open it again any time with /ride setup.", cmd = "setup" },
    { "Key bindings", "Game Menu > Options > Keybindings > Outrider: Find (the command bar), Ask advisor and Paste advice." },
    { "Reload or restart", "Most updates need /reload. When Outrider gains new files, exit the game fully and start it again; a /reload can't load new files." },
    { "Quiet by default", "At most one chat line per kind of event per session. Sounds and pop-ups only for what you asked for, like rare alerts.", page = "settings" },
    { "Advice only", "Outrider never presses keys, casts, targets or plays for you. Every cast, purchase, talent point and macro press is your own click. Macros it writes are ordinary macros you drag to your bar." },
    { "Your data stays on your PC", "Nothing is sent anywhere. Sharing with your guild or party is off until you switch it on (see Sharing)." },
    { "Works with other addons", "Outrider needs no other addon. If you also run addons for quests, waypoints, prices, bags or the interface, Outrider shares what they offer or steps aside instead of fighting them." },
  } },

  { icon = "Ability_Warrior_OffensiveStance", "Fight macros (every class)", "Two macros per character that follow your spellbook for its whole life: drag key 1 to action slot 1 and key 2 to slot 2. Outrider rewrites them by itself, out of combat, whenever you learn a spell, change weapon, a buff goes on or off, or (druid) your forms change.", {
    { "Make them", "Class page > Fight macros > Make or show the macros (or /ride fight). Then open the macro window, Character tab, and drag them to your bar.", page = "class", cmd = "fight" },
    { "Built for your build", "The macros follow your class, talent build (the tree with the most points; under 10 points the levelling plan), race and level, from researched rotations for every class (PvE and PvP, a ranged and a melee key). Extra keys come with them where they help: Trap for hunters, Pull for warriors and rogues, Reach for paladins, and your race's Burst, Break and Recover keys. /ride fightplan shows what Outrider picked; /ride fightplan pvp or pve chooses the set (auto: PvP in battlegrounds, arenas, or when you target a hostile player out of combat). If one of your own macros misses big parts of your rotation or cuts a channel short, Outrider says so once and lists it at the top of the Macros page, yours and Outrider's side by side: Use Outrider's, Keep mine (until you change it) or Not now. Every Outrider fight key explains each of its lines there. Unverified until checked in game.", page = "class", cmd = "fightplan" },
    { "How a press works", "WoW Forever tries one spell per press. Each macro is ordered: buffs before the pull (only while missing), once-per-pull spells, spells on cooldown, then the always-usable filler. Spam it." },
    { "Hunter", "Fight (ranged): Aspect of the Hawk, Hunter's Mark, Auto Shot, Serpent Sting, Arcane Shot, pet sent in. Back to Hawk in a fight when Arcane Shot is cooling down. Strike (melee): Aspect of the Monkey, Wing Clip once, Raptor Strike, Immolation Trap (at your feet, when ready), Mongoose Bite. Pet: Revive, Call or Mend Pet.", page = "class" },
    { "Warrior", "Fight: Charge, Battle Shout, Rend once, Mortal Strike / Bloodthirst / Shield Slam, Heroic Strike. Strike: Overpower, Revenge, Execute, Thunder Clap, Cleave - press it when one lights up.", page = "class" },
    { "Rogue", "Fight: Cheap Shot from Stealth, then builder, builder, Slice and Dice, three builders, Eviscerate, round and round. Strike: Stealth out of combat; Kick, then Adrenaline Rush, Blade Flurry, Evasion.", page = "class" },
    { "Mage", "Fight: Arcane Intellect and armor while missing, Frostbolt (Fireball before it). Strike (close): Frost Nova, Fire Blast, Arcane Explosion.", page = "class" },
    { "Priest", "Fight: Power Word: Fortitude and Inner Fire while missing, Shadow Word: Pain once, Mind Blast, Smite. Heal: your best heal on who you point at, your friendly target, or you.", page = "class" },
    { "Warlock", "Fight: demon in, Bane of Agony, Corruption, Immolate, Siphon Life once each, then the wand (Drain Life from level 30, Shadow Bolt without a wand). Strike: Life Tap; Shift fears the target.", page = "class" },
    { "Druid", "Fight follows your form. No form: Moonfire, Wrath. Bear: Demoralizing Roar, Primal Bite, Maul. Cat: Rake, three Claws, Rip or Ferocious Bite. Heal: Swipe in Bear, Tiger's Fury in Cat, Healing Touch out of form.", page = "class" },
    { "Paladin", "Fight: Blessing and Aura while missing, Seal and Judgement round and round (Seal of Command with a two-hander from 20), Holy Strike, Crusader Strike, Consecration. Heal: Holy Light.", page = "class" },
    { "Shaman", "Fight: weapon imbue and Lightning Shield while missing, Lightning Bolt to pull, Searing Totem, Flame Shock once, Stormstrike, Earth Shock. Heal: Healing Wave.", page = "class" },
    { "Checking the order", "Every fight's casts and refused presses are logged by themselves. Orders come from the WoW Forever levelling guides and are tuned from those logs." },
  } },

  { icon = "Spell_Holy_FlashHeal", "Healing and talents", nil, {
    { "Click-to-heal bars", "In a group, a small panel of health bars: click a bar to heal that player. Priest: left Heal, right Renew, Shift-left Power Word: Shield, Shift-right Flash Heal (druid, paladin, shaman have their own). Red edge under half health, faded out of range. Hunters get the pet's bar with Mend Pet.", page = "class", cmd = "heal" },
    { "Assigned players", "Class page > Heal bars: click the names you're responsible for. With anyone assigned, only they (and you) get bars. Or /ride heal assign <name> (or target them). Bars can't change mid-fight; a new member gets one after combat.", page = "class", cmd = "heal" },
    { "Talent advisor", "Follows a WoW Forever levelling build for your class. Gold rings in the talent window show where your next points go, talent tooltips say 'spend here next', and one chat line tells you when points are waiting. Class page > Talents shows the plan; /ride talents.", page = "class", cmd = "talents" },
    { "Old spell ranks", "After you train, Outrider points out buttons on your bars still holding an old rank of a spell." },
  } },

  { icon = "Ability_Hunter_BeastTaming", "Hunter tools", nil, {
    { "Pet panel", "Pet name, level, XP, health, focus, abilities, attack speed and damage. The Feed button feeds your pet a food it eats (Outrider learns the diet as you feed).", page = "class" },
    { "Tame helper", "/ride tamemacro <Beast Name> writes a macro: press to send the pet in, Shift-press to dismiss it, press again to tame. 'solo' tames without a pet; 'trap' lays a Freezing Trap, pulls the beast onto it, tames, and Wing Clips then tames again if the tame breaks.", page = "class" },
    { "Ammo warnings", "One warning when ammo drops under 200 and again under 50. Errands remind you to buy more in town." },
    { "Beast tooltips", "Family, level, tameable, and for known rares the last sighting and respawn window. Hold Shift for attack speed and abilities." },
  } },

  { icon = "Ability_Hunter_SniperShot", "Rares", "Outrider spots rares by itself from nameplates, your target and mouseover.", {
    { "Alerts", "A pop-up and sound when a rare is alive near you, with a Target button (your click targets it). Rare alerts page: sound and which rares.", page = "rarealerts" },
    { "Nameplate star", "A big pulsing star over a rare's nameplate so you can find it in a crowd: gold for one you're watching." },
    { "Watch list", "/ride watch <name> alerts you for any NPC on this character; /ride unwatch <name> stops.", page = "rarealerts" },
    { "Rares page", "Every rare Outrider knows, for this zone or all: last seen, respawn window on your layer, and a waypoint button.", page = "rares" },
    { "Sightings and respawns", "Every sighting is remembered; respawn windows are worked out per layer from the gaps seen. Forecasts page: respawn and gold forecasts.", page = "forecasts", cmd = "forecast" },
    { "Rare timers", "For rares said to spawn every N hours: a countdown from a time you give it." },
    { "Rare profiles and spawn log", "What a watched rare is like in a fight (level, family, attack speed), and what spawns at its spot, in order, to learn its pattern." },
    { "Layers", "Which copy (layer) of the zone you are on, so a sighting on another layer doesn't fool you." },
    { "Rare macros", "Library macros that always target or tame the newest rare you saw.", page = "macros" },
  } },

  { icon = "INV_Misc_Map_01", "Maps and travel", nil, {
    { "Map pins", "Vendors, trainers, flight masters, repair, mailboxes and rares on the world map and minimap, recorded as you meet them. Map page: which pins show.", page = "map" },
    { "Zone levels", "Level ranges over each zone on the world map and over areas inside a zone map. /ride zonelevels on|off.", page = "map", cmd = "zonelevels" },
    { "Breadcrumbs", "Small gold dots where you walked, on the world map and minimap, so you can find your way back out. /ride trail clear.", page = "map", cmd = "trail" },
    { "Waypoints", "/ride way <x> <y> [title] sets one on this map; /ride near <spirit|flight|vendor|repair|trainer|mail|bank|ah|stable|inn|ammo> goes to the nearest. When you die, a waypoint to the nearest spirit healer appears by itself.", page = "waypoints" },
    { "Travel planner and Journey", "Journey page: 1, pick a place, quest or item (the three best picks for you are on top, or choose what you're looking for on the left, or type a name); 2, press Go; 3, follow the gold arrow. Your trip on the right shows each step, across zones by flight, boat or portal.", page = "journey" },
    { "Coordinates", "Under the minimap while you move. /ride coords prints them.", cmd = "coords" },
    { "Herbs and ore", "Herb and ore spawn points for the world (with the optional node pack), a reminder when Find Herbs is off, and where each herb grows (/ride herbs).", cmd = "herbs" },
    { "Discovery", "Outrider records the NPCs you meet (account-wide) to build its own map of WoW Forever, since zones were redrawn. /ride discovered.", page = "map", cmd = "discovered" },
  } },

  { icon = "INV_Chest_Chain", "Gear", nil, {
    { "Gear advisor", "Scores items for your class and role and compares them with what you wear: tooltips say how much better or worse. /ride score <item>, /ride weights.", page = "gear", cmd = "weights" },
    { "Gear page", "Upgrades you can get: nearby in this zone, from quests, from dungeons, and from your other characters' bags (Bind on Equip handoffs).", page = "gear" },
    { "Dungeons page", "Which dungeons you're ready for and what each holds for you.", page = "dungeons" },
    { "Quest rewards", "At a turn-in with a choice, the best reward for you is named and its button marked. Also bag upgrades." },
    { "Loot rolls", "In a group roll: Need or Greed advice, with the reason (an upgrade for you, or sell it)." },
    { "Gear sets", "/ride gear save <name> remembers what you wear; /ride gear <name> puts it back on (out of combat).", page = "gearsets", cmd = "gear list" },
    { "Gear for alts and family", "Points out gear you carry that another of your characters, or a family member running Outrider, could use." },
  } },

  { icon = "Trade_Alchemy", "Professions and gold", nil, {
    { "Profession records", "Open each profession window once; Outrider remembers your recipes, their colours and reagents.", page = "professions" },
    { "One-press crafting", "/ride make creates Cook, Brew and Herb macros: each press opens the window or makes what you have ingredients for.", page = "professions", cmd = "make" },
    { "Training button", "One button per crafting profession to make the next skill-up you can afford from your bags.", page = "professions" },
    { "Skill-up planner", "/ride skillup [profession]: the cheapest recipes per skill point.", page = "professions", cmd = "skillup" },
    { "Crafting page", "A craft queue and the shopping list it needs.", page = "crafting" },
    { "Fishing", "Pick a key (/ride fishkey F): it casts and hooks the bobber. A small HUD shows skill and lure time, and catches are logged per zone." },
    { "Fishing page", "Your skill, lifetime casts and catches, how many catches to your next point (measured from your own catches), the next milestone (Journeyman, the Expert book, Nat Pagle), the zones for your skill with what you've caught there, one-click fishing gear and back, fishing trainers and supply vendors with an arrow, and the Stranglethorn Fishing Extravaganza countdown. Zone and NPC data from a WoW Forever fishing guide (unverified).", page = "fishing" },
    { "Player tooltips", "Mouse over another player: attack speed, health and mana, PvP flag and rank, the professions they've linked in trade chat, when and where you last saw them, and whether it's your alt. Out of combat and close by, Outrider also looks at their gear once (average item level, epics and blues, weapon) and their talent build. Other players' stats can't be read, so none are shown. A rough PvP odds line weighs level, health, gear and class matchup, and learns from the duels you win and lose. Rares, rare elites, elites and bosses get their health, attack speed and rough fight odds (level, health, elite, your pet and group), learning from the fights you win and lose. /ride module PlayerInfo off turns it off." },
    { "Party quest announcements", "In a party, Outrider tells the party when you finish a quest objective, when a quest is ready to hand in and when you hand it in (it stays quiet if another quest addon already does this). When everyone in the party who has the quest is done, it says so once: 'Everyone is done with [quest], go hand it in!'. It knows party members' progress from Outrider (a party addon message) and from other quest addons' party announcements. /ride module PartyQuests off turns it off." },
    { "Quest tracker", "Outrider's own quest tracker: your quests by zone, nearest first (or by level), each objective with your party's progress under it. Click a quest for the arrow (a finished quest points at its turn-in; when you finish one, the arrow moves there by itself unless you set your own waypoint), right-click to fold it, drag the title to move it. /ride tracker on|off|reset|level|nearest. It steps aside if you run another quest tracker.", page = "quests" },
    { "Journal", "Your quest story on its own page: every quest you took, handed in or abandoned, newest first, with the date, your level and the zone. Pick one to see it in detail with its chain and reward. The top shows quests handed in today, this week and in total.", page = "journal" },
    { "Quest details", "Quest cards, the tracker and quest givers show quest chains (Part 2 of 4, next quest), breadcrumbs, reputation rewards and categories (Darkmoon Faire, profession, class, repeatable). Taking a quest whose breadcrumb you skipped gives one warning. Quest links in chat show their level. A short sound plays when an objective or quest is done. The Quests page keeps a dated history of the quests you take, hand in and abandon. Escort and patrol NPCs of your quests walk a dotted path on the map. Quest-giver pins hide holiday quests and profession quests for professions you don't have (switches on the Quests page). Community data, unverified.", page = "quests" },
    { "Money page", "The best ways to earn gold at your level and with your professions, and your own earnings per hour.", page = "money" },
    { "Gold ledger", "Where your gold came from and went, per session and character.", page = "money" },
    { "Merchant's Favor", "Waylaid Crates: what each crate needs and your Favor balance. /ride favor.", cmd = "favor" },
    { "Errands", "Entering a town, one pop-up with what to do there: sell junk, repair, buy ammo, train. Errands page lists them.", page = "errands", cmd = "errands" },
    { "Vendor and mailbox", "Sell junk and Repair buttons beside vendors; a Collect button beside the mailbox (one item per click) that says what's waiting in total. Send to: your characters on this realm and the last people you mailed, one click fills the To: box. At login, one line warns about mail with gold or items expiring within 3 days on any of your characters." },
  } },

  { icon = "INV_Misc_Coin_02", "Auction house", "With the auction house open, Outrider's shopping window sits beside it: a menu on the left, item cards with icons and prices in coins. Buying is always your click.", {
    { "Training", "Three views from one search. Skill-ups: the cheapest way to your next points, each recipe with its ingredients as icons (amber: not on the auction house) and its cost a point. Recipes: recipes for sale you don't know, usable now or soon; ones this character already knows are left out (the line under the heading says how many); another character knowing it doesn't count. Shopping list: every ingredient added up, with Buy all. Pick a profession with its chip, or All." },
    { "Weapons, Armor and Bags", "Upgrades your gold covers: only armor your class wears, bigger bags than your smallest, quivers or ammo pouches for hunters, profession bags for your professions." },
    { "Profit: vendor flips and resale", "After Scan all prices (top right, once every 15 minutes): Vendor flips lists auctions priced under what a vendor pays, so you buy them and sell them at any vendor for a sure profit; Resale lists auctions well under their usual price (two weeks of history), with the profit after the 5% cut and deposit once it sells again. Each Buy has a price cap: if the cheap listing is gone, it's skipped." },
    { "Buy in one click", "Outrider looks up each card's listing before you click (stackable goods while your mouse rests on Buy), so one click on Buy buys it at the price shown. If you click before it's ready, it goes to the cart and the button says Buy again in a moment. Cards with several things to buy say Add; the cart bar at the bottom buys the next item each press. Every purchase is your click." },
    { "Prices and selling", "Prices from what Outrider has seen at the auction house (or from a price addon if you run one). The auction helper suggests a price; /ride undercut sets how far under the market." },
  } },

  { icon = "INV_Misc_Note_02", "Interface and chat", nil, {
    { "What now?", "Next steps for this character right now: errands, quests, gear, dungeons, training, gold. /ride now [level|gold|gear|professions|explore].", page = "whatnow" },
    { "Find bar", "One search box for everything (key binding Outrider: Find, or /ride find).", cmd = "find" },
    { "Census", "Who's playing on your realm: most common level, class, race and profession, and the highest level seen. Players you see are counted as you play; Search the next group (or its key binding) sends one /who search a press, top level first: 13 presses cover every level, more presses add detail where 50+ players share a level. Professions come only from links in chat. Kept 30 days, on this PC only. /ride census.", page = "census", cmd = "census" },
    { "Players & guilds", "Find any player Outrider has counted (name, guild, zone, class or level) and click to whisper them (opens the chat box, you send), invite them to your group, or to your guild if your rank can. A catalog of every guild seen with members, levels and where they play. Search a guild or your zone with one /who per press.", page = "people" },
    { "Info bar", "A thin strip at the top of the screen: gold (hover for every character's), free bag slots, durability (warns on your worst item), ammo, XP with rested XP and what your quest log is worth, clock, latency and frame rate. Click gold, bags, durability or XP to open the matching page. Shift-drag to move; Settings picks the parts. /ride bar on|off|reset.", page = "settings", cmd = "bar" },
    { "My characters", "Every character at a glance: level, gold, rested XP (it keeps growing offline, faster in an inn), free bag slots, durability, ammo, professions, where and when last seen. Updated whenever you play them.", page = "alts" },
    { "Dungeon lockouts and runs", "Classic allows 5 new instances an hour and 30 a day per account. My characters counts the ones you enter and says when the next slot frees (an estimate). Every run is timed with the XP, kills and gold it gave. /ride runs.", page = "alts", cmd = "runs" },
    { "Map extras", "Dungeon and raid entrances, portals, boats and zeppelins, and guildmates who share their location show as pins on the world map and minimap (Map page picks which).", page = "map" },
    { "Reveal the map", "Areas of the world map this character hasn't explored show tinted, for every zone: Outrider carries the game's own list of map areas for WoW Forever, and also records what each of your characters explored. Settings > Map.", page = "settings" },
    { "Flight times", "Every flight you take is timed. The flight map tooltip then shows how long a flight takes, and the info bar counts down to landing.", page = "settings" },
    { "Quest objectives on the map", "For every quest in your log, pins on the world map and minimap show where its mobs, objects, items and places are, from the quest database (community data, unverified). Finished objectives drop off. Mouse over an object a quest needs and a pop-up says so; the spot is saved as seen on Forever. Settings > Quests.", page = "settings" },
    { "Quests page and turn-ins", "The Quests page lists every quest in your log with its progress; Go puts the arrow on the nearest objective, or on the turn-in once it's done. Finished quests get a ? pin where you hand them in, objects that give quests (wanted posters) get a ! pin, and mob, object and item tooltips say which of your quests needs them.", page = "quests" },
    { "Quest marks and quest XP", "Mobs and objects your quests need get a quest mark beside their nameplate with what's left. The info bar's XP shows what the quests in your log are worth. At a turn-in, the best reward for you is named; if none is an upgrade, the one worth most (vendor or auction house).", page = "settings" },
    { "Bag marks", "On Blizzard's own bag slots: item level on gear, a green arrow on upgrades for you, a gold coin on grey junk (Settings picks which). Outrider steps aside if you run another bag addon.", page = "settings" },
    { "Find an item on any character", "My characters page, or /ride where <item>: which of your characters has it and where (bags, bank, mail, worn), as last seen.", page = "alts", cmd = "where" },
    { "Small switches", "Settings > Small switches, all off until you pick them: hide the big zone names, red error text or the talking head; zoom the camera out further; gather other addons' minimap buttons behind one button; keep the last 50 chat lines after a reload.", page = "settings" },
    { "Wowhead link", "Hover an item, NPC or spell and press your Outrider: Wowhead link key (or /ride wowhead): a box with its WoW Forever Wowhead address to copy (Ctrl+C).", cmd = "wowhead" },
    { "At the trainer", "Open any trainer once (class or profession): the Professions page lists what you can learn now, what comes next (at what skill or level) and the cost.", page = "professions" },
    { "Skill-up chance and cooldowns", "Professions page: each recipe's chance to give a point from its colour (estimates), craft cooldowns like transmutes on every character (one line at login when one is ready), your most profitable crafts, and auctions of yours someone undercut.", page = "professions" },
    { "Feed", "Every pop-up is kept here, newest first, so nothing is lost when one fades. /ride feed.", page = "feed", cmd = "feed" },
    { "Look", "A clean dark skin for Blizzard windows, flat tooltips with a Target line, flat health bars. Cosmetic only; Edit Mode still decides positions.", page = "settings" },
    { "Edit Mode per situation", "Assign an Edit Mode layout to a situation (city, fishing, group...) and Outrider switches to it out of combat. /ride layout.", page = "settings", cmd = "layout" },
    { "Chat", "Your name and watched words highlighted, repeated spam hidden, LFG lines in their own tab, timestamps. /ride chat; /ride copychat copies the last 100 lines.", page = "chat" },
    { "Spell check", "Misspelled words underlined while you type in chat, with suggestions. /ride spell add <word>.", page = "chat" },
    { "Accessibility", "Bigger fonts, UI scale, colour-blind colours, high contrast, less motion. /ride access.", page = "settings", cmd = "setup" },
    { "Macro tree", "Macros page, laid out like the talent window. On top, your keys (Fight, Pull, Strike...): put them on your bar once and Outrider rewrites them as you learn spells; the line under them says what Fight does press by press. Below, a tree: rows are level bands (1-10 up to 51-60), columns are every build of your class and one per talent tree. Grey icons with a number unlock at that level; gold ones are on your bar. Click an icon to read when to press it and every line in plain words; drag it (or Pick up) onto your action bar. PvE / PvP switches the tree to the PvP versions. Before 10 talent points, the build menu at the top picks the build you're heading for. The page also counts your 18 character macro slots, marks newly unlocked macros as new, offers to clear the macros of your old build after a respec, and checks your own macros for spells Forever renamed and for copies (/ride macrocheck).", page = "macros" },
    { "Combined keys", "Second row on the Macros page: Stop, Save, Burst, Recover and Team. Each is one button with layers: plain press, Shift, Ctrl and Alt (the detail panel lists them). Stop interrupts (Shift stuns), Save is your big defensive (Shift escapes), Burst uses both trinkets and your cooldown, Recover eats and drinks out of combat and uses a healthstone or potion in combat (Shift bandages you), Team assists (Shift sets focus). They follow your spellbook and bags. The single macros they cover leave the tree; Show singles brings them back.", page = "macros" },
    { "Bag swap", "Bought or looted a bigger bag? Press the Bag Swap key (Macros page, top right) or type /ride bagswap, out of combat. Outrider moves the items out of your smallest bag into your other bags and puts the new bag in its place; the old bag ends up in your bags. If there isn't room, it tells you how many slots to free.", page = "macros" },
    { "Handy keys and quiet presses", "Top right of the Macros page: Nameplates (enemy nameplates on or off, so rares are seen from further away), Vendor (at a merchant: sell grey junk and repair), Status (XP to level, rested XP, durability, bags, gold this session) and Next Step (the best thing to do next, with the arrow). Drag them to a bar. Quiet presses: Outrider's casting macros clear the red 'not ready yet' text (when it fits in 255 characters) and the game's error voice is off; switch it on the Settings page or with /ride quiet on|off.", page = "macros" },
    { "Macro tooltips and missing buffs", "Hover one of Outrider's macros on your action bar: under the spell's tooltip it says when to press it and what it does. A small row of icons above your bars shows your own buffs that are missing or about to run out; click one to put it on you (out of combat it updates; /ride buffs on|off). Both switch off on the Settings page.", page = "settings" },
  } },

  { icon = "INV_Letter_09", "Sharing (all off by default)", "Only with Outrider users in your guild or party, only what you switch on.", {
    { "Rare sightings", "/ride share rares guild|party on: your rare sightings go to them and theirs come to you.", page = "sharing" },
    { "Gathering spots", "/ride share nodes on: herb, ore and fishing spots you find.", page = "sharing" },
    { "Location", "/ride share location on: your map position to your guild every 30 seconds while you move.", page = "sharing" },
    { "Family installs", "A copy for family can start with what your Outrider already learned (shared data pack), and tells them when a newer Outrider exists." },
  } },

  { icon = "INV_Misc_Book_11", "Advisor", "Advice from an AI companion, without anything leaving your control.", {
    { "Ask", "/ride ask (or the Ask key): Outrider shows a code describing your character. Copy it (Ctrl+C) and give it to your advisor.", page = "advisor", cmd = "ask" },
    { "Paste advice", "/ride paste (or the Paste key): paste the advice code you got back (Ctrl+V). It shows on the Advisor page.", page = "advisor", cmd = "paste" },
  } },

  { icon = "Trade_Engineering", "Settings and troubleshooting", nil, {
    { "Settings page", "Every option in one place. Modules page: switch any feature on or off for this character (/ride module <Name> on|off).", page = "settings" },
    { "Characters", "/ride chars lists your characters; /ride copy <Name-Realm> copies another character's settings; /ride export and /ride import move them as text.", page = "characters", cmd = "chars" },
    { "Something wrong?", "/ride errors shows Outrider's recent errors; /ride status shows modules, saved settings and errors; /ride version shows the build.", cmd = "errors" },
    { "Helping fix it", "/ride mark <text> writes a marker in the log; /ride debug on logs more. The log is saved when you log out or /reload.", cmd = "status" },
    { "All commands", "The All commands page lists every /ride command with what it needs: click one, fill in, Run.", page = "commands" },
  } },
}
