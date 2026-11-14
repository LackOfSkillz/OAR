-- Rares seen through minimap vignettes: alert, red flash, arrow to the exact spot.
local T, mock = ...

T.describe("rare vignettes", function()
  T.it("a vignette on a creature-pack rare elite alerts with an arrow to its spot; others are only logged", function()
    local game = mock.new({ mapID = 1412 })
    game.base.Outrider_DataMobs = { source = "test", maps = { [1412] = {
      { 701, "Slydris", 6, 6, 2, { 0.49, 0.52 } },
    } } }
    rawset(game.env, "Outrider_DataMobs", game.base.Outrider_DataMobs)
    local vig = {
      ["v1"] = { name = "Slydris", atlasName = "VignetteKillElite", objectGUID = "Creature-0-1-2-11-701-ABC" },
      ["v2"] = { name = "Old Chest", atlasName = "VignetteLoot", objectGUID = "GameObject-0-1-2-11-99-DEF" },
    }
    local api = {
      GetVignettes = function() return { "v1", "v2" } end,
      GetVignetteInfo = function(g) return vig[g] end,
      GetVignettePosition = function(g) if g == "v1" then return { GetXY = function() return 0.506, 0.512 end } end end,
    }
    game.base.C_VignetteInfo = api
    rawset(game.env, "C_VignetteInfo", api)
    local ns = game:loadAddon()
    game:login()
    local w = ns.Waypoints.current
    T.ok(w and w.title:find("Slydris", 1, true), "arrow points at Slydris")
    T.eq(math.floor(w.x * 1000 + 0.5), 506)
    local log = ""
    for _, l in ipairs(ns.Log:Tail(80)) do log = log .. ns.Log:FormatLine(l) .. "\n" end
    T.contains(log, "how=vignette")
    T.contains(log, "vignette Old Chest atlas=VignetteLoot")
    T.ok(ns.Modules:Get("RareAlerts").flash ~= nil, "screen flash made")
    T.eq(#ns.Errors.list, 0)
  end)
end)
