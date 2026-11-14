-- Data/Dungeons.lua
-- Level range, group size and type for each WoW Forever dungeon and raid, by
-- the name the dungeon pack uses (Gary, 2026-11-14: "recommend what dungeons
-- you're ready for"). Source: foreverdb.net/dungeons (read 2026-11-14; beta and
-- first-week data). verified = false until Gary has been inside.
-- Raid release dates are reported, not official: Onyxia, Hyjal Summit and the
-- new Barrow Deeps open first (Dec 9 2026); Molten Core has no date yet.

local _, ns = ...
local SRC = "foreverdb.net"

ns.Data:Register("dungeon", "forever-levels", {
  { name = "The Hall of Thanes", min = 13, max = 20, size = 5, new = true, source = SRC, verified = false },
  { name = "Ragefire Chasm", min = 13, max = 18, size = 5, source = SRC, verified = false },
  { name = "Ruins of Lordaeron", min = 15, max = 22, size = 5, new = true, source = SRC, verified = false },
  { name = "Wailing Caverns", min = 15, max = 24, size = 5, source = SRC, verified = false },
  { name = "The Deadmines", min = 17, max = 26, size = 5, source = SRC, verified = false },
  { name = "Shadowfang Keep", min = 20, max = 30, size = 5, source = SRC, verified = false },
  { name = "Blackfathom Deeps", min = 24, max = 32, size = 5, source = SRC, verified = false },
  { name = "The Stockade", min = 24, max = 32, size = 5, source = SRC, verified = false },
  { name = "Excavation Site: Wetlands", min = 26, max = 33, size = 5, new = true, source = SRC, verified = false },
  { name = "City of Dalaran", min = 28, max = 35, size = 5, new = true, source = SRC, verified = false },
  { name = "Gnomeregan", min = 29, max = 38, size = 5, source = SRC, verified = false },
  { name = "Razorfen Kraul", min = 29, max = 38, size = 5, source = SRC, verified = false },
  { name = "Scarlet Monastery", min = 30, max = 38, size = 5, source = SRC, verified = false },
  { name = "Razorfen Downs", min = 37, max = 46, size = 5, source = SRC, verified = false },
  { name = "Uldaman", min = 41, max = 51, size = 5, source = SRC, verified = false },
  { name = "Zul'Farrak", min = 44, max = 54, size = 5, source = SRC, verified = false },
  { name = "Maraudon", min = 46, max = 55, size = 5, source = SRC, verified = false },
  { name = "The Temple of Atal'Hakkar", min = 50, max = 60, size = 5, source = SRC, verified = false },
  { name = "Blackrock Depths", min = 52, max = 60, size = 5, source = SRC, verified = false },
  { name = "Dire Maul", min = 54, max = 60, size = 5, source = SRC, verified = false },
  { name = "Blackrock Spire", min = 55, max = 60, size = 5, source = SRC, verified = false },
  { name = "Scholomance", min = 58, max = 60, size = 5, source = SRC, verified = false },
  { name = "Stratholme", min = 58, max = 60, size = 5, source = SRC, verified = false },
  { name = "Zul'Gurub", min = 60, max = 60, size = 20, raid = true, source = SRC, verified = false },
  { name = "Ruins of Ahn'Qiraj", min = 60, max = 60, size = 20, raid = true, source = SRC, verified = false },
  { name = "Onyxia's Lair", min = 60, max = 60, size = 40, raid = true, source = SRC, verified = false },
  { name = "Molten Core", min = 60, max = 60, size = 40, raid = true, source = SRC, verified = false },
  { name = "Blackwing Lair", min = 60, max = 60, size = 40, raid = true, source = SRC, verified = false },
  { name = "Temple of Ahn'Qiraj", min = 60, max = 60, size = 40, raid = true, source = SRC, verified = false },
  { name = "Naxxramas", min = 60, max = 60, size = 40, raid = true, source = SRC, verified = false },
})
