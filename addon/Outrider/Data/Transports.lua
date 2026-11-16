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
  { id = "boat-steamwheedle-powderfuse", kind = "boat", source = BOTH, verified = false,
    from = { zone = "Tanaris", place = "Steamwheedle Port" }, to = { zone = "Riverglades", place = "Powderfuse Port" } },
  { id = "boat-ratchet-bootybay", kind = "boat", source = BOTH, verified = false,
    from = { zone = "The Barrens", place = "Ratchet" }, to = { zone = "Stranglethorn Vale", place = "Booty Bay" } },
  { id = "zep-org-undercity", kind = "zeppelin", faction = "Horde", source = BOTH, verified = false,
    from = { zone = "Durotar", place = "zeppelin towers outside Orgrimmar" }, to = { zone = "Tirisfal Glades", place = "tower outside Undercity" } },
  { id = "zep-org-gromgol", kind = "zeppelin", faction = "Horde", source = BOTH, verified = false,
    from = { zone = "Durotar", place = "zeppelin towers outside Orgrimmar" }, to = { zone = "Stranglethorn Vale", place = "Grom'gol" } },
  { id = "zep-undercity-gromgol", kind = "zeppelin", faction = "Horde", source = BOTH, verified = false,
    from = { zone = "Tirisfal Glades", place = "tower outside Undercity" }, to = { zone = "Stranglethorn Vale", place = "Grom'gol" } },
  { id = "zep-skywatcher-valanaar", kind = "zeppelin", faction = "Horde", source = BOTH, verified = false,
    from = { zone = "Mulgore", place = "Skywatcher Plateau", x = 0.343, y = 0.258 },
    to = { zone = "Zephras Isle", place = "Valanaar", x = 0.591, y = 0.798 },
    note = "Horde hand-off (LEP); The Earthen Ring quest" },
  { id = "sky-valanaar-dalaran", kind = "skycutter", faction = "Alliance", source = BOTH, verified = false,
    from = { zone = "Zephras Isle", place = "Valanaar", x = 0.666, y = 0.799 },
    to = { zone = "Alterac Mountains", place = "Dalaran", x = 0.125, y = 0.518 },
    note = "first ride comes with the quest The Magical City of Dalaran" },
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
