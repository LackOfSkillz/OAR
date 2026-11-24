-- Data/Leveling_DungeonQuests.lua
-- Dungeon quests, dungeon entrances and recommended dungeon levels for the
-- leveling knowledge base, so dungeon guidance shares its source
-- (requirement 2026-11-21). Source: Wowhead's WoW Forever dungeon guides
-- (wowhead.com/forever/guide/..., read in the browser 2026-11-21):
--   each dungeon's own overview page (levels, quest givers)
--   EVERY    = Every Dungeon Quest in WoW Forever (Serenal, updated 2026-11-20)
--   OVERVIEW = Dungeons Overview for Forever (Serenal, updated 2026-11-15; entrances)
-- Hard rule 7: copied as written, /way numbers divided by 100, verified =
-- false until Gary has seen them in game. Zones by NAME. Where Wowhead's
-- tables contradict themselves (the same /way pasted onto a different NPC or
-- zone) the quest is left out instead of guessed. Krol'dok Stronghold's
-- entrance is already in Data/Leveling.lua ("river-kroldok").

local _, ns = ...
local function S(guide) return "wowhead.com Forever " .. guide .. " (read 2026-11-21)" end
local EVERY = S("Every Dungeon Quest guide")
local OVERVIEW = S("Dungeons Overview")
local SRC = {
  ["Ragefire Chasm"] = S("Ragefire Chasm dungeon overview"),
  ["Wailing Caverns"] = S("Wailing Caverns dungeon overview"),
  ["The Deadmines"] = S("The Deadmines dungeon overview"),
  ["Shadowfang Keep"] = S("Shadowfang Keep dungeon overview"),
  ["Blackfathom Deeps"] = S("Blackfathom Deeps dungeon overview"),
  ["The Stockade"] = S("The Stockade dungeon overview"),
  ["Gnomeregan"] = S("Gnomeregan dungeon overview"),
  ["Razorfen Kraul"] = S("Razorfen Kraul dungeon overview"),
  ["Scarlet Monastery"] = S("Scarlet Monastery Graveyard/Library/Armory/Cathedral overviews"),
  ["Razorfen Downs"] = S("Razorfen Downs dungeon overview"),
  ["Uldaman"] = S("Uldaman dungeon overview"),
  ["Zul'Farrak"] = S("Zul'Farrak dungeon overview"),
  ["Maraudon"] = S("Maraudon dungeon overview"),
  ["The Temple of Atal'Hakkar"] = S("The Temple of Atal'Hakkar dungeon overview"),
  ["Blackrock Depths"] = S("Blackrock Depths dungeon overview"),
  ["Lower Blackrock Spire"] = S("Lower Blackrock Spire dungeon overview"),
  ["Upper Blackrock Spire"] = S("Upper Blackrock Spire dungeon overview"),
  ["Dire Maul"] = S("Dire Maul East/West/North overviews"),
  ["Scholomance"] = S("Scholomance dungeon overview"),
  ["Stratholme"] = S("Stratholme Live/Undead Side overviews"),
  ["The Hall of Thanes"] = S("The Hall of Thanes dungeon overview"),
  ["Ruins of Lordaeron"] = S("Ruins of Lordaeron dungeon overview"),
  ["Excavation Site: Wetlands"] = S("Excavation Site, Wetlands dungeon overview"),
  ["City of Dalaran"] = S("City of Dalaran dungeon overview"),
  ["Krol'dok Stronghold"] = S("Krol'dok Stronghold dungeon overview"),
  ["Alcaz Prison"] = S("Alcaz Prison dungeon overview"),
  ["Blackmaw Hold"] = S("Blackmaw Hold dungeon overview"),
  ["The Drowned City"] = S("The Drowned City dungeon overview"),
}

local H, A = "Horde", "Alliance"

-- Quest starts. way = the /way numbers as printed; turned into 0..1 below.
local quests = {}
local function q(t)
  t.kind = "quest_start"
  t.x, t.y = t.way[1] / 100, t.way[2] / 100
  t.way = nil
  t.source = t.source or SRC[t.dungeon] or EVERY
  t.verified = false
  quests[#quests + 1] = t
end

-- Ragefire Chasm (all Horde)
local D = "Ragefire Chasm"
q{ id = "dq-rfc-slaying-the-beast", zone = "Orgrimmar", place = "The Drag", way = { 49, 50 }, name = "Neeru Fireblade", quest = "Slaying the Beast", dungeon = D, faction = H, level = 9,
  note = "Loot Taragaman the Hungerer's Heart. Reward: XP and money." }
q{ id = "dq-rfc-power-to-destroy", zone = "Undercity", place = "Royal Quarter", way = { 56, 92 }, name = "Varimathras", quest = "The Power to Destroy...", dungeon = D, faction = H, level = 9,
  note = "Loot two books from Searing Blade cultists/warlocks. Reward: Ghastly Trousers, Dredgemire Leggings or Gargoyle Leggings." }
q{ id = "dq-rfc-testing-enemy", zone = "Thunder Bluff", place = "Elder Rise", way = { 70, 30 }, name = "Rahauro", quest = "Testing an Enemy's Strength", dungeon = D, faction = H, level = 9,
  note = "Kill 8 Ragefire Trogg and 8 Ragefire Shaman. Reward: XP and money." }
q{ id = "dq-rfc-lost-satchel", zone = "Thunder Bluff", place = "Elder Rise", way = { 70, 30 }, name = "Rahauro", quest = "Searching for the Lost Satchel", dungeon = D, faction = H, level = 9,
  note = "Find Maur Grimtotem, bring the satchel back. Reward: Featherbead Bracers, Savannah Bracers or Garrison Cuffs." }
q{ id = "dq-rfc-hidden-enemies", zone = "Orgrimmar", place = "Valley of Wisdom", way = { 31, 37 }, name = "Thrall", quest = "Hidden Enemies", dungeon = D, faction = H, level = 9,
  note = "5-part chain (text: requires 13). Kill Bazzalan and Jergosh. Reward: Kris, Hammer, Axe or Staff of Orgrimmar." }

-- The Hall of Thanes (Forever-new). Givers stand in Old Ironforge, under the High Seat.
D = "The Hall of Thanes"
q{ id = "dq-hot-important-heirlooms", zone = "Ironforge", place = "Old Ironforge", way = { 32.6, 44.6 }, name = "Thom Filch", quest = "Important Heirlooms", dungeon = D, level = 10,
  note = "Both factions. Collect 8 Dwarven Heirloom. Reward: Dwarven Tome (off-hand)." }
q{ id = "dq-hot-restless-dead", zone = "Ironforge", place = "Old Ironforge", way = { 64.8, 58.4 }, name = "Afadra Dunwall", quest = "The Restless Dead", dungeon = D, faction = A, level = 10,
  note = "Kill 15 Enraged Apparitions and 10 Tormented Souls (first 3 rooms)." }

-- Ruins of Lordaeron (Forever-new)
D = "Ruins of Lordaeron"
q{ id = "dq-rol-wrath-of-rathmael", zone = "Tirisfal Glades", place = "Rear Guard Patrol", way = { 65.6, 60.2 }, name = "Deathguard Linnea", quest = "The Wrath of Rath'mael", dungeon = D, faction = H, level = 15,
  note = "Has a prequest. Kill Rath'mael. Reward: Gnarled Necromancer's Staff. Page text says Deathguard Kristof /way 65.2 60.2." }
q{ id = "dq-rol-frightened-request", zone = "Silverpine Forest", place = "The Sepulcher", way = { 44.6, 42.8 }, name = "Tabitha Heartweaver", quest = "A Frightened Request", dungeon = D, faction = H, level = 15,
  note = "Find Edward Heartweaver (by Rath'mael)." }
q{ id = "dq-rol-lights-justice", zone = "Undercity", place = "The Apothecarium", way = { 57.8, 89.8 }, name = "Morbin Lightbane", quest = "Light's Justice", dungeon = D, faction = H, level = 15,
  note = "Collect 25 Intact Limbs. Reward: The Stitcher (1H mace)." }
q{ id = "dq-rol-new-plague", zone = "Silverpine Forest", way = { 42.8, 40.8 }, name = "Apothecary Renferrel", quest = "The New Plague", dungeon = D, faction = H, level = 15,
  note = "After A Recipe For Death. Loot Highly Toxic Strain from Witherfang. Page text says Theodore Griffs, Undercity /way 47.0 72.6." }

-- Wailing Caverns
D = "Wailing Caverns"
q{ id = "dq-wc-serpentbloom", zone = "Thunder Bluff", place = "Pools of Vision", way = { 34, 21 }, name = "Apothecary Zamah", quest = "Serpentbloom", dungeon = D, faction = H, level = 14,
  note = "Loot 10 Serpentbloom. Reward: Apothecary Gloves." }
q{ id = "dq-wc-smart-drinks", zone = "The Barrens", place = "Ratchet", way = { 62, 37 }, name = "Mebok Mizzyrix", quest = "Smart Drinks", dungeon = D, level = 13,
  note = "Do Raptor Horns from him first. Loot 6 ectoplasm essences. Reward: XP and silver." }
q{ id = "dq-wc-trouble-at-docks", zone = "The Barrens", place = "Ratchet", way = { 63, 37 }, name = "Crane Operator Bigglefuzz", quest = "Trouble at the Docks", dungeon = D, level = 14,
  note = "Loot 99-Year-Old Port from Mad Magglish. Reward: XP and silver." }
q{ id = "dq-wc-deviate-hides", zone = "The Barrens", place = "cave above WC entrance", way = { 46, 35 }, name = "Nalpak", quest = "Deviate Hides", dungeon = D, level = 13,
  note = "Loot 20 Deviate Hide. Reward: Slick Deviate Leggings or Deviate Hide Pack (10-slot bag)." }
q{ id = "dq-wc-deviate-eradication", zone = "The Barrens", place = "cave above WC entrance", way = { 46, 35 }, name = "Ebru", quest = "Deviate Eradication", dungeon = D, level = 15,
  note = "Kill assorted mobs. Reward: Pattern: Deviate Scale Belt, Sizzle Stick (wand) or Dagmire Gauntlets." }

-- The Deadmines (Alliance, except A Moon-Kissed Blade)
D = "The Deadmines"
q{ id = "dq-dm-collecting-memories", zone = "Stormwind City", place = "Dwarven District", way = { 65, 21 }, name = "Wilder Thistlenettle", quest = "Collecting Memories", dungeon = D, faction = A, level = 14,
  note = "4 Miners' Union Card from elite undead in the mine tunnels outside the instance." }
q{ id = "dq-dm-oh-brother", zone = "Stormwind City", place = "Dwarven District", way = { 65, 21 }, name = "Wilder Thistlenettle", quest = "Oh Brother...", dungeon = D, faction = A, level = 15,
  note = "Loot Thistlenettle's Badge from Foreman Thistlenettle (outside the instance)." }
q{ id = "dq-dm-underground-assault", zone = "Stormwind City", place = "Dwarven District", way = { 55, 13 }, name = "Shoni the Shilent", quest = "Underground Assault", dungeon = D, faction = A, level = 15,
  note = "Breadcrumb from Gnoarn in Ironforge. Loot Gnoam Sprecklesprocket from Sneed's Shredder." }
q{ id = "dq-dm-red-silk-bandanas", zone = "Westfall", place = "Sentinel Hill", way = { 56, 47 }, name = "Scout Riell", quest = "Red Silk Bandanas", dungeon = D, faction = A, level = 14,
  note = "Needs the 6-quest Defias Brotherhood series. 10 Red Silk Bandana." }
q{ id = "dq-dm-defias-brotherhood", zone = "Westfall", place = "Sentinel Hill", way = { 56, 47 }, name = "Gryan Stoutmantle", quest = "The Defias Brotherhood", dungeon = D, faction = A, level = 14,
  note = "Chain ends with Head of VanCleef. Reward: Chausses of Westfall, Staff of Westfall or Tunic of Westfall." }
q{ id = "dq-dm-test-of-righteousness", zone = "Ironforge", place = "inside the Gates", way = { 52, 36 }, name = "Jordan Stilwell", quest = "The Test of Righteousness", dungeon = D, faction = A, level = 20,
  note = "Paladin only. Whitestone Oak Lumber; part of the Verigan's Fist chain (also SFK and BFD)." }
q{ id = "dq-dm-moon-kissed-blade", zone = "Silverpine Forest", place = "inside the crypt", way = { 43, 40 }, name = "Lumina Windsinger", quest = "A Moon-Kissed Blade", dungeon = D, faction = H, level = 20,
  note = "New in Forever, Paladin only: Horde version of The Test of Righteousness. SFK page: The Sepulcher /way 43.2 41.0." }

-- Shadowfang Keep
D = "Shadowfang Keep"
q{ id = "dq-sfk-book-of-ur", zone = "Undercity", place = "The Apothecarium", way = { 53, 54 }, name = "Keeper Bel'dugur", quest = "The Book of Ur", dungeon = D, faction = H, level = 16,
  note = "Book on the shelf in Fenrus' room. Reward: Grizzled Boots or Steel-clasped Bracers." }
q{ id = "dq-sfk-deathstalkers", zone = "Silverpine Forest", place = "The Sepulcher", way = { 43, 41 }, name = "High Executor Hadrec", quest = "Deathstalkers in Shadowfang", dungeon = D, faction = H, level = 18,
  note = "Speak to the corpse of Deathstalker Vincent. Reward: Ghostly Mantle." }
q{ id = "dq-sfk-arugal-must-die", zone = "Silverpine Forest", place = "The Sepulcher", way = { 44, 39 }, name = "Dalar Dawnweaver", quest = "Arugal Must Die", dungeon = D, faction = H, level = 18,
  note = "Loot Head of Arugal. Reward: Seal of Sylvanas (ring)." }
q{ id = "dq-sfk-orb-of-soranruk", zone = "The Barrens", place = "near Camp Taurajo", way = { 49, 57 }, name = "Doan Karhan", quest = "The Orb of Soran'ruk", dungeon = D, level = 20,
  note = "Warlock only; also Blackfathom Deeps." }

-- Blackfathom Deeps
D = "Blackfathom Deeps"
q{ id = "dq-bfd-essence-of-akumai", zone = "Ashenvale", place = "Zoram'gar Outpost", way = { 11, 34 }, name = "Je'neu Sancrea", quest = "The Essence of Aku'Mai", dungeon = D, faction = H, level = 17,
  note = "After Trouble in the Deeps (Tsunaman, Stonetalon). 20 Sapphire of Aku'Mai. Reward: silver and XP." }
q{ id = "dq-bfd-amongst-the-ruins", zone = "Ashenvale", place = "Zoram'gar Outpost", way = { 11, 34 }, name = "Je'neu Sancrea", quest = "Amongst the Ruins", dungeon = D, faction = H, level = 21,
  note = "Loot the Fathom Core (summons Baron Aquanis). Reward: silver and XP." }
q{ id = "dq-bfd-knowledge-in-deeps", zone = "Ironforge", place = "Forlorn Cave", way = { 50, 5 }, name = "Gerrig Bonegrip", quest = "Knowledge in the Deeps", dungeon = D, faction = A, level = 10,
  note = "Page text says requires level 19. Loot Lorgalis Manuscript. Reward: Sustaining Ring." }
q{ id = "dq-bfd-researching-corruption", zone = "Darkshore", place = "Auberdine", way = { 38, 43 }, name = "Gershala Nightwhisper", quest = "Researching the Corruption", dungeon = D, faction = A, level = 18,
  note = "Breadcrumb from Argos Nightwhisper, Stormwind. 8 Corrupted Brain Stem. Reward: Beetle Clasps or Prelacy Cape." }
q{ id = "dq-bfd-twilight-falls", zone = "Darnassus", place = "Craftsman's Terrace", way = { 55, 24 }, name = "Argent Guard Manados", quest = "Twilight Falls", dungeon = D, faction = A, level = 20,
  note = "10 Twilight Pendant. Reward: Nimbus Boots or Heartwood Girdle." }
q{ id = "dq-bfd-search-of-thaelrid", zone = "Darnassus", place = "Craftsman's Terrace", way = { 55, 24 }, name = "Dawnwatcher Shaedlass", quest = "In Search of Thaelrid", dungeon = D, faction = A, level = 18,
  note = "Leads to Blackfathom Villainy (Arctic Buckler or Gravestone Scepter)." }

-- The Stockade (all Alliance)
D = "The Stockade"
q{ id = "dq-stocks-quell-uprising", zone = "Stormwind City", place = "outside the Stockade", way = { 41, 58 }, name = "Warden Thelwater", quest = "Quell the Uprising", dungeon = D, faction = A, level = 22,
  note = "Kill Defias Prisoners, Convicts and Insurgents. Reward: XP and silver." }
q{ id = "dq-stocks-stockade-riots", zone = "Stormwind City", place = "outside the Stockade", way = { 41, 58 }, name = "Warden Thelwater", quest = "The Stockade Riots", dungeon = D, faction = A, level = 16,
  note = "After The Unsent Letter (Deadmines). Loot Head of Bazil Thredd. Reward: XP and silver." }
q{ id = "dq-stocks-crime-punishment", zone = "Duskwood", place = "Darkshire", way = { 72.0, 47.8 }, name = "Councilman Millstipe", quest = "Crime and Punishment", dungeon = D, faction = A, level = 22,
  note = "Loot Hand of Dextren Ward. Reward: Ambassador's Boots or Darkshire Mail Leggings. (Every Dungeon Quest guide misprints /way 42 47.)" }
q{ id = "dq-stocks-what-comes-around", zone = "Redridge Mountains", place = "Lakeshire", way = { 26, 46 }, name = "Guard Berton", quest = "What Comes Around...", dungeon = D, faction = A, level = 22,
  note = "Loot Targorr's head. Reward: Lucine Longsword or Hardened Root Staff." }
q{ id = "dq-stocks-fury-runs-deep", zone = "Wetlands", place = "Dun Modr", way = { 49, 18 }, name = "Motley Garmason", quest = "The Fury Runs Deep", dungeon = D, faction = A, level = 25,
  note = "Needs The Dark Iron War. Loot Kam Deepfury's head. Reward: Belt of Vindication or Headbasher." }

-- Excavation Site: Wetlands (Forever-new)
D = "Excavation Site: Wetlands"
q{ id = "dq-exc-changing-tastes", zone = "Orgrimmar", place = "The Drag", way = { 57, 33 }, name = "Borstan", quest = "Changing Tastes", dungeon = D, faction = H, level = 24,
  note = "4 Thicket Raptor Meat. Reward: Satchel of Potions (trinket)." }
q{ id = "dq-exc-open-the-maw", zone = "Wetlands", place = "hills outside the entrance", way = { 51, 59 }, name = "Deathstalker Agent", quest = "Open the Maw", dungeon = D, faction = H, level = 24,
  note = "Breadcrumb Dragonmaw Rumors from Zaruk, Hammerfall, Arathi /way 74 36. Kill Dragonmaw, loot Dragonmaw Dispatch." }
q{ id = "dq-exc-highland-hides", zone = "Wetlands", place = "Menethil Harbor", way = { 8, 55 }, name = "James Halloran", quest = "Highland Hides", dungeon = D, faction = A, level = 24,
  note = "After Young Crocolisk Skins (same NPC). 4 Thicket Raptor Hide (Shadetooth drops more)." }
q{ id = "dq-exc-songblade-search", zone = "Redridge Mountains", place = "Lakeshire", way = { 25.6, 46.6 }, name = "Dorin Songblade", quest = "Songblade Search", dungeon = D, faction = A, level = 24,
  note = "Find Dorin's brother in a Dragonmaw tent after the raptor area." }
q{ id = "dq-exc-horrors-highland", zone = "Wetlands", way = { 56.2, 40.6 }, name = "Rethiel the Greenwarden", quest = "Horrors in the Highland", dungeon = D, faction = A, level = 24,
  note = "Chain starts with The Greenwarden (First Mate Fitzsimmons, Menethil /way 11 60). Loot Horrible Rootcore." }
q{ id = "dq-exc-lost-in-thicket", zone = "Wetlands", place = "Menethil Harbor", way = { 12, 59 }, name = "Caitlin Grassman", quest = "Lost in the Thicket Things", dungeon = D, faction = A, level = 24,
  note = "Starts with Seeking Caitlin (Llana, Ashenvale /way 35.0 48.6). Follow-up Heartwoven: Satchel of Potions." }

-- Gnomeregan
D = "Gnomeregan"
q{ id = "dq-gnomer-rig-wars", zone = "Orgrimmar", place = "Valley of Honor", way = { 76, 25 }, name = "Nogg", quest = "Rig Wars", dungeon = D, faction = H, level = 25,
  note = "Rig Blueprints + Thermaplugg's Safe Combination. Reward: Civinad Robes, Triprunner Dungarees or Dual Reinforced Leggings." }
q{ id = "dq-gnomer-chief-engineer-scooty", zone = "Orgrimmar", place = "Valley of Honor", way = { 76, 25 }, name = "Sovik", quest = "Chief Engineer Scooty", dungeon = D, faction = H, level = 20,
  note = "Pick up Rig Wars first. Leads to Scooty in Booty Bay (teleporter to Gnomeregan)." }
q{ id = "dq-gnomer-gnomer-gooooone", zone = "Stranglethorn Vale", place = "Booty Bay", way = { 27, 77 }, name = "Scooty", quest = "Gnomer-gooooone!", dungeon = D, faction = H, level = 20,
  note = "Reward: Goblin Transponder (beams you from Booty Bay to Gnomeregan; keep it)." }
q{ id = "dq-gnomer-techbots-brain", zone = "Ironforge", place = "Tinkertown", way = { 69, 50 }, name = "Tinkmaster Overspark", quest = "Save Techbot's Brain!", dungeon = D, faction = A, level = 20,
  note = "Reward: 2,650 XP, Gnomeregan Exiles rep." }
q{ id = "dq-gnomer-gyrodrillmatic", zone = "Stormwind City", place = "Dwarven District", way = { 55, 12 }, name = "Shoni the Shilent", quest = "Gyrodrillmatic Excavationators", dungeon = D, faction = A, level = 20,
  note = "24 Robo-mechanical Guts. Reward: Shoni's Disarming Tool or Shilly Mitts." }
q{ id = "dq-gnomer-data-rescue", zone = "Ironforge", place = "Tinkertown", way = { 69, 48 }, name = "Master Mechanic Castpipe", quest = "Data Rescue", dungeon = D, faction = A, level = 25,
  note = "Punch cards White to Prismatic. Reward: Repairman's Cape or Mechanic's Pipehammer." }
q{ id = "dq-gnomer-grand-betrayal", zone = "Ironforge", place = "Tinkertown", way = { 68, 49 }, name = "High Tinker Mekkatorque", quest = "The Grand Betrayal", dungeon = D, faction = A, level = 25,
  note = "Kill Mekgineer Thermaplugg. Reward: Civinad Robes, Triprunner Dungarees or Dual Reinforced Leggings." }
q{ id = "dq-gnomer-gnogaine", zone = "Dun Morogh", place = "Kharanos", way = { 45, 49 }, name = "Ozzie Togglevolt", quest = "Gnogaine", dungeon = D, faction = A, level = 20,
  note = "Use the Empty Leaden Collection Phial on living Irradiated troggs. 2,200 XP." }
q{ id = "dq-gnomer-more-green-glow", zone = "Dun Morogh", place = "Kharanos", way = { 45, 49 }, name = "Ozzie Togglevolt", quest = "The Only Cure is More Green Glow", dungeon = D, faction = A, level = 20,
  note = "After Gnogaine. The High Potency Radioactive Fallout has 2 hours to return." }

-- City of Dalaran (Forever-new)
D = "City of Dalaran"
q{ id = "dq-cod-grave-knight", zone = "Hillsbrad Foothills", place = "Tarren Mill", way = { 62, 21 }, name = "Melisara", quest = "The Grave Knight", dungeon = D, faction = H, level = 24 }
q{ id = "dq-cod-source-of-power", zone = "Undercity", place = "The Apothecarium", way = { 46, 74 }, name = "Doctor Martin Felben", quest = "Source of Power", dungeon = D, faction = H, level = 24 }
q{ id = "dq-cod-heart-of-disruption-h", zone = "Hillsbrad Foothills", place = "Tarren Mill", way = { 62, 21 }, name = "Magus Wordeen Voidglare", quest = "Heart of Disruption", dungeon = D, faction = H, level = 24,
  note = "Key chain starts here: Prison Break In + Key to the City. Heart of Disruption gives the Dalaran Sewer Key." }
q{ id = "dq-cod-power-overwhelming", zone = "Stormwind City", place = "Magic Quarter", way = { 49, 88 }, name = "High Sorcerer Andromath", quest = "Power Overwhelming", dungeon = D, faction = A, level = 24 }
q{ id = "dq-cod-alarming-request", zone = "Hillsbrad Foothills", place = "Southshore", way = { 48, 60 }, name = "Emissary Jacques", quest = "An Alarming Request", dungeon = D, faction = A,
  note = "Starts the chain to Heart of Disruption and Starving Arcane (both level 30)." }
q{ id = "dq-cod-green-sample", zone = "Stormwind City", place = "The Park", way = { 32, 63 }, name = "Shylamiir", quest = "A Green Sample", dungeon = D, faction = A, level = 24 }

-- Razorfen Kraul
D = "Razorfen Kraul"
q{ id = "dq-rfk-vengeful-fate", zone = "Thunder Bluff", place = "near the main lift", way = { 37, 29 }, name = "Auld Stonespire", quest = "A Vengeful Fate", dungeon = D, faction = H, level = 29,
  note = "Loot Razorflank's Heart. Reward: Berylline Pads, Stonefist Girdle or Marbled Buckler." }
q{ id = "dq-rfk-going-going-guano", zone = "Undercity", place = "The Apothecarium", way = { 48, 69 }, name = "Master Apothecary Faranell", quest = "Going, Going, Guano!", dungeon = D, faction = H, level = 30,
  note = "Loot Kraul Guano (bats, last section). Unlocks Hearts of Zeal (Scarlet Monastery)." }
q{ id = "dq-rfk-blueleaf-tubers", zone = "The Barrens", place = "Ratchet", way = { 62, 37 }, name = "Mebok Mizzyrix", quest = "Blueleaf Tubers", dungeon = D, level = 20,
  note = "Quest items are next to Mizzyrix. Reward: A Small Container of Gems." }
q{ id = "dq-rfk-crone-of-kraul", zone = "Feralas", place = "The Lower Wilds", way = { 89, 46 }, name = "Falfindel Waywarder", quest = "The Crone of the Kraul", dungeon = D, faction = A, level = 29,
  note = "After Lonebrow's Journal. Reward: Berylline Pads, Stonefist Girdle or Marbled Buckler." }

-- The Drowned City (Forever-new)
D = "The Drowned City"
q{ id = "dq-tdc-drowned-city", zone = "Stranglethorn Vale", place = "Grom'gol", way = { 32.2, 27.8 }, name = "Kin'weelay", quest = "The Drowned City", dungeon = D, faction = H, level = 30,
  note = "Starts with The Vile Reef from Kin'weelay." }
q{ id = "dq-tdc-only-good-brinescale", zone = "Stranglethorn Vale", place = "Grom'gol", way = { 32.2, 28.8 }, name = "Commander Aggro'gosh", quest = "The Only Good Brinescale...", dungeon = D, faction = H, level = 30,
  note = "After The Vile Reef, then Enemies in the Water." }
q{ id = "dq-tdc-shady-saltseers", zone = "Stranglethorn Vale", place = "Booty Bay", way = { 27.0, 77.2 }, name = "Krazek", quest = "Shady Saltseers", dungeon = D, level = 34,
  note = "Both factions. Reward: Saltseer's Helm (leather helm)." }
q{ id = "dq-tdc-saltseer-captain", zone = "Stranglethorn Vale", place = "Booty Bay", way = { 27.0, 77.2 }, name = "Krazek", quest = "The Saltseer Captain", dungeon = D, level = 34,
  note = "Both factions." }
q{ id = "dq-tdc-magics-drowned-city", zone = "Hillsbrad Foothills", place = "Southshore", way = { 50.6, 57.0 }, name = "Loremaster Dibbs", quest = "Magics of the Drowned City", dungeon = D, faction = A, level = 30,
  note = "Chain from The Second Rebellion / Bad Medicine; Troll Witchery last. Leads to The Web of Magic." }
q{ id = "dq-tdc-take-two-with-water", zone = "Hillsbrad Foothills", place = "Southshore", way = { 50.6, 57.0 }, name = "Loremaster Dibbs", quest = "Take Two With Water", dungeon = D, faction = A, level = 30,
  note = "Same chain. Leads to Findings for the Explorer's League: Ancient Voodoo Pouch or Intrepid Explorer's Chainmail." }
q{ id = "dq-tdc-gurubashi-secrets", zone = "Alterac Mountains", place = "Dalaran", way = { 15.6, 73.6 }, name = "Archmage Timear", quest = "Ancient Gurubashi Secrets", dungeon = D, faction = A, level = 34 }

-- Scarlet Monastery
D = "Scarlet Monastery"
q{ id = "dq-sm-into-scarlet-monastery", zone = "Undercity", place = "Royal Quarter", way = { 56, 92 }, name = "Varimathras", quest = "Into The Scarlet Monastery", dungeon = D, faction = H, level = 33,
  note = "Kill Loksey, Herod, Mograine and Whitemane. Reward: Sword of Omen, Prophetic Cane or Dragon's Blood Necklace." }
q{ id = "dq-sm-hearts-of-zeal", zone = "Undercity", place = "The Apothecarium", way = { 48, 69 }, name = "Master Apothecary Faranell", quest = "Hearts of Zeal", dungeon = D, faction = H, level = 30,
  note = "After Going, Going, Guano! (RFK). 20 Heart of Zeal from Scarlet mobs outside SM. 3,300 XP." }
q{ id = "dq-sm-compendium-of-fallen", zone = "Thunder Bluff", place = "First Rise", way = { 36, 26 }, name = "Sage Truthseeker", quest = "Compendium of the Fallen", dungeon = D, faction = H, level = 28,
  note = "Library. Not for Undead. Reward: Vile Protector, Forcestone Buckler or Omega Orb." }
q{ id = "dq-sm-test-of-lore", zone = "Undercity", place = "The Apothecarium", way = { 57, 65 }, name = "Parqual Fintallas", quest = "Test of Lore", dungeon = D, faction = H, level = 25,
  note = "Chain starts with Test of Faith (Dorn Plainstalker, Thousand Needles /way 54 42). Reward: Windstorm Hammer or Dancing Flame." }
q{ id = "dq-sm-rituals-of-power", zone = "Thousand Needles", place = "Shimmering Flats Raceway", way = { 78, 75 }, name = "Magus Tirth", quest = "Rituals of Power", dungeon = D, level = 30,
  note = "Mage only; chain of 3 (Library). 3,150 XP." }
q{ id = "dq-sm-name-of-the-light", zone = "Hillsbrad Foothills", place = "Southshore", way = { 51, 58 }, name = "Raleigh the Devout", quest = "In the Name of the Light", dungeon = D, faction = A, level = 34,
  note = "3 prequests from Brother Anton. Reward: Sword of Serenity, Bonebiter, Black Menace or Orb of Lorica." }
q{ id = "dq-sm-mythology-of-titans", zone = "Ironforge", place = "Hall of Explorers", way = { 75, 12 }, name = "Librarian Mae Paledust", quest = "Mythology of the Titans", dungeon = D, faction = A, level = 28,
  note = "Library. Reward: Explorers' League Commendation; 3,550 XP." }
q{ id = "dq-sm-past-due", zone = "Alterac Mountains", place = "Dalaran", way = { 10.0, 63.8 }, name = "Magus Olvek", quest = "Past Due", dungeon = D, faction = A, level = 30,
  note = "Library (text says level 28). From Arcanist Doan. Reward: Explorers' League Commendation; 6,750 XP; Kirin Tor rep." }

-- Razorfen Downs
D = "Razorfen Downs"
q{ id = "dq-rfd-coldbringers-eye-h", zone = "Mulgore", place = "Skywatcher's Plateau", way = { 34.6, 22.8 }, name = "Sutara Plainstalker", quest = "The Coldbringer's Eye", dungeon = D, faction = H, level = 34,
  note = "New in Forever. Loot The Coldbringer's Eye next to Amnennar. Reward: XP and silver." }
q{ id = "dq-rfd-bring-the-end", zone = "Undercity", place = "Magic Quarter", way = { 74, 33 }, name = "Andrew Brownell", quest = "Bring the End", dungeon = D, faction = H, level = 37,
  note = "Loot Skull of the Coldbringer. Reward: Vanquisher's Sword or Amberglow Talisman." }
q{ id = "dq-rfd-bring-the-light", zone = "Stormwind City", place = "Cathedral", way = { 39, 27 }, name = "Archbishop Benedictus", quest = "Bring the Light", dungeon = D, faction = A, level = 39,
  note = "Kill Amnennar. Reward: Vanquisher's Sword or Amberglow Talisman." }

-- Uldaman
D = "Uldaman"
q{ id = "dq-ulda-reclaimed-treasures-h", zone = "Undercity", place = "center", way = { 62, 48 }, name = "Patrick Garrett", quest = "Reclaimed Treasures", dungeon = D, faction = H, level = 33,
  note = "Reward: 60 silver." }
q{ id = "dq-ulda-reagent-run-h", zone = "Badlands", place = "Kargath", way = { 3, 46 }, name = "Jarkal Mossmeld", quest = "Uldaman Reagent Run", dungeon = D, faction = H, level = 36,
  note = "After Badlands Reagent Run (same NPC). Magenta Fungus Cap. Reward: Restorative Potion." }
q{ id = "dq-ulda-power-stones", zone = "Badlands", place = "central Badlands", way = { 42, 52 }, name = "Rigglefuzz", quest = "Power Stones", dungeon = D, level = 30,
  note = "8 Dentrium + 8 An'Alleum Power Stone. Reward: Energized Stone Circle, Duracin Bracers or Everlast Boots." }
q{ id = "dq-ulda-solution-to-doom", zone = "Badlands", place = "southern Badlands", way = { 51, 76 }, name = "Theldurin the Lost", quest = "Solution to Doom", dungeon = D, level = 30,
  note = "Reward: Doomsayer's Robe; 3,150 XP." }
q{ id = "dq-ulda-power-in-uldaman", zone = "Dustwallow Marsh", place = "north of Stonemaul Ruins", way = { 46, 57 }, name = "Tabetha", quest = "Power in Uldaman", dungeon = D, level = 35,
  note = "Mage only; 3 quests starting with Return to the Marsh. Obsidian Power Source from the Obsidian Sentinel." }
q{ id = "dq-ulda-reclaimed-treasures-a", zone = "Ironforge", place = "Hall of Explorers", way = { 74, 9 }, name = "Krom Stoutarm", quest = "Reclaimed Treasures", dungeon = D, faction = A, level = 33,
  note = "Reward: 60 silver, 3,600 XP." }
q{ id = "dq-ulda-lost-dwarves", zone = "Ironforge", place = "Hall of Explorers", way = { 75, 12 }, name = "Prospector Stormpike", quest = "The Lost Dwarves", dungeon = D, faction = A, level = 35,
  note = "Leads to The Hidden Chamber: Dwarven Charge or Explorer's League Lodestar." }
q{ id = "dq-ulda-reagent-run-a", zone = "Loch Modan", place = "Thelsamar", way = { 37, 49 }, name = "Ghak Healtouch", quest = "Uldaman Reagent Run", dungeon = D, faction = A, level = 38,
  note = "After Badlands Reagent Run. Reward: Restorative Potion." }
q{ id = "dq-ulda-agmonds-fate", zone = "Loch Modan", place = "Ironband's Excavation Site", way = { 65, 65 }, name = "Prospector Ironband", quest = "Agmond's Fate", dungeon = D, faction = A, level = 33,
  note = "3 prequests from Ironband Wants You!. Reward: Prospector Gloves." }
q{ id = "dq-ulda-lost-tablets-of-will", zone = "Ironforge", place = "Hall of Explorers", way = { 77, 9 }, name = "Advisor Belgrum", quest = "The Lost Tablets of Will", dungeon = D, faction = A, level = 30,
  note = "8 prequests from A Sign of Hope (Crumpled Map, Badlands /way 53 34). Reward: Medal of Courage." }

-- Krol'dok Stronghold (Forever-new, Riverglades)
D = "Krol'dok Stronghold"
q{ id = "dq-krol-token-of-vengeance", zone = "Riverglades", place = "Krol'dok Stronghold Outskirts", way = { 33.4, 38 }, name = "Da'grosh", quest = "A Token of Vengeance", dungeon = D, faction = H, level = 38,
  note = "Chain from Krom'rosh leading to The Wayward Warrior (/way 59.4 45.6)." }
q{ id = "dq-krol-tome-of-twilight-h", zone = "Riverglades", place = "Rom'gar", way = { 59.4, 44 }, name = "Tran'gul", quest = "Tome of Twilight", dungeon = D, faction = H, level = 38,
  note = "Same Krom'rosh chain first." }
q{ id = "dq-krol-eye-of-mugg-h", zone = "Riverglades", place = "Rom'gar", way = { 59.4, 45.6 }, name = "Krom'rosh", quest = "Eye of Mugg", dungeon = D, faction = H, level = 38,
  note = "Reward: Rock on Stick, Stick No Rock or Bigger Rock on Bigger Stick." }
q{ id = "dq-krol-vengeance-highborne", zone = "Alterac Mountains", place = "Dalaran", way = { 17.8, 66.0 }, name = "Ranath Nightstride", quest = "Vengeance of the Highborne", dungeon = D, faction = A, level = 37 }
q{ id = "dq-krol-twilight-mementos", zone = "Riverglades", place = "Twilight's Shroud", way = { 30.6, 49.0 }, name = "Sergeant Riftan", quest = "Twilight Mementos", dungeon = D, faction = A, level = 38,
  note = "Leads to Curios of Curiosity. Chain starts at Farholde Keep (Ashe Amberhall, Demar Brant)." }
q{ id = "dq-krol-eye-of-mugg-a", zone = "Riverglades", place = "Farholde Keep", way = { 66.6, 81.0 }, name = "Demar Brant", quest = "Eye of Mugg", dungeon = D, faction = A, level = 40,
  note = "After Curious Trinkets, Scraps of Knowledge, Saving Sunnyglade. Reward: Rock on Stick, Stick No Rock or Bigger Rock on Bigger Stick." }
q{ id = "dq-krol-tome-of-twilight-a", zone = "Riverglades", place = "Farholde Keep", way = { 66.6, 81.0 }, name = "Ashe Amberhall", quest = "Tome of Twilight", dungeon = D, faction = A, level = 39,
  note = "Same Farholde Keep chain first." }

-- Zul'Farrak
D = "Zul'Farrak"
q{ id = "dq-zf-spider-god", zone = "Durotar", place = "Sen'jin Village", way = { 56, 74 }, name = "Master Gadrin", quest = "The Spider God", dungeon = D, faction = H, level = 40,
  note = "4th step after Venom Bottles (Hinterlands /way 23 58). Click the Tablet of Theka. XP and silver." }
q{ id = "dq-zf-zumrahs-head", zone = "Mulgore", place = "Skywatcher Plateau", way = { 32, 21 }, name = "Mazu'kon", quest = "Zum'rah's Head", dungeon = D, faction = H, level = 42,
  note = "New in Forever." }
q{ id = "dq-zf-divino-matic-rod", zone = "Tanaris", place = "Gadgetzan", way = { 52, 28 }, name = "Chief Engineer Bilgewhizzle", quest = "Divino-matic Rod", dungeon = D, level = 40,
  note = "From Sergeant Bly. Reward: Masons Fraternity Ring or Engineer's Guild Headpiece." }
q{ id = "dq-zf-scarab-shells", zone = "Tanaris", place = "Gadgetzan", way = { 51, 26 }, name = "Tran'rek", quest = "Scarab Shells", dungeon = D, level = 40,
  note = "Requires Tran'rek (starts in Booty Bay). 5 Uncracked Scarab Shell. XP and silver." }
q{ id = "dq-zf-troll-temper", zone = "Tanaris", place = "Gadgetzan", way = { 51, 28 }, name = "Trenton Lighthammer", quest = "Troll Temper", dungeon = D, level = 40,
  note = "20 Troll Temper. XP and silver." }
q{ id = "dq-zf-tiara-of-the-deep", zone = "Dustwallow Marsh", place = "north of Stonemaul Ruins", way = { 46, 57 }, name = "Tabetha", quest = "Tiara of the Deep", dungeon = D, level = 40,
  note = "From Hydromancer Velratha. Reward: Spellshifter Rod or Gemshale Pauldrons." }
q{ id = "dq-zf-gahzrilla", zone = "Thousand Needles", place = "Shimmering Flats", way = { 78, 77 }, name = "Wizzle Brassbolts", quest = "Gahz'rilla", dungeon = D, level = 40,
  note = "Needs the Mallet of Zul'Farrak (Qiaga the Keeper, Hinterlands). Reward: Carrot on a Stick (trinket)." }
q{ id = "dq-zf-prophecy-of-mosharu", zone = "Tanaris", place = "Steamwheedle Port", way = { 67, 22 }, name = "Yeh'kinya", quest = "The Prophecy of Mosh'aru", dungeon = D, level = 40,
  note = "After Screecher Spirits. Tablets from Velratha and Theka. XP and silver." }
q{ id = "dq-zf-nekrums-medallion", zone = "Blasted Lands", place = "Nethergarde Keep", way = { 66, 19 }, name = "Thadius Grimshade", quest = "Nekrum's Medallion", dungeon = D, faction = A, level = 40,
  note = "4th step after Witherbark Cages (Gryphon Master Talonaxe, Hinterlands /way 10 47). XP and silver." }

-- Maraudon
D = "Maraudon"
q{ id = "dq-mara-anshes-radiance", zone = "Mulgore", place = "Skywatcher's Plateau", way = { 32.6, 24 }, name = "Olana Brighthoof", quest = "An'she's Radiance", dungeon = D, faction = H, level = 43,
  note = "New in Forever." }
q{ id = "dq-mara-shadowshard-h", zone = "Orgrimmar", place = "Valley of Spirits", way = { 39, 86 }, name = "Uthel'nay", quest = "Shadowshard Fragments", dungeon = D, faction = H, level = 39,
  note = "Shadowshard Smashers outside the purple entrance. Reward: Zealous or Prodigious Shadowshard Pendant." }
q{ id = "dq-mara-vyletongue-h", zone = "Desolace", place = "Shadowprey Village", way = { 23, 70 }, name = "Vark Battlescar", quest = "Vyletongue Corruption", dungeon = D, faction = H, level = 41,
  note = "Reward: Woodseed Hoop, Sagebrush Girdle or Branchclaw Gauntlets." }
q{ id = "dq-mara-earth-and-seed-h", zone = "Desolace", place = "south of Shadowprey Village", way = { 26, 77 }, name = "Selendra", quest = "Corruption of Earth and Seed", dungeon = D, faction = H, level = 45,
  note = "Kill Princess Theradras. Reward: Thrash Blade, Verdant Keeper's Aim or Resurgence Rod." }
q{ id = "dq-mara-rot-and-regret", zone = "Shen'dralas", place = "Woodwyrd", way = { 60, 72 }, quest = "Rot and Regret", dungeon = D, level = 35,
  note = "New in Forever. Starts with Strange Pylons (Shen'dralar Pylon, Shen'dralas /way 44 34). Giver not named." }
q{ id = "dq-mara-twisted-evils", zone = "Desolace", place = "SE of Thunderaxe Fortress", way = { 62, 39 }, name = "Willow", quest = "Twisted Evils", dungeon = D, level = 41,
  note = "Reward: Acumen Robes, Sprightring Helm, Relentless Chain or Hulkstone Pauldrons." }
q{ id = "dq-mara-pariahs-instructions", zone = "Desolace", place = "south of Mannoroc Coven (patrols)", way = { 48.4, 87.0 }, name = "Centaur Pariah", quest = "The Pariah's Instructions", dungeon = D, level = 39,
  note = "Use the Amulet of Spirits on 5 Kahns. Reward: Mark of the Chosen (trinket)." }
q{ id = "dq-mara-shadowshard-a", zone = "Dustwallow Marsh", place = "Theramore", way = { 66, 49 }, name = "Archmage Tervosh", quest = "Shadowshard Fragments", dungeon = D, faction = A, level = 39,
  note = "Shadowshard Smashers outside the purple entrance. Reward: Zealous or Prodigious Shadowshard Pendant." }
q{ id = "dq-mara-vyletongue-a", zone = "Desolace", place = "Nijel's Point", way = { 68, 8 }, name = "Talendria", quest = "Vyletongue Corruption", dungeon = D, faction = A, level = 41,
  note = "Reward: Woodseed Hoop, Sagebrush Girdle or Branchclaw Gauntlets." }
q{ id = "dq-mara-earth-and-seed-a", zone = "Desolace", place = "Nijel's Point", way = { 63, 10 }, name = "Keeper Marandis", quest = "Corruption of Earth and Seed", dungeon = D, faction = A, level = 45,
  note = "Kill Princess Theradras. Reward: Thrash Blade, Verdant Keeper's Aim or Resurgence Rod." }

-- The Temple of Atal'Hakkar (Sunken Temple)
D = "The Temple of Atal'Hakkar"
q{ id = "dq-st-temple-of-atalhakkar", zone = "Swamp of Sorrows", place = "Stonard", way = { 47, 54 }, name = "Fel'zerul", quest = "The Temple of Atal'Hakkar", dungeon = D, faction = H, level = 38,
  note = "3 quests starting with Pool of Tears. 20 Fetish of Hakkar. Reward: Guardian Talisman." }
q{ id = "dq-st-zapper-fuel", zone = "The Barrens", place = "Ratchet", way = { 62, 38 }, name = "Liv Rizzlefix", quest = "Zapper Fuel", dungeon = D, faction = H, level = 47,
  note = "After Larion and Muigin (Un'Goro). 5 Atal'ai Haze. 5,900 XP." }
q{ id = "dq-st-jammalan", zone = "The Hinterlands", place = "spider area SW of Altar of Zul", way = { 33, 75 }, name = "Atal'ai Exile", quest = "Jammal'an the Prophet", dungeon = D, level = 38,
  note = "Head of Jammal'an. Reward: Rainstrider Leggings or Helm of Exile." }
q{ id = "dq-st-into-the-depths", zone = "Tanaris", place = "south of Gadgetzan", way = { 52, 45 }, name = "Marvon Rivetseeker", quest = "Into the Depths", dungeon = D, level = 46,
  note = "After The Sunken Temple. Interact with the Altar of Hakkar. 4,900 XP." }
q{ id = "dq-st-secret-of-the-circle", zone = "Tanaris", place = "south of Gadgetzan", way = { 52, 45 }, name = "Marvon Rivetseeker", quest = "Secret of the Circle", dungeon = D, level = 46,
  note = "Click the snake statue after Atal'alarion. Reward: Hakkari Urn." }
q{ id = "dq-st-god-hakkar", zone = "Tanaris", place = "Steamwheedle Port", way = { 67, 22 }, name = "Yeh'kinya", quest = "The God Hakkar", dungeon = D, level = 40,
  note = "Chain from Screecher Spirits; needed to summon the Avatar of Hakkar. Reward: Avenguard Helm, Lifeforce Dirk or Gemburst Circlet." }
q{ id = "dq-st-haze-of-evil", zone = "Feralas", place = "Twin Colossals", way = { 45, 25 }, name = "Gregan Brewspewer", quest = "Haze of Evil", dungeon = D, faction = A, level = 47,
  note = "After Muigin and Larion. 75 silver, 5,100 XP." }
q{ id = "dq-st-into-the-temple", zone = "Stormwind City", place = "Dwarven District", way = { 64, 21 }, name = "Brohann Caskbelly", quest = "Into The Temple of Atal'Hakkar", dungeon = D, faction = A, level = 38,
  note = "6 prequests from In Search of The Temple. Reward: Guardian Talisman." }

-- Alcaz Prison (Forever-new)
D = "Alcaz Prison"
q{ id = "dq-alcaz-missing-korkron", zone = "Orgrimmar", way = { 34.6, 38.6 }, name = "Eitrigg", quest = "The Missing Kor'kron", dungeon = D, faction = H,
  note = "Starts the Horde chain to Sergeant Ulka on Alcaz Island: No Orc Left Behind, A Little Payback, Blood Red Bandanas (48)." }
q{ id = "dq-alcaz-dragons-journal", zone = "Alterac Mountains", place = "Dalaran", way = { 15.6, 73.6 }, name = "Archmage Lan'dalock", quest = "The Dragon's Journal", dungeon = D, faction = A, level = 46 }
q{ id = "dq-alcaz-wet-work", zone = "Dustwallow Marsh", place = "Theramore Graveyard", way = { 63.4, 42.4 }, name = "Sully McCleary", quest = "A Bit of Wet Work", dungeon = D, faction = A, level = 48,
  note = "Chain from Our Man in Theramore (Master Mathias Shaw, Stormwind Old Town). Leads to Somber News." }
q{ id = "dq-alcaz-secret-prison", zone = "Dustwallow Marsh", place = "Theramore Graveyard", way = { 63.4, 42.4 }, name = "Sully McCleary", quest = "The Secret Prison", dungeon = D, faction = A, level = 48,
  note = "Same chain from Our Man in Theramore." }

-- Blackrock Depths
D = "Blackrock Depths"
q{ id = "dq-brd-kos-dark-iron", zone = "Badlands", place = "Kargath", way = { 4.0, 46.8 }, name = "WANTED poster", quest = "KILL ON SIGHT: Dark Iron Dwarves", dungeon = D, faction = H, level = 48,
  note = "Return to Warlord Goretooth. 15 Guardsman, 10 Warden, 5 Footman." }
q{ id = "dq-brd-kos-officials", zone = "Badlands", place = "Kargath", way = { 4.0, 46.8 }, name = "WANTED poster", quest = "KILL ON SIGHT: High Ranking Dark Iron Officials", dungeon = D, faction = H, level = 50,
  note = "After the first KILL ON SIGHT." }
q{ id = "dq-brd-lost-thunderbrew-h", zone = "Badlands", place = "Kargath", way = { 3.0, 47.6 }, name = "Shadowmage Vivian Lagrave", quest = "Lost Thunderbrew Recipe", dungeon = D, faction = H, level = 50,
  note = "Breadcrumb from Apothecary Zinge, Undercity /way 50.0 68.6. Reward: Swiftstrike Cudgel or Limb Cleaver." }
q{ id = "dq-brd-rise-of-machines", zone = "Badlands", place = "camp east of Kargath", way = { 25.8, 45.0 }, name = "Lotwil Veriatus", quest = "The Rise of the Machines", dungeon = D, faction = H, level = 52,
  note = "Starts with Hierophant Theodora Mulvadania, Kargath /way 3.0 47.8 (3 quests)." }
q{ id = "dq-brd-disharmony-of-flame", zone = "Badlands", place = "Kargath", way = { 3.6, 48.0 }, name = "Thunderheart", quest = "Disharmony of Flame", dungeon = D, faction = H, level = 48,
  note = "Kill Overmaster Pyron, then Disharmony of Fire (Lord Incendius)." }
q{ id = "dq-brd-commander-gorshak", zone = "Badlands", place = "Kargath", way = { 5.8, 47.6 }, name = "Galamav the Marksman", quest = "Commander Gor'shak", dungeon = D, faction = H, level = 48,
  note = "Leads to The Royal Rescue (Thrall). Reward: Eye of Orgrimmar or Thrall's Resolve." }
q{ id = "dq-brd-last-element", zone = "Badlands", place = "Kargath", way = { 3.0, 47.6 }, name = "Shadowmage Vivian Lagrave", quest = "The Last Element", dungeon = D, faction = H, level = 48,
  note = "10 Essence of the Elements. Reward: Lagrave's Seal." }
q{ id = "dq-brd-death-to-angerforge", zone = "Badlands", place = "Kargath", way = { 3.0, 47.6 }, name = "Warlord Goretooth", quest = "Operation: Death to Angerforge", dungeon = D, faction = H, level = 52,
  note = "After both KILL ON SIGHT, Grark Lorkrub escort, Precarious Predicament. Reward: Conqueror's Medallion. EVERY: /way 6 47." }
q{ id = "dq-brd-royal-rescue", zone = "Orgrimmar", place = "Valley of Wisdom", way = { 32, 38 }, name = "Thrall", quest = "The Royal Rescue", dungeon = D, faction = H, level = 48,
  note = "4 quests first, starting with Commander Gor'shak." }
q{ id = "dq-brd-ribbly", zone = "Burning Steppes", place = "Flame Crest", way = { 66, 21 }, name = "Yuka Screwspigot", quest = "Ribbly Screwspigot", dungeon = D, level = 50,
  note = "Breadcrumb from Yorba Screwspigot, Steamwheedle Port /way 67.0 24.0. Reward: Rancor Boots, Penance Spaulders or Splintsteel Armor." }
q{ id = "dq-brd-heart-of-mountain", zone = "Burning Steppes", place = "Flame Crest", way = { 65.2, 23.8 }, name = "Maxwort Uberglint", quest = "The Heart of the Mountain", dungeon = D, level = 50,
  note = "85 silver, 5,650 XP." }
q{ id = "dq-brd-taste-of-flame", zone = "Burning Steppes", place = "cave in NE Burning Steppes", way = { 95.0, 31.4 }, name = "Cyrus Therepentous", quest = "A Taste of Flame", dungeon = D, level = 52,
  note = "11 quests first from Divine Retribution. Reward: Shaleskin Cape, Wyrmhide Spaulders or Valconian Sash." }
q{ id = "dq-brd-overmaster-pyron", zone = "Burning Steppes", place = "Morgan's Vigil", way = { 85.4, 70.0 }, name = "Jalinda Sprig", quest = "Overmaster Pyron", dungeon = D, faction = A, level = 48,
  note = "Then Incendius!. Reward: Sunborne Cape, Nightfall Gloves, Crypt Demon Bracers or Stalwart Clutch." }
q{ id = "dq-brd-good-stuff", zone = "Burning Steppes", place = "Morgan's Vigil", way = { 84, 68 }, name = "Oralius", quest = "The Good Stuff", dungeon = D, faction = A, level = 50,
  note = "Reward: A Dingy Fanny Pack. (Page text says Jalinda Sprig.)" }
q{ id = "dq-brd-hurley-blackbreath", zone = "Dun Morogh", place = "Kharanos", way = { 46.8, 52.4 }, name = "Ragnar Thunderbrew", quest = "Hurley Blackbreath", dungeon = D, faction = A, level = 50,
  note = "Breadcrumb from Enohar Thunderbrew, Blasted Lands /way 63.6 20.4. Reward: Swiftstrike Cudgel or Limb Cleaver." }
q{ id = "dq-brd-kharan-mighthammer", zone = "Ironforge", place = "Throne Room", way = { 40.0, 55.2 }, name = "King Magni Bronzebeard", quest = "Kharan Mighthammer", dungeon = D, faction = A, level = 50,
  note = "After The Smoldering Ruins of Thaurissan. Chain to The Fate of the Kingdom: Magni's Will or Songstone of Ironforge." }
q{ id = "dq-brd-marshal-windsor", zone = "Burning Steppes", place = "Morgan's Vigil", way = { 84, 68 }, name = "Marshal Maxwell", quest = "Marshal Windsor", dungeon = D, faction = A, level = 48,
  note = "After Dragonkin Menace. Leads to Jail Break!." }

-- Dire Maul
D = "Dire Maul"
q{ id = "dq-dire-lethtendris-h", zone = "Feralas", place = "Camp Mojache", way = { 76, 43 }, name = "Talo Thornhoof", quest = "Lethtendris's Web", dungeon = D, faction = H, level = 54,
  note = "East. Lethtendris's Web from Lethtendris. Reward: Lorespinner; 1g 70s." }
q{ id = "dq-dire-lethtendris-a", zone = "Feralas", place = "Feathermoon Stronghold", way = { 30, 46 }, name = "Latronicus Moonspear", quest = "Lethtendris's Web", dungeon = D, faction = A, level = 54,
  note = "East. Lethtendris's Web from Lethtendris. Reward: Lorespinner; 1g 70s." }
q{ id = "dq-dire-pusillin", zone = "Feralas", place = "Lariss Pavilion", way = { 76, 37 }, name = "Azj'Tordin", quest = "Pusillin and the Elder Azj'Tordin", dungeon = D, level = 54,
  note = "East. Book of Incantations from Pusillin. Reward: Spry Boots or Sprinter's Sword." }
q{ id = "dq-dire-shards-of-felvine", zone = "Moonglade", place = "Nighthaven", way = { 51, 45 }, name = "Rabine Saturna", quest = "Shards of the Felvine", dungeon = D, level = 56,
  note = "East. After A Reliquary of Purity. Felvine Shard. Reward: Milli's Shield or Milli's Lexicon." }
q{ id = "dq-dire-elven-legends-h", zone = "Feralas", place = "Camp Mojache", way = { 74, 43 }, name = "Sage Korolusk", quest = "Elven Legends", dungeon = D, faction = H, level = 54,
  note = "North. Makes you eligible for the Libram of Protection, Rapidity and Focus." }
q{ id = "dq-dire-elven-legends-a", zone = "Feralas", place = "Feathermoon Stronghold", way = { 31, 43 }, name = "Scholar Runethorn", quest = "Elven Legends", dungeon = D, faction = A, level = 54,
  note = "North. Makes you eligible for the Libram of Protection, Rapidity and Focus." }

-- Lower Blackrock Spire
D = "Lower Blackrock Spire"
q{ id = "dq-lbrs-pack-mistress", zone = "Badlands", place = "Kargath", way = { 6, 47 }, name = "Galamav the Marksman", quest = "The Pack Mistress", dungeon = D, faction = H, level = 55,
  note = "Kill Halycon. Reward: Astoria Robes, Traphook Jerkin or Jadescale Breastplate." }
q{ id = "dq-lbrs-operative-bijou", zone = "Badlands", place = "Kargath", way = { 5, 47 }, name = "Lexlort", quest = "Operative Bijou", dungeon = D, faction = H, level = 55,
  note = "Leads to Bijou's Belongings. Reward: Freewind Gloves or Seapost Girdle." }
q{ id = "dq-lbrs-warlords-command", zone = "Badlands", place = "Kargath", way = { 5, 47 }, name = "Warlord Goretooth", quest = "Warlord's Command", dungeon = D, faction = H, level = 55,
  note = "Kill Voone, Omokk, Wyrmthalak + Important Blackrock Documents. Continues to For The Horde! (UBRS)." }
q{ id = "dq-lbrs-en-ay-es-tee-why", zone = "Burning Steppes", place = "Flame Crest", way = { 65, 21 }, name = "Kibler", quest = "En-Ay-Es-Tee-Why", dungeon = D, level = 55,
  note = "15 Spire Spider Egg. Reward: Smolderweb Carrier." }
q{ id = "dq-lbrs-kiblers-exotic-pets", zone = "Burning Steppes", place = "Flame Crest", way = { 65, 21 }, name = "Kibler", quest = "Kibler's Exotic Pets", dungeon = D, level = 55,
  note = "Empty Worg Pup Cage on a living pup with Halycon. Reward: Worg Carrier." }
q{ id = "dq-lbrs-mothers-milk", zone = "Burning Steppes", place = "Flame Crest", way = { 65, 23 }, name = "Ragged John", quest = "Mother's Milk", dungeon = D, level = 55 }
q{ id = "dq-lbrs-final-tablets", zone = "Tanaris", place = "Steamwheedle Port", way = { 66, 24 }, name = "Prospector Ironboot", quest = "The Final Tablets", dungeon = D, level = 40,
  note = "After 5 quests from Screecher Spirits. 7,750 XP." }

-- Upper Blackrock Spire
D = "Upper Blackrock Spire"
q{ id = "dq-ubrs-darkstone-tablet", zone = "Badlands", place = "Kargath", way = { 3, 48 }, name = "Shadowmage Vivian Lagrave", quest = "The Darkstone Tablet", dungeon = D, faction = H, level = 57,
  note = "Optional breadcrumb from Apothecary Zinge, Undercity. Reward: Swiftfoot Treads or Blinkstrike Armguards." }
q{ id = "dq-ubrs-for-the-horde", zone = "Orgrimmar", place = "Valley of Wisdom", way = { 31, 37 }, name = "Thrall", quest = "For The Horde!", dungeon = D, faction = H, level = 55,
  note = "After Warlord's Command, Eitrigg's Wisdom. Head of Rend Blackhand. Reward: Mark of Tyranny, Eye of the Beast or Blackhand's Breadth." }
q{ id = "dq-ubrs-egg-collection", zone = "Burning Steppes", place = "Flame Crest", way = { 65, 23 }, name = "Tinkee Steamboil", quest = "Egg Collection", dungeon = D, level = 57,
  note = "6 prequests from Egg Freezing / Broodling Essence." }
q{ id = "dq-ubrs-eye-of-emberseer", zone = "Azshara", way = { 79, 73 }, name = "Duke Hydraxis", quest = "Eye of the Emberseer", dungeon = D, level = 55,
  note = "After Stormers and Rumblers, Poisoned Water. Eye of the Emberseer from Pyroguard Emberseer." }
q{ id = "dq-ubrs-demon-forge", zone = "Winterspring", place = "SE Winterspring", way = { 63, 73 }, name = "Lorax", quest = "The Demon Forge", dungeon = D, level = 55,
  note = "Blacksmiths only, after Lorax's Tale. Reward: Plans: Demon Forged Breastplate, Potion of Demon Slaying." }
q{ id = "dq-ubrs-doomriggers-clasp", zone = "Burning Steppes", place = "Morgan's Vigil", way = { 84, 69 }, name = "Mayara Brightwing", quest = "Doomrigger's Clasp", dungeon = D, faction = A, level = 57,
  note = "Breadcrumb from Count Remington Ridgewell, Stormwind Keep. Reward: Swiftfoot Treads or Blinkstrike Armguards." }
q{ id = "dq-ubrs-drakkisaths-demise", zone = "Burning Steppes", place = "Morgan's Vigil", way = { 84, 68 }, name = "Marshal Maxwell", quest = "General Drakkisath's Demise", dungeon = D, faction = A, level = 55,
  note = "After General Drakkisath's Command (LBRS drop). Reward: Mark of Tyranny, Eye of the Beast or Blackhand's Breadth." }
q{ id = "dq-ubrs-drakefire-amulet", zone = "Winterspring", place = "Mazthoril", way = { 56, 49 }, name = "Haleh", quest = "Drakefire Amulet", dungeon = D, faction = A, level = 50,
  note = "10 prequests from Dragonkin Menace. Cave entrance /way 57 50; step on the blue rune at the end." }

-- Scholomance
D = "Scholomance"
q{ id = "dq-scholo-barov-fortune-h", zone = "Tirisfal Glades", place = "The Bulwark", way = { 83, 71 }, name = "Alexi Barov", quest = "Barov Family Fortune", dungeon = D, faction = H, level = 52,
  note = "May be dead from the Alliance kill quest (30 min respawn). Four deeds. 1g 80s." }
q{ id = "dq-scholo-barov-fortune-a", zone = "Western Plaguelands", place = "Chillwind Camp", way = { 43, 83 }, name = "Weldon Barov", quest = "Barov Family Fortune", dungeon = D, faction = A, level = 52,
  note = "May be dead from the Horde kill quest (30 min respawn). Four deeds. 1g 80s." }
q{ id = "dq-scholo-darkreaver-menace", zone = "Orgrimmar", place = "Valley of Wisdom", way = { 38, 35 }, name = "Sagorne Creststrider", quest = "The Darkreaver Menace", dungeon = D, faction = H, level = 58,
  note = "Shaman only, after Material Assistance; part of the Skyfury Helm epic." }
q{ id = "dq-scholo-plagued-hatchlings", zone = "Eastern Plaguelands", place = "Light's Hope Chapel", way = { 81, 59 }, name = "Betina Bigglezink", quest = "Plagued Hatchlings", dungeon = D, level = 55,
  note = "Kill 20 Plagued Hatchling (Rattlegore's room). Healthy Dragon Scale drops give Argent Dawn rep." }
q{ id = "dq-scholo-krastinov", zone = "Western Plaguelands", place = "Caer Darrow", way = { 70, 73 }, name = "Eva Sarkhoff", quest = "Doctor Theolen Krastinov, the Butcher", dungeon = D, level = 55,
  note = "Then Krastinov's Bag of Horrors and Kirtonos the Herald (save the Spectral Essence). 3g 96s." }
q{ id = "dq-scholo-dawns-gambit", zone = "Eastern Plaguelands", place = "Light's Hope Chapel", way = { 81, 59 }, name = "Betina Bigglezink", quest = "Dawn's Gambit", dungeon = D, level = 57,
  note = "9 prequests from Broodling Essence." }
q{ id = "dq-scholo-ras-frostwhisper", zone = "Western Plaguelands", place = "Caer Darrow", way = { 70, 74 }, name = "Magistrate Marduke", quest = "The Lich, Ras Frostwhisper", dungeon = D, level = 57,
  note = "Visible only with the Spectral Essence equipped; 8 prequests. Reward: Warblade, Crown of Caer Darrow or Darrowspike." }

-- Stratholme
D = "Stratholme"
q{ id = "dq-strat-ramstein", zone = "Eastern Plaguelands", place = "Marris Stead", way = { 26, 74 }, name = "Nathanos Blightcaller", quest = "Ramstein", dungeon = D, faction = H, level = 56,
  note = "Undead side. 4 prequests. Reward: Royal Seal of Alexis or Elemental Circle; 100 Undercity rep." }
q{ id = "dq-strat-ezra-grimm", zone = "Eastern Plaguelands", place = "Light's Hope Chapel", way = { 80, 58 }, name = "Smokey LaRue", quest = "The Great Ezra Grimm", dungeon = D, level = 55,
  note = "Live side. Reward: Smokey's Lighter." }
q{ id = "dq-strat-archivist", zone = "Eastern Plaguelands", place = "Light's Hope Chapel", way = { 81, 59 }, name = "Duke Nicholas Zverenhoff", quest = "The Archivist", dungeon = D, level = 55,
  note = "Live side; leads to The Truth Comes Crashing Down. 150 Argent Dawn rep." }
q{ id = "dq-strat-restless-souls", zone = "Eastern Plaguelands", place = "Terrordale", way = { 14, 33 }, name = "Egan", quest = "The Restless Souls", dungeon = D, level = 55,
  note = "Live side, has a prequest. Reward: Testament of Hope." }
q{ id = "dq-strat-love-and-family", zone = "Western Plaguelands", place = "Caer Darrow", way = { 65, 75 }, name = "Artist Renfray", quest = "Of Love and Family", dungeon = D, level = 52,
  note = "Live side; 7 prequests. 6,600 XP." }
q{ id = "dq-strat-houses-of-holy", zone = "Eastern Plaguelands", place = "Light's Hope Chapel", way = { 81, 57 }, name = "Leonid Barthalomew the Revered", quest = "Houses of the Holy", dungeon = D, level = 55,
  note = "Undead side. Reward: Crown or Band of the Penitent, plus potions." }
q{ id = "dq-strat-flesh-does-not-lie", zone = "Eastern Plaguelands", place = "Light's Hope Chapel", way = { 81, 59 }, name = "Betina Bigglezink", quest = "The Flesh Does Not Lie", dungeon = D, level = 55,
  note = "Undead side; then The Active Agent (Rune or Seal of the Dawn). 100 Argent Dawn rep." }
q{ id = "dq-strat-above-and-beyond", zone = "Eastern Plaguelands", place = "Light's Hope Chapel", way = { 81, 59 }, name = "Duke Nicholas Zverenhoff", quest = "Above and Beyond", dungeon = D, level = 55,
  note = "Undead side; 2 prequests from The Archivist. 150 Argent Dawn rep." }
q{ id = "dq-strat-menethils-gift", zone = "Eastern Plaguelands", place = "Light's Hope Chapel", way = { 81, 57 }, name = "Leonid Barthalomew the Revered", quest = "Menethil's Gift", dungeon = D, level = 57,
  note = "Undead side; 5 prequests. Reward: Penelope's Rose or Mirah's Song." }
q{ id = "dq-strat-dead-mans-plea", zone = "Eastern Plaguelands", place = "Stratholme main entrance", way = { 30, 16 }, name = "Anthion Harmon", quest = "Dead Man's Plea", dungeon = D, level = 58,
  note = "9 prequests from A Supernatural Device; needs the Extra-Dimensional Ghost Revealer to see him." }

-- Blackmaw Hold (Forever-new, Azshara). All level 55.
D = "Blackmaw Hold"
q{ id = "dq-bmh-blackmaw-pouches", zone = "Azshara", place = "near Ruins of Eldarath", way = { 42.0, 38.8 }, name = "Ekkal", quest = "Blackmaw Pouches", dungeon = D, level = 55,
  note = "Both factions. Ekkal also starts The Legashi Threat." }
q{ id = "dq-bmh-blackmaw-reclamation", zone = "Azshara", place = "Timbermaw Hold", way = { 42.4, 20.2 }, name = "Gatekeeper Rageroar", quest = "Blackmaw Reclamation", dungeon = D, level = 55,
  note = "Needs Neutral with Timbermaw; after The Legashi Threat (Ekkal). Ring choice: Ouroboros Ring, Eagle's Head Signet and more." }
q{ id = "dq-bmh-claws-that-rend", zone = "Azshara", place = "near Ruins of Eldarath", way = { 41.4, 20.0 }, name = "Ogtinc", quest = "Claws That Rend, Tusks that Gore", dungeon = D, level = 55,
  note = "Both factions." }
q{ id = "dq-bmh-blackmaw-magic-a", zone = "Alterac Mountains", place = "Dalaran", way = { 15.6, 73.6 }, name = "Archmage Timear", quest = "Blackmaw Magic", dungeon = D, faction = A, level = 55 }
q{ id = "dq-bmh-roots-of-it-a", zone = "Darnassus", place = "Cenarion Enclave", way = { 35.2, 8.6 }, name = "Mathrengyl Bearwalker", quest = "Get to the Roots of It", dungeon = D, faction = A, level = 55,
  note = "Starts with Icebane Gauntlets (Commander Truesong, Azshara /way 11.8 78.2)." }
q{ id = "dq-bmh-roots-of-it-h", zone = "Thunder Bluff", place = "Elder Rise", way = { 76.0, 30.4 }, name = "Nara Wildmane", quest = "Get to the Roots of It", dungeon = D, faction = H, level = 55,
  note = "Starts with Beneath Nordrassil (Jediga, Azshara /way 22.4 51.4)." }

ns.Data:Register("place", "wowhead-dungeon-quests", quests)

-- Dungeon entrances (OVERVIEW). Only where the page prints a /way.
local entrances = {}
local function e(id, zone, x, y, name, note)
  entrances[#entrances + 1] = { id = id, kind = "dungeon", zone = zone, x = x / 100, y = y / 100, name = name, note = note,
    source = OVERVIEW, verified = false }
end
e("de-ragefire-chasm", "Orgrimmar", 52.0, 49.0, "Ragefire Chasm", "Levels 13-18 (min 10). Cleft of Shadow.")
e("de-wailing-caverns", "The Barrens", 45.5, 35.5, "Wailing Caverns", "Levels 15-25 (min 10).")
e("de-the-deadmines", "Westfall", 42.4, 70.4, "The Deadmines", "Levels 18-23 (min 10). Building in Moonbrook.")
e("de-shadowfang-keep", "Silverpine Forest", 42.6, 66.6, "Shadowfang Keep", "Levels 22-30 (min 14). Above Pyrewood Village.")
e("de-the-stockade", "Stormwind City", 41.0, 57.0, "The Stockade", "Levels 22-30 (min 15). No Horde quests.")
e("de-blackfathom-deeps", "Ashenvale", 13.4, 12.8, "Blackfathom Deeps", "Levels 24-32 (min 15). Zoram Strand.")
e("de-scarlet-monastery", "Tirisfal Glades", 83.5, 32.0, "Scarlet Monastery", "Levels 28-45 (min 21). Wings: Graveyard, Library, Armory, Cathedral.")
e("de-gnomeregan", "Dun Morogh", 30.5, 36.3, "Gnomeregan", "Levels 29-38 (min 19). Horde: Rig Wars chain unlocks a teleporter in Booty Bay.")
e("de-razorfen-kraul", "The Barrens", 42.6, 88.5, "Razorfen Kraul", "Levels 30-40 (min 25).")
e("de-razorfen-downs", "The Barrens", 50.0, 92.0, "Razorfen Downs", "Levels 40-50 (min 35).")
e("de-uldaman", "Badlands", 42.6, 10.8, "Uldaman", "Levels 42-52 (min 30).")
e("de-zulfarrak", "Tanaris", 39.5, 21.3, "Zul'Farrak", "Levels 44-54 (min 39).")
e("de-maraudon", "Desolace", 29.5, 57.8, "Maraudon", "Levels 45-57 (min 30).")
e("de-temple-of-atalhakkar", "Swamp of Sorrows", 69.6, 53.2, "The Temple of Atal'Hakkar", "Levels 50-60 (min 45). Avatar of Hakkar needs Yeh'kinya's Scroll (one player).")
e("de-blackrock-depths", "Searing Gorge", 35.2, 84.2, "Blackrock Depths", "Levels 52-60 (min 48). Inside Blackrock Mountain. Shadowforge Key skips the lower part.")
e("de-lower-blackrock-spire", "Searing Gorge", 35.2, 84.2, "Lower Blackrock Spire", "Levels 55-60 (min 48). Inside Blackrock Mountain.")
e("de-upper-blackrock-spire", "Searing Gorge", 35.2, 84.2, "Upper Blackrock Spire", "Levels 58-60 (min 48). 10 players. Needs the Seal of Ascension.")
e("de-dire-maul", "Feralas", 58.9, 41.5, "Dire Maul", "Levels 58-60 (min 48). Crescent Key (Pusillin, East) opens West and North.")
e("de-scholomance", "Western Plaguelands", 69.8, 76.0, "Scholomance", "Levels 58-60 (min 48). Beneath Caer Darrow; Skeleton Key for the gate.")
e("de-stratholme-live", "Eastern Plaguelands", 30.9, 15.2, "Stratholme", "Levels 58-60 (min 48). Living Side (main gate).")
e("de-stratholme-undead", "Eastern Plaguelands", 48.3, 21.8, "Stratholme", "Levels 58-60 (min 48). Undead Side; Key to the City (Magistrate Barthilas) or go through the Living Side.")
ns.Data:Register("place", "wowhead-dungeon-entrances", entrances)

-- Recommended level ranges, from each dungeon's own overview page. note =
-- where the Dungeons Overview disagrees.
ns.Leveling = ns.Leveling or {}
ns.Leveling.DUNGEON_LEVELS = {
  ["Ragefire Chasm"] = { 13, 18, source = SRC["Ragefire Chasm"] },
  ["Wailing Caverns"] = { 15, 25, source = SRC["Wailing Caverns"] },
  ["The Deadmines"] = { 18, 23, source = SRC["The Deadmines"] },
  ["Shadowfang Keep"] = { 22, 30, source = SRC["Shadowfang Keep"] },
  ["Blackfathom Deeps"] = { 24, 32, source = SRC["Blackfathom Deeps"] },
  ["The Stockade"] = { 24, 30, source = SRC["The Stockade"], note = "Dungeons Overview says 22-30" },
  ["Gnomeregan"] = { 29, 38, source = SRC["Gnomeregan"] },
  ["Razorfen Kraul"] = { 30, 40, source = SRC["Razorfen Kraul"] },
  ["Scarlet Monastery"] = { 26, 45, source = SRC["Scarlet Monastery"], note = "Dungeons Overview says 28-45 (Graveyard 28-38)",
    wings = { { "Graveyard", 26, 36 }, { "Library", 29, 39 }, { "Armory", 32, 42 }, { "Cathedral", 35, 45 } } },
  ["Razorfen Downs"] = { 37, 43, source = SRC["Razorfen Downs"], note = "Dungeons Overview says 40-50" },
  ["Uldaman"] = { 40, 45, source = SRC["Uldaman"], note = "Dungeons Overview says 42-52" },
  ["Zul'Farrak"] = { 44, 54, source = SRC["Zul'Farrak"] },
  ["Maraudon"] = { 45, 52, source = SRC["Maraudon"], note = "Dungeons Overview says 45-57 (Purple 45-53, Orange 45-53, Inner 48-57)" },
  ["The Temple of Atal'Hakkar"] = { 50, 55, source = SRC["The Temple of Atal'Hakkar"], note = "Dungeons Overview says 50-60" },
  ["Blackrock Depths"] = { 52, 60, source = SRC["Blackrock Depths"] },
  ["Lower Blackrock Spire"] = { 55, 60, source = SRC["Lower Blackrock Spire"] },
  ["Upper Blackrock Spire"] = { 55, 60, source = SRC["Upper Blackrock Spire"], note = "Dungeons Overview says 58-60" },
  ["Dire Maul"] = { 52, 60, source = SRC["Dire Maul"], note = "Dungeons Overview says 58-60",
    wings = { { "East", 52, 60 }, { "West", 54, 60 }, { "North", 54, 60 } } },
  ["Scholomance"] = { 55, 60, source = SRC["Scholomance"], note = "Dungeons Overview says 58-60" },
  ["Stratholme"] = { 55, 60, source = SRC["Stratholme"], note = "Dungeons Overview says 58-60",
    wings = { { "Live Side", 55, 60 }, { "Undead Side", 55, 60 } } },
  ["The Hall of Thanes"] = { 13, 18, source = SRC["The Hall of Thanes"] },
  ["Ruins of Lordaeron"] = { 16, 22, source = SRC["Ruins of Lordaeron"], note = "Dungeons Overview says 15-20" },
  ["Excavation Site: Wetlands"] = { 26, 32, source = SRC["Excavation Site: Wetlands"], note = "Dungeons Overview says 24-29" },
  ["City of Dalaran"] = { 28, 34, source = SRC["City of Dalaran"], note = "Dungeons Overview says 28-33" },
  ["Krol'dok Stronghold"] = { 40, 45, source = SRC["Krol'dok Stronghold"] },
  ["Alcaz Prison"] = { 49, 54, source = SRC["Alcaz Prison"], note = "Dungeons Overview says 48-53" },
  ["Blackmaw Hold"] = { 56, 60, source = SRC["Blackmaw Hold"], note = "Dungeons Overview says 55-60" },
  ["The Drowned City"] = { 35, 42, source = SRC["The Drowned City"], note = "Dungeons Overview says 35-40" },
  -- only on the Dungeons Overview (no own page read)
  ["Shaper's Terrace"] = { 58, 60, source = OVERVIEW, note = "New: Un'Goro Crater near Marshal's Refuge (titan facility). No entrance /way." },
}

-- Forever-new unlocks and notable facts without coordinates.
ns.Leveling.DUNGEON_NOTES = {
  { dungeon = "City of Dalaran", source = SRC["City of Dalaran"],
    text = "Secret boss Lyn the Ignored: loot the Black Tome from Archmage Arugal's table in Shadowfang Keep, use it at the Ambermill Leyline Focus (Silverpine) to make the Tome of Dalaran, then use that on the purple rune in the sewer after Atrexis." },
  { dungeon = "Shadowfang Keep", source = SRC["Shadowfang Keep"],
    text = "New in Forever: everyone should loot the Black Tome in Arugal's room; it becomes the Tome of Dalaran at the Ambermill town hall (extra boss in City of Dalaran)." },
  { dungeon = "City of Dalaran", source = SRC["City of Dalaran"],
    text = "Entry needs the Dalaran Sewer Key (keyring); only one player needs it. Horde get it from Magus Wordeen Voidglare's chain at Tarren Mill. Almost every mob is immune to Arcane." },
  { dungeon = "Ruins of Lordaeron", source = SRC["Ruins of Lordaeron"],
    text = "Secret quest Crest of Lordaeron (level 14, both factions): an interactable item with several spawn points inside; return it to Stormwind or Undercity." },
  { dungeon = "Ruins of Lordaeron", source = SRC["Ruins of Lordaeron"],
    text = "Entrance: portal in the Ruins of Lordaeron above the Undercity, from Tirisfal Glades south of Brill. Alliance quests (Captain Truman) are all inside." },
  { dungeon = "The Hall of Thanes", source = SRC["The Hall of Thanes"],
    text = "Entrance: the door to Old Ironforge just left inside the High Seat of Ironforge; follow the path down to the portal. Most quests are Alliance-only." },
  { dungeon = "Krol'dok Stronghold", source = SRC["Krol'dok Stronghold"],
    text = "New in Forever: inside the dungeon you see yourself on the Riverglades map." },
  { dungeon = "The Drowned City", source = SRC["The Drowned City"],
    text = "Long underwater section: bring a Warlock or Shaman for water breathing. Entrance: ocean cave off the Stranglethorn coast, south of the Haunted Isle." },
  { dungeon = "Blackmaw Hold", source = SRC["Blackmaw Hold"],
    text = "Entrance: Azshara, directly west of Timbermaw Hold, through the furbolg tunnel. Very large (Maraudon/BRD size)." },
  { dungeon = "Alcaz Prison", source = SRC["Alcaz Prison"],
    text = "Entrance: portal in the keep's basement on Alcaz Island (NE Dustwallow); enter the island from the west. The Man in the Iron Chains appears only if The Questioner is alive." },
  { dungeon = "Excavation Site: Wetlands", source = SRC["Excavation Site: Wetlands"],
    text = "Entrance at the top of the hill SE of Whelgar's Excavation Site (new roads). Only one graveyard in Wetlands: a wipe is a long run." },
  { dungeon = "The Deadmines", source = SRC["The Deadmines"],
    text = "New in Forever: A Moon-Kissed Blade, the Horde Paladin version of The Test of Righteousness, starts at Bandarion Keep in Tirisfal Glades." },
  { dungeon = "Gnomeregan", source = SRC["Gnomeregan"],
    text = "Horde: Gnomer-gooooone! from Scooty in Booty Bay gives the Goblin Transponder, a teleporter to Gnomeregan. Keep it." },
}
