-- Data/Herbs.lua
-- Where each herb grows on WoW Forever and the Herbalism skill it needs,
-- from community guides (zone hints chosen over coordinates, 2026-11-12). Guide facts in
-- our own words; no coordinates (Forever redrew the zones, hard rule 7).
-- skill only where a guide states it. Everything verified = false until Gary
-- picks one in game.
-- Sources (read 2026-11-12):
--   WP = wow-professions.com/forever/herbalism-leveling-guide (made from beta clients)
--   WT = warcrafttavern.com/forever/guides/herbalism/

local _, ns = ...
local WP, WT, BOTH = "wow-professions.com (Forever beta)", "warcrafttavern.com", "wow-professions.com, warcrafttavern.com"
local START = { "Durotar", "Mulgore", "Tirisfal Glades", "Zephras Isle", "Elwynn Forest", "Dun Morogh", "Teldrassil" }

ns.Data:Register("herb", "forever-guides", {
  { name = "Peacebloom", source = BOTH, verified = false, zones = START },
  { name = "Silverleaf", source = BOTH, verified = false, zones = START },
  { name = "Earthroot", skill = 15, source = BOTH, verified = false, zones = START, note = "on ledges and by hills" },
  { name = "Mageroyal", source = BOTH, verified = false, zones = { "Silverpine Forest", "Loch Modan", "Darkshore", "The Barrens" } },
  { name = "Briarthorn", source = BOTH, verified = false, zones = { "Silverpine Forest", "Loch Modan", "Darkshore", "The Barrens" } },
  { name = "Stranglekelp", skill = 85, source = BOTH, verified = false, note = "underwater only",
    zones = { "Silverpine Forest", "Loch Modan", "Darkshore", "Hillsbrad Foothills", "Stonetalon Mountains", "The Barrens" } },
  { name = "Bruiseweed", source = BOTH, verified = false, zones = { "Hillsbrad Foothills", "Stonetalon Mountains", "Wetlands" } },
  { name = "Wild Steelbloom", source = BOTH, verified = false, zones = { "Hillsbrad Foothills", "Stonetalon Mountains", "Wetlands" } },
  { name = "Grave Moss", source = WT, verified = false, zones = { "Raven Hill Cemetery", "Scarlet Monastery graveyard" }, note = "near graves" },
  { name = "Kingsblood", skill = 125, source = BOTH, verified = false,
    zones = { "Hillsbrad Foothills", "Stonetalon Mountains", "Stranglethorn Vale", "Arathi Highlands" } },
  { name = "Liferoot", source = BOTH, verified = false,
    zones = { "Hillsbrad Foothills", "Stonetalon Mountains", "Stranglethorn Vale", "Arathi Highlands" } },
  { name = "Fadeleaf", source = BOTH, verified = false, zones = { "Stranglethorn Vale", "Arathi Highlands" } },
  { name = "Goldthorn", source = BOTH, verified = false, zones = { "Stranglethorn Vale", "Arathi Highlands" } },
  { name = "Khadgar's Whisker", skill = 185, source = BOTH, verified = false, zones = { "Stranglethorn Vale", "Arathi Highlands" } },
  { name = "Purple Lotus", source = BOTH, verified = false, zones = { "Tanaris", "Searing Gorge", "The Hinterlands" } },
  { name = "Firebloom", source = BOTH, verified = false, zones = { "Tanaris", "Searing Gorge" } },
  { name = "Sungrass", source = BOTH, verified = false, zones = { "The Hinterlands", "Felwood", "Un'Goro Crater" } },
  { name = "Ghost Mushroom", skill = 245, source = BOTH, verified = false, zones = { "The Hinterlands" }, note = "in caves" },
  { name = "Golden Sansam", source = BOTH, verified = false, zones = { "The Hinterlands", "Felwood", "Un'Goro Crater" } },
  { name = "Gromsblood", source = BOTH, verified = false, zones = { "Felwood", "Un'Goro Crater" } },
  { name = "Dreamfoil", source = BOTH, verified = false, zones = { "Felwood", "Un'Goro Crater" } },
  { name = "Mountain Silversage", source = BOTH, verified = false, zones = { "Felwood", "Un'Goro Crater" } },
  { name = "Plaguebloom", source = BOTH, verified = false, zones = { "Felwood", "Un'Goro Crater" } },
  { name = "Icecap", source = WT, verified = false, zones = { "Felwood", "Un'Goro Crater" }, note = "guide suggestion for 50-60" },
  { name = "Black Lotus", source = WT, verified = false, zones = { "Felwood", "Un'Goro Crater" }, note = "guide suggestion for 50-60" },
  -- new on Forever: named by the guide, zones not documented yet
  { name = "Marefoil", source = WT, verified = false, zones = {}, note = "new on Forever" },
  { name = "Demonsage", source = WT, verified = false, zones = {}, note = "new on Forever" },
  { name = "Death Lotus", source = WT, verified = false, zones = {}, note = "new on Forever" },
  { name = "Frilled Lichen", source = WT, verified = false, zones = {}, note = "new on Forever" },
  { name = "Rosecap", source = WT, verified = false, zones = {}, note = "new on Forever" },
  { name = "Stranglevine", source = WT, verified = false, zones = {}, note = "new on Forever" },
})
