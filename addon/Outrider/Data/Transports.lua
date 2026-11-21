-- Data/Transports.lua
-- Boats, zeppelins, skycutters, trams and fixed portals on WoW Forever, from
-- community guides (Gary chose "guides + learn", 2026-11-13). Zones by NAME;
-- the game turns names into map IDs at runtime (no IDs typed in by hand).
-- Dock coordinates only where a guide states them; otherwise the zone is
-- known but not the dock, and Outrider learns the exact spot the first time
-- Gary takes that ride (Travel module). Ride times are estimates.
-- Everything verified = false. Routes run both ways unless oneWay = true.
-- Sources (read 2026-11-13):
--   CWF = classicwowforever.com/boats-and-zeppelins/
--   LEP = leprestore.com/guides/world-of-warcraft-forever/wow-forever-travel-guide/ (pre-launch, beta data)
--   MGG = method.gg/wow-forever/all-travel-routes-in-wow-forever-boats-zeppelins (read 2026-11-16)
-- Captured: the Dalaran portal's spot is where Gary stepped through it
-- (a learned ride in his saved data, 2026-11-13).
-- At launch Blizzard put temporary portals by most docks while ships were
-- lost in the Maelstrom; guides disagree on whether they are gone. Either
-- way the dock is the place to go.

local _, ns = ...
local CWF, LEP, BOTH = "classicwowforever.com", "leprestore.com (beta data)", "classicwowforever.com, leprestore.com"
local MGG = "method.gg (read 2026-11-16)"
local WH = "wowhead.com Forever zone guides (read 2026-11-21)"
-- Zeppelin masters and shipmasters stand on the towers and docks: their spots
-- come from QuestieDB's Forever NPC data (read 2026-11-21) and "npc" lets
-- Outrider's own sighting of that NPC move the spot (Gary, 2026-11-21: the
-- arrow sent him to the middle of Durotar for the Undercity zeppelin).
local QDB = "QuestieDB Forever NPC spawns (read 2026-11-21)"

ns.Data:Register("link", "forever-guides", {
  { id = "boat-stormwind-auberdine", kind = "boat", faction = "Alliance", source = BOTH, verified = false,
    from = { zone = "Stormwind City", place = "Stormwind Harbor" }, to = { zone = "Darkshore", place = "Auberdine" } },
  { id = "boat-auberdine-ruttheran", kind = "boat", faction = "Alliance", source = BOTH, verified = false,
    from = { zone = "Darkshore", place = "Auberdine" }, to = { zone = "Teldrassil", place = "Rut'theran Village" } },
  { id = "boat-menethil-southshore", kind = "boat", faction = "Alliance", source = BOTH, verified = false,
    from = { zone = "Wetlands", place = "Menethil Harbor" }, to = { zone = "Hillsbrad Foothills", place = "Southshore" } },
  { id = "boat-southshore-auberdine", kind = "boat", faction = "Alliance", source = CWF, verified = false,
    from = { zone = "Hillsbrad Foothills", place = "Southshore" }, to = { zone = "Darkshore", place = "Auberdine" } },
  { id = "boat-auberdine-menethil", kind = "boat", faction = "Alliance", source = CWF, verified = false,
    from = { zone = "Darkshore", place = "Auberdine" }, to = { zone = "Wetlands", place = "Menethil Harbor" } },
  { id = "boat-menethil-theramore", kind = "boat", faction = "Alliance", source = BOTH, verified = false,
    from = { zone = "Wetlands", place = "Menethil Harbor" }, to = { zone = "Dustwallow Marsh", place = "Theramore" } },
  { id = "boat-steamwheedle-powderfuse", kind = "boat", source = BOTH .. "; docks: " .. WH, verified = false,
    from = { zone = "Tanaris", place = "Steamwheedle Port, east of Gadgetzan", x = 0.686, y = 0.230 },
    to = { zone = "Riverglades", place = "Powderfuse Port", x = 0.806, y = 0.546 } },
  { id = "boat-ratchet-bootybay", kind = "boat", source = BOTH .. "; docks: " .. QDB, verified = false,
    from = { zone = "The Barrens", place = "Ratchet", npc = 9558, x = 0.6354, y = 0.3861 },
    to = { zone = "Stranglethorn Vale", place = "Booty Bay", npc = 9559, x = 0.2608, y = 0.7335 } },
  { id = "zep-org-undercity", kind = "zeppelin", faction = "Horde", source = BOTH .. "; towers: " .. QDB, verified = false,
    from = { zone = "Durotar", place = "zeppelin towers outside Orgrimmar (Frezza)", npc = 9564, x = 0.5082, y = 0.1354 },
    to = { zone = "Tirisfal Glades", place = "tower outside Undercity (Zapetta)", npc = 9566, x = 0.6074, y = 0.5887 } },
  { id = "zep-org-gromgol", kind = "zeppelin", faction = "Horde", source = BOTH .. "; towers: " .. QDB, verified = false,
    from = { zone = "Durotar", place = "zeppelin towers outside Orgrimmar (Snurk Bucksquick)", npc = 12136, x = 0.5069, y = 0.1289 },
    to = { zone = "Stranglethorn Vale", place = "Grom'gol (Nez'raz)", npc = 3149, x = 0.3143, y = 0.2991 } },
  { id = "zep-undercity-gromgol", kind = "zeppelin", faction = "Horde", source = BOTH .. "; towers: " .. QDB, verified = false,
    from = { zone = "Tirisfal Glades", place = "tower outside Undercity (Hin Denburg)", npc = 3150, x = 0.6178, y = 0.5918 },
    to = { zone = "Stranglethorn Vale", place = "Grom'gol (Squibby Overspeck)", npc = 12137, x = 0.3154, y = 0.2936 } },
  -- Wowhead (2026-11-21): two skyboats about every 5 minutes; either faction
  -- may ride either (Dalaran is meant for Alliance, Thunder Bluff for Horde).
  -- Docks: Thunder Bluff boat at Valanaar's westernmost dock, Dalaran boat at
  -- the easternmost one (was 66.6, 79.9 from older guides).
  { id = "zep-skywatcher-valanaar", kind = "skycutter", source = BOTH .. "; docks: " .. WH, verified = false,
    from = { zone = "Mulgore", place = "cliffs south of Skywatcher Plateau", x = 0.343, y = 0.258 },
    to = { zone = "Zephras Isle", place = "Valanaar, westernmost dock", x = 0.579, y = 0.809 },
    note = "Meant for Horde, either faction may ride; The Earthen Ring quest" },
  { id = "sky-valanaar-dalaran", kind = "skycutter", source = BOTH .. "; docks: " .. WH, verified = false,
    from = { zone = "Zephras Isle", place = "Valanaar, easternmost dock", x = 0.659, y = 0.835 },
    to = { zone = "Alterac Mountains", place = "Dalaran, north side", x = 0.125, y = 0.518 },
    note = "Meant for Alliance, either faction may ride; first ride comes with the quest The Magical City of Dalaran" },
  { id = "tram-ironforge-stormwind", kind = "tram", faction = "Alliance", source = CWF, verified = false, ride = 60,
    from = { zone = "Ironforge", place = "Tinker Town" }, to = { zone = "Stormwind City", place = "Dwarven District" } },
  { id = "boat-feathermoon-coast", kind = "boat", faction = "Alliance", source = MGG, verified = false,
    from = { zone = "Feralas", place = "Feathermoon Stronghold" }, to = { zone = "Feralas", place = "the Forgotten Coast" } },
  -- Skyborne only and one way: guides say the way back went on 2026-10-17
  -- (method.gg, blizzardwatch.com). The spot is Gary's own ride.
  { id = "portal-dalaran-stormwind", kind = "portal", faction = "Alliance", race = "Skyborne", oneWay = true, ride = 10,
    source = MGG .. "; spot captured 2026-11-13", verified = false,
    from = { zone = "Alterac Mountains", place = "Dalaran", x = 0.120, y = 0.564 }, to = { zone = "Stormwind City", place = "Stormwind" },
    note = "Skyborne only; no portal back" },
  { id = "portal-ruttheran-darnassus", kind = "portal", faction = "Alliance", source = LEP, verified = false, ride = 10,
    from = { zone = "Teldrassil", place = "Rut'theran Village" }, to = { zone = "Darnassus", place = "Darnassus" } },
})
