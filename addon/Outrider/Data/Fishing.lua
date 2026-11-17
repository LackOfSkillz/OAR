-- Data/Fishing.lua
-- Fishing guide data for WoW Forever (Gary, 2026-11-17: "add all the best
-- fishing features and data"). Everything here is verified = false until
-- seen in game; zones and NPCs by NAME (the game turns names into maps and
-- the NPC pack into places at runtime).
-- Sources (read 2026-11-17):
--   WPF = wow-professions.com/forever/fishing-leveling-guide (WoW Forever 1-300:
--         zone tiers incl. Zephras Isle, trainers, supply vendors, Expert book,
--         Nat Pagle, lures)
--   FF  = curseforge.com/wow/addons/forever-fishing (Stranglethorn Fishing
--         Extravaganza runs on Forever)
--   CL  = Classic rule: the Extravaganza is Sundays 14:00-16:00 server time
--         (unverified on Forever; the page says so)
-- What fish bite where is NOT here: no Forever source lists it reliably, so
-- Outrider shows what you've caught in each zone (your catch log) instead.
local _, ns = ...

ns.FishingData = {
  source = "wow-professions.com Forever fishing guide (2026-11-17)",
  verified = false,

  -- skill tiers and where to fish (WPF)
  tiers = {
    { lo = 1, hi = 75, zones = { "Dun Morogh", "Durotar", "Elwynn Forest", "Mulgore", "Teldrassil", "Tirisfal Glades", "Zephras Isle" },
      lure = "Shiny Bauble", note = "Starting zones, not the capitals." },
    { lo = 75, hi = 150, zones = { "Darnassus", "Stormwind City", "Orgrimmar", "Undercity", "Thunder Bluff", "The Barrens", "Darkshore",
      "Ironforge", "Loch Modan", "Silverpine Forest", "Westfall" },
      lure = "Nightcrawlers", note = "Use Nightcrawlers (Fishing 50) if fish keep getting away." },
    { lo = 150, hi = 225, zones = { "Dustwallow Marsh", "Alterac Mountains", "Arathi Highlands", "Desolace", "Stranglethorn Vale",
      "Swamp of Sorrows", "Thousand Needles" },
      lure = "Bright Baubles", note = "Dustwallow Marsh is the main spot; Bright Baubles stop fish escaping there." },
    { lo = 225, hi = 300, zones = { "Felwood", "Feralas", "The Hinterlands", "Tanaris", "Un'Goro Crater", "Western Plaguelands" },
      lure = "Bright Baubles", note = "Bright Baubles stop fish escaping in these zones." },
  },

  -- training milestones (WPF): at max skill `max`, with skill `need` and level `level`
  milestones = {
    { max = 75, need = 50, level = 10, title = "Journeyman Fishing", how = "Any fishing trainer teaches it (Fishing 50, level 10).", npc = nil },
    { max = 150, need = 125, level = 20, title = "Expert Fishing - The Bass and You",
      how = "A book from Old Man Heming in Booty Bay (bottom of the town, by the fishing sign), or the auction house. Buy Bright Baubles there too.",
      npc = "Old Man Heming", zone = "Stranglethorn Vale" },
    { max = 225, need = 225, level = 35, title = "Artisan Fishing: Nat Pagle, Angler Extreme",
      how = "Nat Pagle at Tidefury Cove, Dustwallow Marsh. Catch one of each: Feralas Ahi (Feralas), Misty Reed Mahi Mahi (Swamp of Sorrows), Sar'theris Striker (Desolace), Savage Coast Blue Sailfin (Stranglethorn Vale).",
      npc = "Nat Pagle", zone = "Dustwallow Marsh",
      fish = { "Feralas Ahi", "Misty Reed Mahi Mahi", "Sar'theris Striker", "Savage Coast Blue Sailfin" } },
  },

  -- fishing trainers (WPF): name, zone, where, faction (nil = both)
  trainers = {
    { "Lumak", "Orgrimmar", nil, "Horde" },
    { "Armand Cromwell", "Undercity", nil, "Horde" },
    { "Kah Mistrunner", "Thunder Bluff", nil, "Horde" },
    { "Lau'Tiki", "Durotar", "coast at Sen'jin Village", "Horde" },
    { "Uthan Stillwater", "Mulgore", "Stonebull Lake by Bloodhoof Village", "Horde" },
    { "Clyde Kellen", "Tirisfal Glades", "Brightwater Lake east of Brill", "Horde" },
    { "Katoom the Angler", "The Hinterlands", "Revantusk Village", "Horde" },
    { "Arnold Leland", "Stormwind City", nil, "Alliance" },
    { "Grimnur Stonebrand", "Ironforge", nil, "Alliance" },
    { "Astaia", "Darnassus", nil, "Alliance" },
    { "Lee Brown", "Elwynn Forest", "Crystal Lake east of Goldshire", "Alliance" },
    { "Paxton Ganter", "Dun Morogh", "Iceflow Lake toward Gnomeregan", "Alliance" },
    { "Androl Oakhand", "Teldrassil", "Rut'theran Village dock shore", "Alliance" },
    { "Baelann Swiftcurrent", "Zephras Isle", "Valanaar", nil },
    { "Fenn Fairweather", "Zephras Isle", "Shen'dar Village", nil },
  },

  -- fishing supply vendors: poles and baubles (WPF)
  vendors = {
    { "Zansoa", "Durotar", "Sen'jin Village", "Horde" },
    { "Wunna Darkmane", "Mulgore", "Bloodhoof Village", "Horde" },
    { "Martine Tramblay", "Tirisfal Glades", "Death's Watch Waystation, south-east of Brill", "Horde" },
    { "Shankys", "Orgrimmar", "next to the trainer", "Horde" },
    { "Lizbeth Cromwell", "Undercity", "next to the trainer", "Horde" },
    { "Sewa Mistrunner", "Thunder Bluff", "next to the trainer", "Horde" },
    { "Wik'Tar", "Ashenvale", "Zoram'gar Outpost", "Horde" },
    { "Katoom the Angler", "The Hinterlands", "Revantusk Village", "Horde" },
    { "Tharynn Bouden", "Elwynn Forest", "Goldshire", "Alliance" },
    { "Gretta Ganter", "Dun Morogh", "Iceflow Lake", "Alliance" },
    { "Nessa Shadowsong", "Teldrassil", "Rut'theran Village", "Alliance" },
    { "Catherine Leland", "Stormwind City", "next to the trainer", "Alliance" },
    { "Tansy Puddlefizz", "Ironforge", "next to the trainer", "Alliance" },
    { "Voloren", "Darnassus", "next to the trainer", "Alliance" },
    { "Khara Deepwater", "Loch Modan", "the Loch", "Alliance" },
    { "Stuart Fleming", "Wetlands", "Menethil Harbor", "Alliance" },
    { "Vernon Hale", "Redridge Mountains", "Lake Everstill", "Alliance" },
    { "Lindea Rabonne", "Hillsbrad Foothills", "Southshore", "Alliance" },
    { "Baelann Swiftcurrent", "Zephras Isle", "Valanaar", nil },
    { "Belandiel Farflight", "Zephras Isle", "Shen'dar Village", nil },
    { "Old Man Heming", "Stranglethorn Vale", "Booty Bay, by the fishing sign (Bright Baubles, Expert book)", nil },
  },

  -- lures (WPF): name, the guide's advice
  lures = {
    { "Shiny Bauble", "Starting zones (1-75)." },
    { "Nightcrawlers", "From Fishing 50; use when fish keep getting away (75-150)." },
    { "Bright Baubles", "From 150 on; needed in Dustwallow Marsh, Feralas and the 225-300 zones." },
  },

  -- Stranglethorn Fishing Extravaganza (FF says it runs on Forever; times are the Classic schedule, CL)
  extravaganza = { wday = 1, startHour = 14, endHour = 16, where = "Booty Bay, Stranglethorn Vale", verified = false },
}
