-- Zone levels on the world map. Maps, creatures and levels are test data.
local T, mock = ...

local function session(level)
  local game = mock.new({ mapID = 101, x = 0.5, y = 0.5, level = level or 15 })
  game.maps = {
    [10] = { name = "Testland", mapType = 2 },
    [101] = { name = "Lowvale", parent = 10, mapType = 3, rect = { 0.1, 0.3, 0.1, 0.3 } },
    [102] = { name = "Midmoor", parent = 10, mapType = 3, rect = { 0.4, 0.6, 0.4, 0.6 } },
    [103] = { name = "Highpeak", parent = 10, mapType = 3, rect = { 0.7, 0.9, 0.7, 0.9 } },
    [104] = { name = "Emptycity", parent = 10, mapType = 3, rect = { 0.0, 0.1, 0.9, 1.0 } },
  }
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  -- the Classic creature pack: { npcID, name, lo, hi, rank, points }
  game.env.Outrider_DataMobs = { source = "spec", maps = {
    [101] = { { 1, "Rat", 2, 4 }, { 2, "Wolf", 5, 6 }, { 3, "Boar", 6, 7 }, { 4, "Boss", 30, 30, 3 } },
    [102] = { { 5, "Gnoll", 14, 15 }, { 6, "Murloc", 15, 17 }, { 7, "Spider", 16, 18 }, { 8, "Rare", 40, 40, 4 } },
    [103] = { { 9, "Giant", 30, 32 }, { 10, "Yeti", 31, 33 }, { 11, "Drake", 33, 35 } },
  } }
  ns.Finder.mobs = nil
  return game, ns
end

T.describe("zone levels", function()
  T.it("each zone on a continent map gets its level range, coloured for your level", function()
    local _, ns = session(15)
    local Z = ns.ZoneLevels
    local by = {}
    for _, l in ipairs(Z:Labels(10)) do by[l.name] = l end
    T.eq(by.Lowvale.lo, 2)
    T.eq(by.Lowvale.hi, 7, "the boss does not stretch the range")
    T.eq(by.Lowvale.color, "muted", "too low at 15")
    T.eq(by.Midmoor.lo, 14)
    T.eq(by.Midmoor.hi, 18, "the rare is left out")
    T.eq(by.Midmoor.color, "good")
    T.eq(by.Highpeak.color, "bad")
    T.eq(by.Emptycity, nil, "a city without creatures gets no label")
    T.ok(math.abs(by.Midmoor.x - 0.5) < 1e-9 and math.abs(by.Midmoor.y - 0.5) < 1e-9, "at the zone's middle")
    T.eq(by.Midmoor.source, "classic")
    T.eq(Z:Text(by.Midmoor), "Midmoor\n14-18")
  end)

  T.it("creatures you met win over the Classic data once there are enough", function()
    local _, ns = session(15)
    local npcs = {}
    for i = 1, 10 do npcs[1000 + i] = { mapID = 102, level = 20 + (i % 3), creatureType = "Beast" } end
    npcs[2000] = { mapID = 102, level = 60, creatureType = "Beast", classification = "rareelite" }
    npcs[2001] = { mapID = 102, level = 1, creatureType = "Critter" }
    npcs[2002] = { mapID = 102, level = 30, creatureType = "Humanoid", title = "Innkeeper" }
    ns.db.global.discovered = { npcs = npcs }
    local lo, hi, source = ns.ZoneLevels:Range(102)
    T.eq(source, "seen")
    T.eq(lo, 20)
    T.eq(hi, 22)
  end)

  T.it("a zone map shows its own range at the top; draws on the map and can be switched off", function()
    local game, ns = session(15)
    local Z = ns.ZoneLevels
    local labels = Z:Labels(102)
    T.eq(#labels, 1)
    T.eq(labels[1].y < 0.1, true)
    game.mapShownID = 10
    Z:Refresh()
    T.eq(#Z.used, 3)
    game:slash("zonelevels off")
    T.eq(#Z.used, 0)
    game:slash("zonelevels on")
    T.eq(#Z.used, 3)
    -- colours follow the level
    T.eq(ns.ZoneLevels.Color(14, 18, 30), "muted")
    T.eq(ns.ZoneLevels.Color(14, 18, 11), "warn")
    T.eq(#ns.Errors.list, 0)
  end)
end)
