-- Breadcrumbs (Trail): where you walked, on the world map. Positions are test data.
local T, mock = ...

local function session()
  local game = mock.new({ mapID = 100, x = 0.10, y = 0.50 })
  game.maps = { [1] = { name = "World" }, [10] = { name = "East", parent = 1 }, [100] = { name = "Old City", parent = 10 } }
  game.mapWorld = { [100] = { 1, 0, 0 } }   -- 1000 x 1000 yards
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  return game, ns
end

local function walkTo(game, x, y) game.opts.x, game.opts.y = x, y end

T.describe("trail", function()
  T.it("drops a dot every 12 yards while moving, none on the same spot, and stops with you", function()
    local game, ns = session()
    local Tr = ns.Trail
    game:fire("PLAYER_STARTED_MOVING")
    T.ok(Tr.ticker, "samples only while moving")
    for i = 1, 5 do
      walkTo(game, 0.10 + i * 0.015, 0.50)   -- 15 yards a step
      game:advance(Tr.EVERY)
    end
    T.eq(#Tr:Dots(100), 5)
    walkTo(game, 0.10 + 5 * 0.015 + 0.005, 0.50)   -- 5 yards more: too close
    game:advance(Tr.EVERY)
    T.eq(#Tr:Dots(100), 5)
    game:fire("PLAYER_STOPPED_MOVING")
    T.eq(Tr.ticker, nil)
    -- walking the same street back adds nothing new
    Tr.last = nil
    walkTo(game, 0.115, 0.50)
    T.eq(Tr:Sample(), false)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("never records on a flight path", function()
    local game, ns = session()
    game.env.UnitOnTaxi = function() return true end
    walkTo(game, 0.6, 0.6)
    T.eq(ns.Trail:Sample(), false)
  end)

  T.it("shows dots and the rides you took on the world map; the Map tab can hide them", function()
    local game, ns = session()
    ns.Trail:Sample()
    ns.db.global.travelLinks = { { kind = "learned", from = { mapID = 100, x = 0.12, y = 0.56 },
      to = { mapID = 100, x = 0.9, y = 0.9 }, t = 1794000000, oneWay = true } }
    ns.MapPins:Invalidate()
    local kinds = {}
    for _, p in ipairs(ns.MapPins:PinsFor(100)) do kinds[p.kind] = (kinds[p.kind] or 0) + 1 end
    T.eq(kinds.trail, 1)
    T.eq(kinds.ride, 1)
    local ride
    for _, p in ipairs(ns.MapPins:PinsFor(100)) do if p.kind == "ride" then ride = p end end
    T.contains(ride.name, "Ride to ")
    T.ok(ride.x == 0.12 and ride.y == 0.56)
    -- hiding the kind in the Map tab hides the dots
    ns.MapPins:Settings().hidden.trail = true
    ns.MapPins:Invalidate()
    for _, p in ipairs(ns.MapPins:PinsFor(100)) do T.ok(p.kind ~= "trail") end
  end)

  T.it("keeps at most MAX dots per map and clears on request", function()
    local _, ns = session()
    local Tr = ns.Trail
    local list = {}
    for i = 1, Tr.MAX do list[i] = { x = 0.001 * i, y = 0.9, t = i } end
    Tr.db[100] = list
    Tr.last = nil
    Tr:Sample()
    T.eq(#Tr:Dots(100), Tr.MAX)
    T.eq(Tr:Dots(100)[1].t, 2)   -- the oldest went
    Tr:Clear(100)
    T.eq(#Tr:Dots(100), 0)
  end)
end)
