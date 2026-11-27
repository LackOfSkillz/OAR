-- Bosses and their loot on dungeon maps (2026-11-23, ideas from FojjiCore).
local T, mock = ...

T.describe("bosses on dungeon maps", function()
  T.it("places each boss on the dungeon map from its spot inside the instance, with its loot", function()
    local game = mock.new({ mapID = 1413, x = 0.5, y = 0.5 })
    game.maps = { [279] = { name = "Wailing Caverns", mapType = 4 }, [1413] = { name = "The Barrens", mapType = 3 } }
    game.mapWorld = { [279] = { 43, -500, -500 }, [1413] = { 1, 0, 0 } }
    game.items = { [5404] = { name = "Serpent's Shoulders", equipLoc = "INVTYPE_SHOULDER" } }
    rawset(game.env, "Outrider_DataTravel", { source = "spec", taxi = {}, flights = {}, docks = {}, rides = {}, portals = {},
      bosses = { [43] = { { 3671, "Lady Anacondra", 1, 46, 184, { 5404, 3666 } }, { 9999, "Far Away", 1, 9000, 9000, {} } } } })
    local ns = game:loadAddon()
    game:login()
    ns.Travel.pack = nil
    local pins = ns.DungeonJournal:BossPins(279)
    T.eq(#pins, 1, "the one that lands on this map")
    T.eq(pins[1].name, "Lady Anacondra")
    T.ok(math.abs(pins[1].x - 0.546) < 0.001 and math.abs(pins[1].y - 0.684) < 0.001)
    T.contains(pins[1].poi.note, "Serpent's Shoulders  37%")
    T.eq(#ns.DungeonJournal:BossPins(1413), 0, "not on zone maps")
    local onMap = 0
    for _, p in ipairs(ns.MapPins:BuildPins(279)) do if p.kind == "boss" then onMap = onMap + 1 end end
    T.eq(onMap, 1, "on the world map's pins")
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("boss tips and the first dungeon shown", function()
  T.it("a boss skull's tip says what the boss needs, from the researched guides, marked unchecked", function()
    local game = mock.new({ mapID = 1413, x = 0.5, y = 0.5 })
    game.maps = { [279] = { name = "Wailing Caverns", mapType = 4 } }
    game.mapWorld = { [279] = { 43, -500, -500 } }
    rawset(game.env, "Outrider_DataTravel", { source = "spec", taxi = {}, flights = {}, docks = {}, rides = {}, portals = {},
      bosses = { [43] = { { 3671, "Lady Anacondra", 1, 46, 184, {} }, { 3669, "Nobody Known", 1, 47, 185, {} } } } })
    local ns = game:loadAddon()
    game:login()
    ns.VanguardFacts = { bosses = { ["Wailing Caverns"] = { kind = "classic", source = "x", list = {
      { name = "Lady Anacondra", tags = { interrupt_heal = "heals", dispel_magic = "sleep", fear = "x" } } } } } }
    ns.DungeonJournal.factsByBoss = nil
    ns.Travel.pack = nil
    local pins = ns.DungeonJournal:BossPins(279)
    local tip = {}
    for _, p in ipairs(pins) do tip[p.name] = p.poi.note end
    T.contains(tip["Lady Anacondra"], "Bring:|r interrupt its heal, remove magic")
    T.contains(tip["Lady Anacondra"], "Watch:|r fears players")
    T.contains(tip["Lady Anacondra"], "Classic guide, Forever may differ, not checked in game")
    T.ok(not tip["Nobody Known"]:find("Bring"), "no researched needs: no made-up line")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("finds a dungeon's inside map from the client's own list, wherever it is filed, and logs the list", function()
    local game = mock.new()
    game.maps = { [279] = { name = "Wailing Caverns", mapType = 4 }, [280] = { name = "Wailing Caverns", mapType = 4 },
      [213] = { name = "Ragefire Chasm", mapType = 4 }, [1413] = { name = "The Barrens", mapType = 3 } }
    local ns = game:loadAddon()
    game:login()
    local P = ns.MapPages
    P.scan, P.dungeonMaps = nil, {}
    T.eq(P.DungeonMap("Wailing Caverns", 1413), 279, "found with no parent link, first id wins")
    T.eq(P.DungeonMap("Ragefire Chasm", nil), 213, "found with no zone at all")
    T.eq(P.DungeonMap("Alterac Valley", 1416), nil, "none: the zone is shown instead")
    local logged = false
    for _, l in ipairs(ns.Log:Tail(50)) do if tostring(ns.Log:FormatLine(l) or l):find("213 Ragefire Chasm") then logged = true end end
    T.ok(logged, "the list is in the log")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("opens a dungeon for your level, else the next one up; battlegrounds last", function()
    local game = mock.new()
    local ns = game:loadAddon()
    local items = { { name = "Alterac Valley", min = 0, max = 0 }, { name = "Ragefire Chasm", min = 13, max = 18 },
      { name = "The Deadmines", min = 18, max = 23 }, { name = "Scholomance", min = 58, max = 60 } }
    T.eq(ns.MapPages.Pick(items, 8), "Ragefire Chasm", "level 8: the next one up, not the battleground")
    T.eq(ns.MapPages.Pick(items, 20), "The Deadmines")
    T.eq(ns.MapPages.Pick(items, 40), "Scholomance", "between: the next one up")
    T.eq(ns.MapPages.Pick(items, 62), "Scholomance", "above all: the highest")
    T.eq(ns.MapPages.Pick({ items[1] }, 8), "Alterac Valley", "only a battleground: that")
  end)
end)

T.describe("wish list drops", function()
  T.it("a wish list item in a roll or a loot window gets one toast, and getting it is noted", function()
    local game = mock.new()
    game.items = { [5404] = { name = "Serpent's Shoulders" } }
    local ns = game:loadAddon()
    game:login()
    ns.BagExtras:Wish(5404, true)
    game.lootRolls = { [7] = { link = "|cff0070dd|Hitem:5404::|h[Serpent's Shoulders]|h|r" } }
    game:fire("START_LOOT_ROLL", 7)
    T.eq(ns.Toast:Count(), 1)
    T.contains(ns.Toast.visible[1].title:GetText(), "up for a roll")
    game:fire("START_LOOT_ROLL", 7)
    T.eq(ns.Toast:Count(), 1, "once a minute per item")
    ns.DungeonJournal.told = {}
    game.env.LOOT_ITEM_SELF = "You receive loot: %s."
    game:fire("CHAT_MSG_LOOT", "You receive loot: |cff0070dd|Hitem:5404::|h[Serpent's Shoulders]|h|r.")
    T.ok(ns.BagExtras:Wishlist()[5404].got ~= nil, "noted as got")
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("dungeon run timer", function()
  T.it("splits at each boss kill, ends when you leave, keeps the best", function()
    local game = mock.new()
    local inside = false
    game.env.IsInInstance = function() if inside then return true, "party" end return false, "none" end
    game.env.GetInstanceInfo = function() return "Wailing Caverns", "party" end
    local ns = game:loadAddon()
    game:login()
    local J = ns.DungeonJournal
    inside = true
    game:fire("PLAYER_ENTERING_WORLD")
    T.ok(J.run ~= nil, "started inside")
    game:advance(300)
    game:fire("ENCOUNTER_END", 585, "Lady Anacondra", 1, 5, 1)
    game:advance(200)
    game:fire("ENCOUNTER_END", 586, "Lord Cobrahn", 1, 5, 0)
    T.eq(#J.run.splits, 1, "a wipe is not a split")
    game:fire("ENCOUNTER_END", 586, "Lord Cobrahn", 1, 5, 1)
    inside = false
    game:fire("PLAYER_ENTERING_WORLD")
    game:advance(J.REJOIN + 5)
    game:fire("ZONE_CHANGED_NEW_AREA")
    local rec = ns.db.global.dungeonRuns["Wailing Caverns"]
    T.ok(rec and rec.bosses == 2, "two bosses")
    T.ok(math.abs(rec.best - 500) < 2, "time to the last kill")
    T.ok(math.abs(rec.splits["Lady Anacondra"] - 300) < 2)
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("unlock mode", function()
  T.it("shows the movable pieces with a drag outline and puts back what was hidden", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    local hud = game.env.CreateFrame("Frame", "Outrider_FishingHUD", game.env.UIParent)
    hud:Hide()
    game:slash("unlock")
    T.ok(hud:IsShown(), "shown to be moved")
    T.ok(hud.otrUnlock ~= nil, "outlined")
    T.eq(ns.Toast:Count(), 1, "a sample pop-up marks the pop-up spot")
    game:slash("lock")
    T.ok(not hud:IsShown(), "hidden again")
    T.eq(#ns.Errors.list, 0)
  end)
end)
