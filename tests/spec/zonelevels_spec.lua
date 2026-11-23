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
    [105] = { name = "Ironforge", parent = 10, mapType = 3, rect = { 0.3, 0.4, 0.0, 0.1 } },
  }
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  -- the Classic creature pack: { npcID, name, lo, hi, rank, points }
  game.env.Outrider_DataMobs = { source = "spec", maps = {
    [101] = { { 1, "Rat", 2, 4 }, { 2, "Wolf", 5, 6 }, { 3, "Boar", 6, 7 }, { 4, "Boss", 30, 30, 3 } },
    [102] = { { 5, "Gnoll", 14, 15 }, { 6, "Murloc", 15, 17 }, { 7, "Spider", 16, 18 }, { 8, "Rare", 40, 40, 4 } },
    [103] = { { 9, "Giant", 30, 32 }, { 10, "Yeti", 31, 33 }, { 11, "Drake", 33, 35 } },
    [105] = { { 12, "Rat", 2, 3 }, { 13, "Guard", 55, 55 }, { 14, "Guard", 55, 55 } },
    -- a forest with guards at 55 and pets at 1: the zone is still 5-11; two areas, west low, east higher
    [106] = { { 20, "Wolf", 5, 6, 0, { 0.1, 0.1, 0.15, 0.12 } }, { 21, "Kobold", 6, 7, 0, { 0.12, 0.2 } }, { 22, "Spider", 5, 7, 0, { 0.2, 0.15 } },
      { 23, "Bear", 9, 10, 0, { 0.8, 0.8 } }, { 24, "Thief", 10, 11, 0, { 0.85, 0.82 } }, { 25, "Boar", 9, 11, 0, { 0.82, 0.9 } },
      { 26, "City Guard", 55, 55, 0, { 0.5, 0.05 } }, { 27, "Pony", 1, 1, 0, { 0.5, 0.5 } } },
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
    T.eq(by.Lowvale.lo, 4)
    T.eq(by.Lowvale.hi, 7, "the boss does not stretch the range")
    T.eq(by.Lowvale.color, "muted", "too low at 15")
    T.eq(by.Midmoor.lo, 15)
    T.eq(by.Midmoor.hi, 18, "the rare is left out")
    T.eq(by.Midmoor.color, "good")
    T.eq(by.Highpeak.color, "bad")
    T.eq(by.Emptycity, nil, "a city without creatures gets no label")
    T.eq(by.Ironforge, nil, "capital cities get no label")
    T.ok(math.abs(by.Midmoor.x - 0.5) < 1e-9 and math.abs(by.Midmoor.y - 0.5) < 1e-9, "at the zone's middle")
    T.eq(by.Midmoor.source, "classic")
    T.eq(Z:Text(by.Midmoor), "Midmoor\n15-18")
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

  T.it("guards and pets don't stretch a zone; a zone map shows a range per area", function()
    local game, ns = session(8)
    game.maps[106] = { name = "Forest", parent = 10, mapType = 3, rect = { 0.0, 0.1, 0.0, 0.1 } }
    local lo, hi = ns.ZoneLevels:Range(106)
    T.eq(lo, 5)
    T.eq(hi, 11)
    local areas = {}
    for _, l in ipairs(ns.ZoneLevels:Labels(106)) do if l.area then areas[#areas + 1] = l end end
    T.eq(#areas, 2)
    T.ok(areas[1].x < 0.5 and areas[1].hi <= 7, "north-west area is low")
    T.ok(areas[2].x > 0.5 and areas[2].lo >= 9, "south-east area is higher")
    T.eq(ns.ZoneLevels:Text(areas[1]), areas[1].lo .. "-" .. areas[1].hi)
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
    T.ok(Z.used[1]:GetFrameLevel() >= 1000, "above the explored-area art and pins")
    -- the map's own art can sit higher still (Forever): the labels go above it
    local canvas = game.env.WorldMapFrame:GetCanvas()
    local art = { GetFrameLevel = function() return 4200 end }
    canvas.GetChildren = function() return art end
    Z:Refresh()
    T.ok(Z.used[1]:GetFrameLevel() > 4200, "above the explored-area art: " .. tostring(Z.used[1]:GetFrameLevel()))
    canvas.GetChildren = nil
    -- the range is drawn on its own line under the name (it vanished when both
    -- were one string with word wrap off, 2026-11-23)
    local f = Z.used[1]
    T.ok(f.range:GetText() ~= nil and f.range:GetText():find("%d") ~= nil, "the levels show under the name: " .. tostring(f.range:GetText()))
    T.ok(not f.text:GetText():find("%d+%-%d+"), "the name line is just the name")
    game:slash("zonelevels off")
    T.eq(#Z.used, 0)
    game:slash("zonelevels on")
    T.eq(#Z.used, 3)
    -- colours follow the level
    T.eq(ns.ZoneLevels.Color(14, 18, 30), "muted")
    T.eq(ns.ZoneLevels.Color(14, 18, 11), "warn")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a world that is its own continent with no zones (Zephras Isle) is labelled like a zone", function()
    local game, ns = session(10)
    game.maps[2521] = { name = "Isle", mapType = 2 }
    game.env.Outrider_DataMobs.maps[2521] = { { 30, "Owl", 3, 4, 0, { 0.3, 0.3 } }, { 31, "Cat", 4, 5, 0, { 0.32, 0.31 } },
      { 32, "Hawk", 5, 6, 0, { 0.31, 0.33 } }, { 33, "Bird", 6, 7, 0, { 0.33, 0.32 } } }
    ns.Finder.mobs = nil
    ns.ZoneLevels.cache = {}
    local labels = ns.ZoneLevels:Labels(2521)
    T.ok(#labels >= 1, "the island gets a range")
    T.eq(labels[1].name, "Isle")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("Outrider's own data addon switched off for this character is switched back on and loaded", function()
    local game, ns = session(15)
    game.disabledAddons = { Outrider_Data_Mobs = true, SomeoneElse = true }
    game.loadable = { Outrider_Data_Mobs = true, SomeoneElse = true }
    T.ok(ns.Compat.LoadAddOn("Outrider_Data_Mobs"), "switched back on, then loaded")
    T.contains(ns.Compat.loadReasons.Outrider_Data_Mobs, "switched back on")
    local ok, why = ns.Compat.LoadAddOn("SomeoneElse")
    T.no(ok, "another addon is never switched on")
    T.eq(why, "DISABLED")
  end)
end)
