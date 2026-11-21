-- Data/Leveling.lua
-- Outrider's leveling knowledge base (Gary, 2026-11-21: "make sure all our
-- leveling guidance matches ... add it to our leveling knowledge base").
-- Source: Wowhead's WoW Forever leveling guides (wowhead.com/forever/guides/leveling,
-- read in the browser 2026-11-21):
--   ZONES = Forever Zones Overview (Serenal, updated 2026-09-17)
--   RIVER = Riverglades Zone Overview (Nodge, updated 2026-11-19)
--   ZEPH  = Zephras Isle Zone Overview (Nodge, updated 2026-10-22)
--   COZY  = Cozy Sleeping Bag guide (Serenal, updated 2026-11-19)
-- Hard rule 7: copied as written, coordinates divided by 100, verified =
-- false until Gary has seen them in game. Zones by NAME (the game turns names
-- into map IDs). What Gary's own characters see always wins: a place he
-- recorded beats a guide place, creatures he met beat a guide's level range.

local _, ns = ...
local ZONES = "wowhead.com Forever Zones Overview (read 2026-11-21)"
local RIVER = "wowhead.com Riverglades Zone Overview (read 2026-11-21)"
local ZEPH = "wowhead.com Zephras Isle Zone Overview (read 2026-11-21)"
local COZY = "wowhead.com Cozy Sleeping Bag guide (read 2026-11-21)"

-- Zone level ranges and what each zone is for. lo/hi only where the guide states them.
ns.Data:Register("zoneguide", "wowhead-forever", {
  { name = "Zephras Isle", lo = 1, hi = 12, new = true, source = ZEPH, verified = false,
    note = "Skyborne starting zone; choose Horde or Alliance at level 1. Skyboats from Valanaar to Dalaran and to north of Thunder Bluff, every ~5 min, either faction may ride either." },
  { name = "Riverglades", lo = 36, hi = 44, new = true, contested = true, source = RIVER, verified = false,
    note = "Contested frontier east of Redridge, Burning Steppes and Badlands. Alliance hub Farholde Keep (south), Horde hub Rog'mar (centre), goblin town Powderfuse Port (east coast). Dungeon: Krol'dok Stronghold. Reach it on foot from northern Redridge or southern Badlands, or by boat from Steamwheedle Port (Tanaris)." },
  { name = "Mount Hyjal", lo = 60, hi = 60, new = true, source = ZONES, verified = false,
    note = "Level 60 zone after Archimonde's defeat; home of the 20-player raid Hyjal Summit." },
  { name = "Shen'Dralas", new = true, source = ZONES, verified = false,
    note = "New zone between Mulgore and Desolace (the Shen'dralar of Dire Maul, the centaur war). Its quests send you to Razorfen Downs and Maraudon. No level range given." },
})

-- Places from the guides: trainers, flight masters, quest starts, dungeon
-- entrances, chain steps. kind follows POICapture's kinds where one fits.
local places = {}
local function add(t) t.verified = false places[#places + 1] = t end

-- Zephras Isle class trainers: three per Skyborne class (ZEPH)
local CLASS_TRAINERS = {
  Druid   = { { "Xyton Silverwind", "Thendall Village", 41.6, 23.4, true }, { "Naeluna Swiftmend", "Shen'dar Village", 45.2, 44.2 }, { "Lotheluum Starbreeze", "Valanaar", 64.0, 75.0 } },
  Hunter  = { { "Tai'ree Farsight", "Thendall Village", 42.4, 23.6, true }, { "Elayaa Easewind", "Shen'dar Village", 45.2, 44.2 }, { "Quel'ana Quickgale", "Valanaar", 59.6, 72.6 } },
  Mage    = { { "Dorii Brightwhisper", "Thendall Village", 41.6, 23.6, true }, { "Shenaan Spellwind", "Shen'dar Village", 45.0, 45.8 }, { "Anathamaas Aetherwind", "Valanaar", 65.8, 80.4 } },
  Rogue   = { { "Akeri Duskblade", "Thendall Village", 43.6, 24.2, true }, { "Miriaan Mistblade", "Shen'dar Village", 43.2, 43.2 }, { "Eltheen Nightbreeze", "Valanaar", 59.8, 72.6 } },
  Shaman  = { { "Windshaper Boro", "Thendall Village", 42.8, 23.6, true }, { "Aarnor Galestrike", "Shen'dar Village", 43.6, 44.8 }, { "Sessaria Skystride", "Valanaar", 58.2, 78.6 } },
  Warrior = { { "Blademaster Ren", "Thendall Village", 43.6, 24.2, true }, { "Corsan Earthrazer", "Shen'dar Village", 44.8, 45.2 }, { "Seena Skybreaker", "Valanaar", 59.8, 72.8 } },
}
for cls, list in pairs(CLASS_TRAINERS) do
  for _, t in ipairs(list) do
    add({ id = "zeph-" .. t[1]:lower():gsub("[^%a]", ""), kind = "trainer", zone = "Zephras Isle", place = t[2], x = t[3] / 100, y = t[4] / 100,
      name = t[1], title = cls .. " Trainer", note = t[5] and "teaches up to level 6" or nil, source = ZEPH })
  end
end
-- Zephras Isle profession trainers (ZEPH). journeyman = teaches up to 150, the rest up to 75.
local PROF_TRAINERS = {
  { "Nyassa Swiftdraught", "Alchemy", "Shen'dar Village", 43.8, 43.6 }, { "Iaadaria Bitterwind", "Alchemy", "Valanaar", 66.2, 79.6 },
  { "Valiena Swiftgale", "Alchemy", "Valanaar", 59.2, 76.2 }, { "Aedi Thriceforged", "Blacksmithing", "Shen'dar Village", 44.8, 44.4 },
  { "Daeann Steelwind", "Blacksmithing", "Valanaar", 65.4, 80.2, true }, { "Nasalanna Windsinger", "Enchanting", "Shen'dar Village", 43.2, 43.2 },
  { "Eaysaa Brightgust", "Enchanting", "Valanaar", 59.2, 76.2 }, { "Strange Hermit", "Engineering", "Shadowgale Forest", 54.0, 39.0 },
  { "Indari Sunseam", "Leatherworking", "Shen'dar Village", 44.6, 44.6 }, { "Emerii Tallgust", "Leatherworking", "Valanaar", 63.8, 80.6, true },
  { "Taleen Shimmerthread", "Tailoring", "Shen'dar Village", 44.8, 44.2, true }, { "Othesia Evengale", "Tailoring", "Valanaar", 64.4, 81.0, true },
  { "Halassa Fernbreeze", "Herbalism", "Shen'dar Village", 43.0, 43.6 }, { "Syriel Nightrain", "Herbalism", "Valanaar", 57.8, 75.4 },
  { "Messana Crestwind", "Mining", "Shen'dar Village", 44.8, 44.4 }, { "Halavuul Cragwind", "Mining", "Valanaar", 65.4, 80.4 },
  { "Mendalass Tattermend", "Skinning", "Shen'dar Village", 43.2, 43.6 }, { "Ishlee Breezewhisper", "Skinning", "Valanaar", 59.6, 76.0 },
  { "Zerril Softbreeze", "Cooking", "Shen'dar Village", 43.8, 43.8 }, { "Nyalah Brightfire", "Cooking", "Valanaar", 60.6, 72.6 },
  { "Naleeia Tattermend", "First Aid", "Shen'dar Village", 43.0, 46.2 }, { "Melasa Fairmend", "First Aid", "Valanaar", 63.0, 72.6 },
  { "Fenn Fairweather", "Fishing", "Shen'dar Village", 45.0, 48.4 }, { "Baelann Swiftcurrent", "Fishing", "Valanaar", 63.2, 75.6 },
}
local PRIMARY = { Alchemy = true, Blacksmithing = true, Enchanting = true, Engineering = true, Leatherworking = true, Tailoring = true }
for _, t in ipairs(PROF_TRAINERS) do
  add({ id = "zeph-" .. t[1]:lower():gsub("[^%a]", ""), kind = "trainer", zone = "Zephras Isle", place = t[3], x = t[4] / 100, y = t[5] / 100,
    name = t[1], title = t[2] .. " Trainer",
    note = PRIMARY[t[2]] and (t[6] and "teaches up to Journeyman (150)" or "teaches up to Apprentice (75)") or nil, source = ZEPH })
end

-- Riverglades (RIVER)
add({ id = "river-fm-gretchen", kind = "flight_master", zone = "Riverglades", place = "Farholde Keep", x = 0.606, y = 0.816,
  name = "Gretchen Mayberry", title = "Flight Master", faction = "Alliance", source = RIVER })
add({ id = "river-fm-grakna", kind = "flight_master", zone = "Riverglades", place = "Rog'mar", x = 0.596, y = 0.450,
  name = "Grakna", title = "Flight Master", faction = "Horde", source = RIVER })
add({ id = "river-bloodring", kind = "quest_hub", zone = "Riverglades", x = 0.656, y = 0.214, name = "Blood Master's Ring",
  note = "Ring of Blood-style chain: each quest gives about a dungeon quest's XP; pay to enter; a ring at the end. Skip it on a PvP server if you'd rather.",
  source = RIVER })
add({ id = "river-kroldok", kind = "dungeon", zone = "Riverglades", x = 0.375, y = 0.375, name = "Krol'dok Stronghold",
  note = "Dungeon entrance on the hills northeast of Twilight's Shroud. Level range not given.", source = RIVER })
-- breadcrumb quests that lead to Riverglades: { quest, giver, zone, place, x, y, faction }
local CRUMBS = {
  { "Twice Misplaced Trust", "Wharfmaster Lozgil", "Stranglethorn Vale", "Booty Bay", 26.4, 73.6 },
  { "Overseas Delivery", "Innkeeper Fizzgrimble", "Tanaris", "Gadgetzan", 52.6, 28.0 },
  { "The Riverglades Report", "Captain Nials", "Arathi Highlands", "Refuge Point", 45.8, 47.6, "Alliance" },
  { "Lost Shipping Crate", "Lost Shipping Crate", "Desolace", "Nijel's Point", 64.7, 10.5, "Alliance" },
  { "Lost Shipping Crate", "Lost Shipping Crate", "Stranglethorn Vale", "border with Duskwood", 38.0, 3.0, "Alliance" },
  { "Deliver the Second Shipment", "Watcher Biggs", "Swamp of Sorrows", "west of Stonard", 26.8, 59.6, "Alliance" },
  { "Finding Tan'jani", "Tor'gan", "Arathi Highlands", "Hammerfall", 74.6, 36.6, "Horde" },
  { "Lost Shipping Crate", "Lost Shipping Crate", "Desolace", "Shadowprey Village", 23.5, 72.5, "Horde" },
  { "Report to Rog'mar", "Commander Aggro'gosh", "Stranglethorn Vale", "Grom'gol Base Camp", 32.2, 28.8, "Horde" },
  { "Lost Shipping Crate", "Lost Shipping Crate", "Thousand Needles", "Freewind Post", 45.3, 49.2, "Horde" },
}
for i, c in ipairs(CRUMBS) do
  add({ id = "river-crumb-" .. i, kind = "quest_start", zone = c[3], place = c[4], x = c[5] / 100, y = c[6] / 100,
    name = c[2], quest = c[1], faction = c[7], note = "Breadcrumb to Riverglades (levels 36-44): " .. c[1], source = RIVER })
end

-- Cozy Sleeping Bag chain (COZY): level 14+. Alliance starts in Westfall,
-- Horde in The Barrens (the same first two steps, reverse order).
-- step = order after the two start steps; start = which faction does it first.
local CZ = {
  { "cozy-westfall", "Westfall", "Alexston Farmstead", 37.0, 50.0, "Burned-Out Remains", "Click the Burned-Out Remains in the cart wreckage: ...and that note you found", "Alliance" },
  { "cozy-barrens", "The Barrens", "south of Camp Taurajo", 46.0, 74.0, "Burned-Out Remains", "Click the Burned-Out Remains in the burnt tower: ...and that note you found", "Horde" },
  { "cozy-stonetalon-path", "Stonetalon Mountains", "northeast of Sun Rock Retreat", 50.9, 52.3, "Path", "Take the path up to the abandoned camp" },
  { "cozy-stonetalon-camp", "Stonetalon Mountains", "abandoned camp", 40.6, 52.4, "Pocket Litter", "Click the Pocket Litter on the box: finishes Stepping Stones, gives Scramble (optional: Rekindle at the campfire)" },
  { "cozy-stonetalon-mound", "Stonetalon Mountains", "hill north of the camp", 39.6, 49.8, "Mound of Dirt", "Jump across to the Mound of Dirt: finishes Scramble, gives Wet Job" },
  { "cozy-lochmodan", "Loch Modan", "Loch Modan Dam", 49.4, 12.9, "Eagle Figurine", "Jump onto the carved heads facing the Wetlands: finishes Wet Job, gives Eagle's Fist" },
  { "cozy-thoradin", "Hillsbrad Foothills", "Thoradin's Wall", 87.3, 49.6, "Messenger Bag", "Climb the cart into the wall, take the hanging Messenger Bag, then the Hastily Rolled-Up Satchel: Cozy Sleeping Bag" },
}
for i, c in ipairs(CZ) do
  add({ id = c[1], kind = "chain", chain = "cozy", step = i, zone = c[2], place = c[3], x = c[4] / 100, y = c[5] / 100,
    name = c[6], note = c[7], start = c[8], source = COZY })
end

ns.Data:Register("place", "wowhead-forever", places)

-- The Cozy Sleeping Bag, what it does (COZY)
ns.Leveling = ns.Leveling or {}
ns.Leveling.COZY = {
  level = 14, source = COZY,
  what = "Lie in it: +1% experience for every minute lying down, up to 3%, for one hour, and you become rested.",
  extra = "The chain gives generous XP at each step and Student Fodder x5 (restores health in Forever).",
}
