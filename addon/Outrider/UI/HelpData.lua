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
    { "Works with other addons", "If Questie, TomTom, Auctionator, TSM, HealBot, RareScanner, ElvUI and similar are installed, Outrider uses their data or steps aside instead of fighting them." },
  } },

  { icon = "Ability_Warrior_OffensiveStance", "Fight macros (every class)", "Two macros per character that follow your spellbook for its whole life: drag key 1 to action slot 1 and key 2 to slot 2. Outrider rewrites them by itself, out of combat, whenever you learn a spell, change weapon, a buff goes on or off, or (druid) your forms change.", {
    { "Make them", "Class page > Fight macros > Make or show the macros (or /ride fight). Then open the macro window, Character tab, and drag them to your bar.", page = "class", cmd = "fight" },
    { "How a press works", "WoW Forever tries one spell per press. Each macro is ordered: buffs before the pull (only while missing), once-per-pull spells, spells on cooldown, then the always-usable filler. Spam it." },
    { "Hunter", "Fight (ranged): Aspect of the Hawk, Hunter's Mark, Auto Shot, Serpent Sting, Arcane Shot, pet sent in. Back to Hawk in a fight when Arcane Shot is cooling down. Strike (melee): Aspect of the Monkey, Wing Clip once, Raptor Strike, Mongoose Bite. Pet: Revive, Call or Mend Pet.", page = "class" },
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
    { "Tame helper", "/ride tamemacro <Beast Name> writes a macro: press to send the pet in, Shift-press to dismiss it, press again to tame. 'solo' tames without a pet.", page = "class" },
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
    { "Travel planner and Journey", "Journey page: search for any place, rare, mob, NPC, quest or item, and the best gear and XP quests for your level; a number guides you there across zones (flights, boats, portals).", page = "journey" },
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
    { "Money page", "The best ways to earn gold at your level and with your professions, and your own earnings per hour.", page = "money" },
    { "Gold ledger", "Where your gold came from and went, per session and character.", page = "money" },
    { "Merchant's Favor", "Waylaid Crates: what each crate needs and your Favor balance. /ride favor.", cmd = "favor" },
    { "Errands", "Entering a town, one pop-up with what to do there: sell junk, repair, buy ammo, train. Errands page lists them.", page = "errands", cmd = "errands" },
    { "Vendor and mailbox", "Sell junk and Repair buttons beside vendors; a Collect button beside the mailbox (one item per click)." },
  } },

  { icon = "INV_Misc_Coin_02", "Auction house", "With the auction house open, Outrider's shopping panel sits beside it. Buying is always your click.", {
    { "Training tab", "Pick a profession (only the ones this character has, or All). Outrider searches the ingredients your skill-up recipes need and ranks them by cost per skill point, plus recipes for sale you can use now or soon." },
    { "Weapons, Armor and Bags tabs", "Upgrades your gold covers: only armor your class wears, bigger bags than your smallest, quivers or ammo pouches for hunters, profession bags for your professions." },
    { "Buy", "A Buy click queues the item; the bar above the auction window shows the cheapest listing and you confirm each purchase." },
    { "Prices and selling", "Prices from Auctionator or TSM when installed, else what Outrider has seen. The auction helper suggests a price; /ride undercut sets how far under the market." },
  } },

  { icon = "INV_Misc_Note_02", "Interface and chat", nil, {
    { "What now?", "Next steps for this character right now: errands, quests, gear, dungeons, training, gold. /ride now [level|gold|gear|professions|explore].", page = "whatnow" },
    { "Find bar", "One search box for everything (key binding Outrider: Find, or /ride find).", cmd = "find" },
    { "Census", "Who's playing on your realm: most common level, class, race and profession, and the highest level seen. Players you see are counted as you play; Search the next group (or its key binding) sends one /who search a press, top level first: 13 presses cover every level, more presses add detail where 50+ players share a level. Professions come only from links in chat. Kept 30 days, on this PC only. /ride census.", page = "census", cmd = "census" },
    { "Feed", "Every pop-up is kept here, newest first, so nothing is lost when one fades. /ride feed.", page = "feed", cmd = "feed" },
    { "Look", "A clean dark skin for Blizzard windows, flat tooltips with a Target line, flat health bars. Cosmetic only; Edit Mode still decides positions.", page = "settings" },
    { "Edit Mode per situation", "Assign an Edit Mode layout to a situation (city, fishing, group...) and Outrider switches to it out of combat. /ride layout.", page = "settings", cmd = "layout" },
    { "Chat", "Your name and watched words highlighted, repeated spam hidden, LFG lines in their own tab, timestamps. /ride chat; /ride copychat copies the last 100 lines.", page = "chat" },
    { "Spell check", "Misspelled words underlined while you type in chat, with suggestions. /ride spell add <word>.", page = "chat" },
    { "Accessibility", "Bigger fonts, UI scale, colour-blind colours, high contrast, less motion. /ride access.", page = "settings", cmd = "setup" },
    { "Macro library", "Macros page: ready-made macros for your class, each explained line by line, with Install and Update.", page = "macros" },
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
