-- Data/Leveling_Facts.lua
-- Short leveling tips for the leveling knowledge base, shown by What now?
-- (Modules/WhatNow.lua) from minLevel for a few levels, filtered by class
-- and race when set. Source: Wowhead's WoW Forever guides (wowhead.com/forever,
-- read in the browser 2026-11-21); each fact names its guide.
-- Hard rule 7: numbers copied as the guides print them, nothing invented.
-- Costs in the riding guide are shown with a coin icon; gold is implied.

local _, ns = ...

local function src(guide) return "wowhead.com " .. guide .. " (read 2026-11-21)" end
local RIDE = src("Learning to Ride and Getting Your First Mount guide")
local CAMP = src("Camping Overview")
local LEG  = src("Legacy System Overview")
local BAGS = src("Bags & Storage Overview Guide")
local LIB  = src("Collecting Library Books guide")
local STQ  = src("Sunken Temple Class Quests Guide")
local SKY  = src("Skyborne Race Overview")
local RACE = src("All Racials and Available Class-Race Combinations guide")
local TUR  = src("Tarnished Undermine Real Currency Guide")
local WRIT = src("Craftsman's Writs guide")
local ACA  = src("Azeroth Commerce Authority Guide")
local PROF = src("Professions Overview")
local COOK = src("Cooking Profession Overview")
local FAID = src("First Aid Profession Overview")
local FISH = src("Fishing Profession Overview")
local ENGI = src("Engineering Overview")
local SKIN = src("Skinning Profession Overview")
local HERB = src("Herbalism Profession Overview")
local MINE = src("Mining Profession Overview")
local DUNG = src("Dungeons Overview")
local FLY  = src("Flight Points, Zeppelins, and Ships guide")
local GELK = src("Gelkis Clan Centaur Reputation Guide")
local NCLW = src("Nightclaw Druids Reputation Guide")
local TMBR = src("Timbermaw Hold Reputation Guide")
local SHEN = src("Shen'dralar Reputation Faction guide")
local COZY = src("Bags & Storage Overview Guide")

ns.Leveling = ns.Leveling or {}
ns.Leveling.FACTS = {
  -- riding
  { id = "riding-apprentice", topic = "riding", minLevel = 40, source = RIDE,
    text = "At level 40 you can learn Apprentice Riding (60% speed) for 100 gold. Your first mount is free (it would cost 20)." },
  { id = "riding-journeyman", topic = "riding", minLevel = 60, source = RIDE,
    text = "At level 60 you can learn Journeyman Riding (100% speed) for 1,000 gold. Your first epic mount is free (it would cost 200)." },
  { id = "riding-free-mounts", topic = "riding", minLevel = 40, source = RIDE,
    text = "After Apprentice Riding, claim a free Rare mount from your race's mount vendor. After Journeyman Riding, claim a free Epic mount." },
  { id = "riding-discount", topic = "riding", minLevel = 38, source = RIDE,
    text = "Honored reputation with your race's faction gives 10% off riding." },
  { id = "riding-racial", topic = "riding", minLevel = 40, source = RIDE,
    text = "Learning riding also teaches your race's mount skill. Other races' mounts need Exalted with that race plus 100 gold to learn that riding." },
  { id = "riding-paladin", topic = "riding", minLevel = 40, class = "PALADIN", source = RIDE,
    text = "Paladins get class mount quests at 40 and 60 that reward a 60% / 100% mount plus the riding skill." },
  { id = "riding-warlock", topic = "riding", minLevel = 40, class = "WARLOCK", source = RIDE,
    text = "Warlocks get class mount quests at 40 and 60 that reward a 60% / 100% mount plus the riding skill." },

  -- camping and rested XP
  { id = "camp-unlock", topic = "camping", minLevel = 5, source = CAMP,
    text = "Around level 5 you get the quest The Great Outdoors: /sit at the campfire, then train Cooking and craft a Basic Campfire. The Cooking Trainer sells Simple Wood and Flint and Tinder." },
  { id = "camp-basic", topic = "camping", minLevel = 5, source = CAMP,
    text = "A Basic Campfire holds 3 camp items: you place one, friends place the others. You get a Camping 101 quest for each profession you have trained." },
  { id = "camp-cooldown", topic = "camping", minLevel = 5, source = CAMP,
    text = "All camping features share a 1 hour cooldown. The buff goes to anyone sitting or crafting near the camp for 1 minute." },
  { id = "camp-tent", topic = "rested", minLevel = 5, source = CAMP,
    text = "Leatherworkers (skill 20) can place a Camp Tent from 5 Light Leather: it raises your rested XP to 5% of a level, usable every hour." },
  { id = "camp-best-leveling", topic = "camping", minLevel = 5, source = PROF,
    text = "Best professions for leveling: Leatherworking (Camp Tent, 5% rested XP every hour) and Engineering (camp vendor to clear your bags every hour)." },
  { id = "camp-buffs-1", topic = "camping", minLevel = 5, source = CAMP,
    text = "Tier 1 camp buffs: Fish Bowl +8% stats, Lodestone +90 melee Attack Power, Sharpening Wheel +34 Strength, Camp Chair +2% crit." },
  { id = "camp-buffs-2", topic = "camping", minLevel = 5, source = CAMP,
    text = "More tier 1 camp buffs: Incense Candle +25 Intellect, Faction Banner +32 Spirit, Mana Well 29 mana per 5 sec, Enchanted Lute +308 armor and +13 all stats." },
  { id = "camp-no-stack", topic = "camping", minLevel = 5, source = PROF,
    text = "Camp buffs do not stack with the matching class buff; the class buff wins (Fish Bowl vs Blessing of Kings, Incense Candle vs Arcane Intellect)." },
  { id = "camp-campfires", topic = "camping", minLevel = 18, source = CAMP,
    text = "Bigger campfires: Journeyman Campfire (Cooking 90, from Lord Serpentis in Wailing Caverns) holds 5 items; Expert Campfire (Cooking 200, Slavecrusher Grox) holds 10." },
  { id = "rested-cozy", topic = "rested", minLevel = 14, source = COZY,
    text = "The Cozy Sleeping Bag gives +1% experience per minute you rest in it, up to 3%. It comes from the Cozy Sleeping Bag quest chain." },
  { id = "food-xp", topic = "professions", minLevel = 1, maxLevel = 10, source = COOK,
    text = "All cooked food gives Well Fed XP Boost: +5% XP from kills for 15 minutes." },

  -- Legacy
  { id = "legacy-what", topic = "legacy", minLevel = 1, maxLevel = 8, source = LEG,
    text = "Legacy Points are account-wide and come from challenges; spend them in the Legacy Tree. At launch you can spend 16. Respec at your class trainer for 10." },
  { id = "legacy-class", topic = "legacy", minLevel = 22, source = LEG,
    text = "Reaching level 25, 45 and 60 for the first time on a class gives 1 Legacy Point each." },
  { id = "legacy-trades", topic = "legacy", minLevel = 10, source = LEG,
    text = "Skill 150, 225 and 300 in Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking or Tailoring give 1 Legacy Point each, kept even if you unlearn it." },
  { id = "legacy-spelunker", topic = "legacy", minLevel = 13, source = LEG,
    text = "Novice Spelunker (1 Legacy Point): clear Ragefire Chasm or Hall of Thanes, Wailing Caverns, Shadowfang Keep, Ruins of Lordaeron, The Deadmines and Excavation Site: Wetlands." },
  { id = "legacy-fastest", topic = "legacy", minLevel = 1, maxLevel = 8, source = LEG,
    text = "Fastest Legacy Points: class levels 25/45/60, crafts to 150 and 225 (Alchemy and Enchanting to 225 are cheap), Novice and Experienced Spelunker." },
  { id = "legacy-well-rested", topic = "legacy", minLevel = 1, maxLevel = 8, source = LEG,
    text = "Well Rested (5 ranks): rested XP builds 4% faster and the rested cap is 4% higher. It is needed before Talented." },
  { id = "legacy-talented", topic = "legacy", minLevel = 1, maxLevel = 8, source = LEG,
    text = "Talented (5 ranks): talent points start at level 9 instead of 10 (still 51 total), so key talents come up to five levels earlier." },
  { id = "legacy-thrill", topic = "legacy", minLevel = 1, maxLevel = 8, source = LEG,
    text = "Thrill of Adventure (5 ranks): 1% max health and mana over 10 sec on each killing blow (not in dungeons). Best if you have fewer than 5 points." },
  { id = "legacy-flier", topic = "legacy", minLevel = 10, source = LEG,
    text = "Frequent Flier (1 rank): flight paths cost 50% less and flight mounts are 20% faster." },
  { id = "legacy-reagents", topic = "legacy", minLevel = 10, source = LEG,
    text = "Reagent Economy (1 rank): class abilities no longer need vendor reagents, and tier 1 camp features cost no reagents." },
  { id = "legacy-rewards", topic = "legacy", minLevel = 10, source = LEG,
    text = "Claim Legacy rewards from Innkeeper Wiley in Ratchet: 15 points Replica Ironforge Air Rifle, 25 Spectral Bear Cub, 40 a tabard, 55 the Spectral Bear mount." },

  -- bags
  { id = "bags-starter", topic = "bags", minLevel = 1, maxLevel = 8, source = BAGS,
    text = "Every starting zone has a quest for a 6-slot bag: Sticks and Bones (Tirisfal), Carry Your Weight (Durotar), Grace of An'she and Mu'sha (Mulgore), The Problem With Prideclaws (Zephras Isle)." },
  { id = "bags-starter-alliance", topic = "bags", minLevel = 1, maxLevel = 8, source = BAGS,
    text = "Alliance 6-slot bag quests: Book Return (Elwynn Forest), Soft Saber Pelts (Teldrassil), Grund and Gozwin (Dun Morogh)." },
  { id = "bags-reagent", topic = "bags", minLevel = 1, maxLevel = 10, source = BAGS,
    text = "There is a new reagent bag slot. Gathering trainers sell an Apprentice's Mining Pack, Skinning Satchel or Herb Pouch at level 1 once you learn that profession." },
  { id = "bags-deviate", topic = "bags", minLevel = 13, source = BAGS,
    text = "The Wailing Caverns quest Deviate Hides rewards the 10-slot Deviate Hide Pack." },
  { id = "bags-ammo", topic = "bags", minLevel = 1, maxLevel = 10, class = "HUNTER", source = BAGS,
    text = "Ammo pouches (bullets) and quivers (arrows) give ranged attack speed (does not stack). Weapon vendors sell a Small Shot Pouch (8) or Light Quiver (6)." },

  -- professions
  { id = "prof-ranks", topic = "professions", minLevel = 10, source = PROF,
    text = "Profession ranks: Journeyman needs skill 50 and level 10, Expert needs skill 125 and level 20, Artisan needs skill 225 and level 35." },
  { id = "prof-gather-quests", topic = "professions", minLevel = 1, maxLevel = 8, source = HERB,
    text = "You can learn a gathering profession from an early starting-zone quest reward: Wild Harvest (Herbalism), Mining for Dummies, Pelt Collecting for Beginners (Skinning)." },
  { id = "prof-firstaid-potions", topic = "professions", minLevel = 10, source = PROF,
    text = "In Forever, Healing Potions are made with First Aid, not Alchemy." },
  { id = "prof-cooking-expert", topic = "professions", minLevel = 20, source = COOK,
    text = "Expert Cooking comes from the Expert Cookbook: Shandrina, NE of Talondeep Path in Ashenvale (Alliance), or Wulan, Shadowprey Village in Desolace (Horde)." },
  { id = "prof-cooking-artisan", topic = "professions", minLevel = 35, source = COOK,
    text = "Artisan Cooking (level 35, Cooking 225): Clamlette Surprise from Dirge Quikcleave in Gadgetzan needs 12 Giant Egg, 10 Zesty Clam Meat, 20 Alterac Swiss." },
  { id = "prof-firstaid-expert", topic = "professions", minLevel = 20, source = FAID,
    text = "Expert First Aid comes from the book Expert First Aid - Under Wraps: Deneb Walker in Stromgarde Keep (Alliance) or Balai Lok'Wein in Brackenwall Village (Horde)." },
  { id = "prof-firstaid-artisan", topic = "professions", minLevel = 35, source = FAID,
    text = "Artisan First Aid (level 35, First Aid 225): quest Triage from Doctor Gustaf VanHowzen in Theramore (Alliance) or Doctor Gregory Victor in Hammerfall (Horde)." },
  { id = "prof-fishing-expert", topic = "professions", minLevel = 20, source = FISH,
    text = "Expert Fishing comes from the book Expert Fishing - The Bass and You, sold by Old Man Heming in Booty Bay." },
  { id = "prof-fishing-artisan", topic = "professions", minLevel = 35, source = FISH,
    text = "Artisan Fishing (level 35, Fishing 225): Nat Pagle in Dustwallow Marsh wants Feralas Ahi, Misty Reed Mahi Mahi, Sar'theris Striker and Savage Coast Blue Sailfin." },
  { id = "prof-fishing-lure", topic = "professions", minLevel = 1, maxLevel = 10, source = FISH,
    text = "Below 25 Fishing skill, use a Shiny Bauble lure. From 25 you catch fish every cast in starting zones." },
  { id = "prof-engineering-spec", topic = "professions", minLevel = 30, source = ENGI,
    text = "At level 30 with Engineering 200 you can pick Goblin or Gnomish Engineering (3 quests). The Membership Card lasts 14 days and must be renewed." },
  { id = "prof-skinning-cap", topic = "professions", minLevel = 10, source = SKIN,
    text = "To skin a mob of level 21 or higher you need skill equal to its level x 5 (a level 42 mob needs 210)." },
  { id = "prof-mining-smelt", topic = "professions", minLevel = 10, source = MINE,
    text = "Smelting gives Mining skill up to 185. You can only gain one Mining point per node." },

  -- dungeons
  { id = "dungeon-xp", topic = "dungeons", minLevel = 13, source = DUNG,
    text = "Dungeon grinding is less effective in Forever: dungeon experience was greatly reduced. Extra dungeon quest XP was added, then also reduced." },
  { id = "dungeon-cleave", topic = "dungeons", minLevel = 20, source = DUNG,
    text = "Spell cleave groups (Mage Blizzard, Warlock Rain of Fire, Hunter Volley) are high risk, high reward: a well-run group earns the most XP per hour." },

  -- travel
  { id = "travel-flight", topic = "travel", minLevel = 1, maxLevel = 12, source = FLY,
    text = "Talk to every flight master you pass to unlock it (an unknown one shows a green ! overhead). Flights cost silver; Request Stop drops you at the next point." },
  { id = "travel-ships", topic = "travel", minLevel = 10, source = FLY,
    text = "Ships and zeppelins are free, arrive every 3-5 minutes and wait about 1 minute. The Deeprun Tram runs every minute." },

  -- reputation and currency
  { id = "rep-writs", topic = "reputation", minLevel = 15, source = WRIT,
    text = "Craftsman's Writs are rare world drops that start a daily quest: Journeyman 75 rep, Expert 125, Artisan 200 with Durotar Supply and Logistics (Horde) or Azeroth Commerce Authority (Alliance)." },
  { id = "rep-crates", topic = "currency", minLevel = 10, source = ACA,
    text = "Waylaid Supply Crates drop everywhere. Fill one and hand it in for Merchant's Favor: Sealed Apprentice Crate 5 (10 if uncommon), Journeyman 10 (20 if uncommon)." },
  { id = "rep-first-crate", topic = "reputation", minLevel = 10, source = ACA,
    text = "Your first supply crate delivery gives 2000 reputation (2200 with the Legacy bonus). Shipping Label quests give 660 XP." },
  { id = "rep-receipt", topic = "reputation", minLevel = 15, source = ACA,
    text = "At Friendly, buy a Forged Delivery Receipt for 15 Merchant's Favor from the Uncertified Scribe; use it on an empty crate for 50 reputation." },
  { id = "rep-favor-rewards", topic = "currency", minLevel = 20, source = ACA,
    text = "Merchant's Favor buys recipes, the Pack Kodo mount (6000), the Minimule pet (1500), and at skill 300 a Certification (1000) for a profession title." },
  { id = "rep-centaurs", topic = "reputation", minLevel = 40, source = GELK,
    text = "Desolace centaurs (levels 40-43): Gelkis and Magram are rivals, rep with one lowers the other. Buying Friendship gives +3000 (Friendly) and unlocks Carved Centaur Totem turn-ins." },
  { id = "rep-nightclaw", topic = "reputation", minLevel = 10, maxLevel = 13, source = NCLW,
    text = "Nightclaw Druids on Zephras Isle (quests for levels 10-12): start with Unnerving Silence from Lotheluum Starbreeze in Valanaar." },
  { id = "rep-timbermaw", topic = "reputation", minLevel = 55, source = TMBR,
    text = "Timbermaw Hold starts at Hated. Start with Grazle south of Emerald Sanctuary in Felwood, and be Unfriendly before you walk through the cave." },
  { id = "rep-shendralar", topic = "reputation", minLevel = 54, source = SHEN,
    text = "In Dire Maul, hand in your class book once per character for 500 Shen'dralar reputation and a Royal Seal of Eldre'Thalas." },
  { id = "currency-tur", topic = "currency", minLevel = 55, source = TUR,
    text = "Tarnished Undermine Reals drop from dungeon bosses, usually level 55+, once per boss per day (final bosses give 3). Spend them with Pix Xizzix in Stranglethorn Vale." },
  { id = "currency-tur-items", topic = "currency", minLevel = 55, source = TUR,
    text = "Undermine Real prices: trinkets 125, belts 100, cloaks and rings 75, most relics 50 (Beta list, may change)." },

  -- books
  { id = "books-library", topic = "books", minLevel = 10, source = LIB,
    text = "Collect library books for your librarian (Owen Thadd in Undercity, Garion Wendell in Stormwind): 10, 20 and 25 books give an amulet, a ring, then a bigger reward." },
  { id = "books-mage", topic = "books", minLevel = 6, class = "MAGE", source = LIB,
    text = "Mages: your first book hand-in teaches Study (tied to Decipher Scrolls, from your trainer at level 6). Studying in the library gives scrolls once a day." },

  -- level 50 Sunken Temple class quests
  { id = "st-class-quests", topic = "class-quests", minLevel = 50, source = STQ,
    text = "At level 50 your class trainer gives a Sunken Temple class quest. In Forever you get all three rewards, not a choice." },
  { id = "st-hunter", topic = "class-quests", minLevel = 50, class = "HUNTER", source = STQ,
    text = "Hunter level-50 quest: The Hunter's Charm sends you to Ogtinc in Azshara; you get Hunting Spear, Devilsaur Eye and Devilsaur Tooth." },
  { id = "st-priest", topic = "class-quests", minLevel = 50, class = "PRIEST", source = STQ,
    text = "Priest level-50 quest: Cenarion Aid sends you to Ogtinc in Azshara; you get Blessed Prayer Beads, Woestave and Circle of Hope." },
  { id = "st-mage", topic = "class-quests", minLevel = 50, class = "MAGE", source = STQ,
    text = "Mage level-50 quest: Magecraft sends you to Sanath Lim-yo in Azshara; you get Glacial Spike, Arcane Crystal Pendant and Fire Ruby." },
  { id = "st-druid", topic = "class-quests", minLevel = 50, class = "DRUID", source = STQ,
    text = "Druid level-50 quest: Torwa Pathfinder in Un'Goro Crater; you get Grizzled Pelt, Forest's Embrace and Moonshadow Stave." },
  { id = "st-paladin", topic = "class-quests", minLevel = 50, class = "PALADIN", source = STQ,
    text = "Paladin level-50 quest: Chillwind Point sends you to Chillwind Camp; you get Lightforged Blade, Sanctified Orb and Chivalrous Signet." },
  { id = "st-rogue", topic = "class-quests", minLevel = 50, class = "ROGUE", source = STQ,
    text = "Rogue level-50 quest: A Simple Request sends you to Lord Jorach Ravenholdt; you get Ebon Mask, Whisperwalk Boots and Duskbat Drape." },
  { id = "st-shaman", topic = "class-quests", minLevel = 50, class = "SHAMAN", source = STQ,
    text = "Shaman level-50 quest: Elemental Mastery sends you to Bath'rah the Windwatcher in Alterac; you get Azurite Fists, Wildstaff and Enamored Water Spirit." },
  { id = "st-warlock", topic = "class-quests", minLevel = 50, class = "WARLOCK", source = STQ,
    text = "Warlock level-50 quest: An Imp's Request (bring Impsy in Felwood a Felcloth); you get Soul Harvester, Abyss Shard and Robes of Servitude." },
  { id = "st-warrior", topic = "class-quests", minLevel = 50, class = "WARRIOR", source = STQ,
    text = "Warrior level-50 quest: A Troubled Spirit sends you to the Fallen Hero of the Horde in Swamp of Sorrows; you get Fury Visor, Diamond Flask and Razorsteel Shoulders." },

  -- races
  { id = "race-skyborne-classes", topic = "race", minLevel = 1, maxLevel = 6, race = "Skyborne", source = SKY,
    text = "Skyborne can be Warrior, Hunter, Rogue or Druid; Shaman on the Horde side only, Mage on the Alliance side only." },
  { id = "race-skyborne-racials", topic = "race", minLevel = 1, maxLevel = 6, race = "Skyborne", source = SKY,
    text = "Skyborne racials: Walk on Air (glide down for 10 sec), Wind Blessed (+2% haste), Elemental Insight (+5% damage to Elementals)." },
  { id = "race-skyborne-skysight", topic = "race", minLevel = 1, maxLevel = 6, race = "Skyborne", source = SKY .. "; " .. RACE,
    text = "Horde Skyborne Skysight: +15% movement and mounted speed; near an elemental convergence you are Charged for 1 hour (guides differ: 30 sec, +100% / 15 sec, 30%)." },
  { id = "race-skyborne-leyline", topic = "race", minLevel = 1, maxLevel = 6, race = "Skyborne", source = SKY,
    text = "Alliance Skyborne Read Leyline: +50% health and mana regen for 15 sec; near a leyline you are Attuned for 1 hour and the effect becomes +100%." },
  { id = "race-skyborne-mounts", topic = "riding", minLevel = 40, race = "Skyborne", source = SKY,
    text = "Skyborne ride Galestriders: Empyrean, Stormy or Umber Galestrider at 40, Swift versions at 60, from Genn Fairweather west of Valanaar." },
  { id = "race-orc-command", topic = "race", minLevel = 10, class = "HUNTER", race = "Orc", source = RACE,
    text = "Orc racial Command: your pet deals 5% more damage." },
}
