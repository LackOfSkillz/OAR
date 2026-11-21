-- Data/Dungeons.lua
-- Level range, group size and type for each WoW Forever dungeon and raid, by
-- the name the dungeon pack uses (Gary, 2026-11-14: "recommend what dungeons
-- you're ready for"). Source: foreverdb.net/dungeons (read 2026-11-14; beta and
-- first-week data). verified = false until Gary has been inside.
-- Raid release dates are reported, not official: Onyxia, Hyjal Summit and the
-- new Barrow Deeps open first (Dec 9 2026); Molten Core has no date yet.

local _, ns = ...
local SRC = "foreverdb.net"
-- 2026-11-21 (Gary: match Wowhead): 5-player ranges from Wowhead's Forever
-- dungeon guides (each dungeon's own page; Data/Leveling_DungeonQuests.lua has
-- the details and where the Dungeons Overview differs); was = the old range.
local WHD = "wowhead.com Forever dungeon guides (read 2026-11-21)"

ns.Data:Register("dungeon", "forever-levels", {
  { name = "The Hall of Thanes", min = 13, max = 18, was = "foreverdb 13-20", size = 5, new = true, source = WHD, verified = false },
  { name = "Ragefire Chasm", min = 13, max = 18, size = 5, source = WHD, verified = false },
  { name = "Ruins of Lordaeron", min = 16, max = 22, was = "foreverdb 15-22", size = 5, new = true, source = WHD, verified = false },
  { name = "Wailing Caverns", min = 15, max = 25, was = "foreverdb 15-24", size = 5, source = WHD, verified = false },
  { name = "The Deadmines", min = 18, max = 23, was = "foreverdb 17-26", size = 5, source = WHD, verified = false },
  { name = "Shadowfang Keep", min = 22, max = 30, was = "foreverdb 20-30", size = 5, source = WHD, verified = false },
  { name = "Blackfathom Deeps", min = 24, max = 32, size = 5, source = WHD, verified = false },
  { name = "The Stockade", min = 24, max = 30, was = "foreverdb 24-32", size = 5, source = WHD, verified = false },
  { name = "Excavation Site: Wetlands", min = 26, max = 32, was = "foreverdb 26-33", size = 5, new = true, source = WHD, verified = false },
  { name = "City of Dalaran", min = 28, max = 34, was = "foreverdb 28-35", size = 5, new = true, source = WHD, verified = false },
  { name = "Gnomeregan", min = 29, max = 38, size = 5, source = WHD, verified = false },
  { name = "Razorfen Kraul", min = 30, max = 40, was = "foreverdb 29-38", size = 5, source = WHD, verified = false },
  { name = "Scarlet Monastery", min = 26, max = 45, was = "foreverdb 30-38", size = 5, source = WHD, verified = false },
  { name = "Razorfen Downs", min = 37, max = 43, was = "foreverdb 37-46", size = 5, source = WHD, verified = false },
  { name = "Uldaman", min = 40, max = 45, was = "foreverdb 41-51", size = 5, source = WHD, verified = false },
  { name = "Zul'Farrak", min = 44, max = 54, size = 5, source = WHD, verified = false },
  { name = "Maraudon", min = 45, max = 52, was = "foreverdb 46-55", size = 5, source = WHD, verified = false },
  { name = "The Temple of Atal'Hakkar", min = 50, max = 55, was = "foreverdb 50-60", size = 5, source = WHD, verified = false },
  { name = "Blackrock Depths", min = 52, max = 60, size = 5, source = WHD, verified = false },
  { name = "Dire Maul", min = 52, max = 60, was = "foreverdb 54-60", size = 5, source = WHD, verified = false },
  { name = "Blackrock Spire", min = 55, max = 60, size = 5, source = WHD, verified = false },
  { name = "Scholomance", min = 55, max = 60, was = "foreverdb 58-60", size = 5, source = WHD, verified = false },
  { name = "Stratholme", min = 55, max = 60, was = "foreverdb 58-60", size = 5, source = WHD, verified = false },
  -- new on Forever, from Wowhead's dungeon guides (2026-11-21)
  { name = "The Drowned City", min = 35, max = 42, size = 5, new = true, source = WHD, verified = false },
  { name = "Krol'dok Stronghold", min = 40, max = 45, size = 5, new = true, source = WHD, verified = false },
  { name = "Alcaz Prison", min = 49, max = 54, size = 5, new = true, source = WHD, verified = false },
  { name = "Blackmaw Hold", min = 56, max = 60, size = 5, new = true, source = WHD, verified = false },
  { name = "Shaper's Terrace", min = 58, max = 60, size = 5, new = true, source = WHD, verified = false },
  { name = "Zul'Gurub", min = 60, max = 60, size = 20, raid = true, source = SRC, verified = false },
  { name = "Ruins of Ahn'Qiraj", min = 60, max = 60, size = 20, raid = true, source = SRC, verified = false },
  { name = "Onyxia's Lair", min = 60, max = 60, size = 40, raid = true, source = SRC, verified = false },
  { name = "Molten Core", min = 60, max = 60, size = 40, raid = true, source = SRC, verified = false },
  { name = "Blackwing Lair", min = 60, max = 60, size = 40, raid = true, source = SRC, verified = false },
  { name = "Temple of Ahn'Qiraj", min = 60, max = 60, size = 40, raid = true, source = SRC, verified = false },
  { name = "Naxxramas", min = 60, max = 60, size = 40, raid = true, source = SRC, verified = false },
})
