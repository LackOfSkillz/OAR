-- Map extras: dungeon entrance pins and flight times (gap analysis 2026-11-17).
local T, mock = ...

T.describe("map extras", function()
  T.it("dungeon entrances show as pins on their map, and can be hidden", function()
    local game = mock.new({ class = "HUNTER", level = 20 })
    game.base.Outrider_DataDungeons = { source = "test", dungeons = {
      [1581] = { name = "The Deadmines", map = 1436, x = 0.425, y = 0.717, bosses = {}, items = {} } } }
    rawset(game.env, "Outrider_DataDungeons", game.base.Outrider_DataDungeons)
    local ns = game:loadAddon()
    game:login()
    local found
    for _, p in ipairs(ns.MapPins:PinsFor(1436)) do if p.kind == "dungeon" then found = p end end
    T.ok(found)
    T.eq(found.name, "The Deadmines")
    ns.MapPins:Settings().hidden.dungeon = true
    ns.MapPins:Invalidate()
    found = nil
    for _, p in ipairs(ns.MapPins:PinsFor(1436)) do if p.kind == "dungeon" then found = p end end
    T.eq(found, nil)
  end)

  T.it("times a flight you take and counts down the next one on the info bar", function()
    local game = mock.new({ class = "HUNTER", level = 20 })
    local onTaxi = false
    local function set(k, v) rawset(game.env, k, v) game.base[k] = v end
    set("NumTaxiNodes", function() return 2 end)
    set("TaxiNodeName", function(i) return i == 1 and "Orgrimmar" or "Crossroads" end)
    set("TaxiNodeGetType", function(i) return i == 1 and "CURRENT" or "REACHABLE" end)
    set("TakeTaxiNode", function() end)
    set("UnitOnTaxi", function() return onTaxi end)
    local ns = game:loadAddon()
    game:login()
    local F = ns.FlightTimes
    game.now = 5000
    game.env.TakeTaxiNode(2)
    onTaxi = true
    game:fire("PLAYER_CONTROL_LOST")
    game.now = game.now + 100
    onTaxi = false
    game:fire("PLAYER_CONTROL_GAINED")
    T.eq(F:Get("Orgrimmar", "Crossroads"), 100)
    -- second flight: a countdown
    game.env.TakeTaxiNode(2)
    onTaxi = true
    game:fire("PLAYER_CONTROL_LOST")
    game.now = game.now + 40
    T.contains(ns.InfoBar:Text("flight"), "1:00")
    local lines = {}
    F:TipLine({ AddLine = function(_, t) lines[#lines + 1] = t end, Show = function() end }, 2)
    T.contains(lines[1], "1:40")
    T.eq(#ns.Errors.list, 0)
  end)
end)
