-- OI03-05: travel time observations (planned trip to arrival).
local T, mock = ...

local function session(opts)
  local game = mock.new(opts or { mapID = 1412, x = 0.5, y = 0.5 })
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("Outcomes", true)
  -- a fixed planner estimate, so detours are predictable
  ns.Travel.TimeTo = function() return 100 end
  ns.Travel.TimeToRaw = ns.Travel.TimeTo -- trips record the raw estimate (Pathfinder, OI04-13)
  return game, ns, ns.TravelTimes
end
local function trips(ns) return ns.TravelTimes:List(ns.Outcomes:Store()) end
local function lastTrip(ns) local l = trips(ns) return l[#l] end
local function go(ns) return ns.Waypoints:Set(1412, 0.6, 0.6, "Somewhere") end
local function arrive(ns) ns.Waypoints:Clear("arrived") end

T.describe("travel time observations (OI03-05)", function()
  T.it("a plain trip on foot is a walking sample with its time and the planner's estimate", function()
    local game, ns = session()
    go(ns)
    game:advance(80)
    arrive(ns)
    local t = lastTrip(ns)
    T.eq(t.kind, "arrived") T.eq(t.seconds, 80) T.eq(t.estimate, 100)
    T.eq(t.mode, "ground") T.eq(t.walking, true)
    T.eq(t.fromMap, 1412)
    T.eq(t.playSessionId, ns.PlaySession:Id())
  end)

  T.it("a flight, a boat (loading screen) and a teleport are never walking samples", function()
    local game, ns = session()
    go(ns)
    game.env.UnitOnTaxi = function() return true end
    game:fire("PLAYER_CONTROL_LOST")
    game.env.UnitOnTaxi = function() return false end
    game:advance(60) arrive(ns)
    T.eq(lastTrip(ns).mode, "flight") T.eq(lastTrip(ns).walking, nil)
    go(ns)
    game:fire("PLAYER_ENTERING_WORLD", false, false) -- a loading screen
    game:advance(60) arrive(ns)
    T.eq(lastTrip(ns).mode, "transport")
    go(ns)
    game:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 8690)
    game:advance(5)
    game:fire("PLAYER_ENTERING_WORLD", false, false)
    game:advance(20) arrive(ns)
    T.eq(lastTrip(ns).mode, "teleport")
  end)

  T.it("a detour (more than twice the estimate) and AFK time are kept but not walking samples", function()
    local game, ns = session()
    go(ns) game:advance(250) arrive(ns)
    T.eq(lastTrip(ns).detour, true) T.eq(lastTrip(ns).walking, nil) T.eq(lastTrip(ns).mode, "ground")
    go(ns)
    game.env.UnitIsAFK = function() return true end
    game:fire("PLAYER_FLAGS_CHANGED", "player")
    game:advance(30) arrive(ns)
    T.eq(lastTrip(ns).afk, true) T.eq(lastTrip(ns).walking, nil)
  end)

  T.it("dying on the way, or an unknown map, labels the trip", function()
    local game, ns = session()
    go(ns) game:fire("PLAYER_DEAD") game:advance(40) arrive(ns)
    T.eq(lastTrip(ns).mode, "interrupted")
    local real = ns.Compat.PlayerPosition
    ns.Compat.PlayerPosition = function() return nil end
    go(ns) game:advance(40) arrive(ns)
    ns.Compat.PlayerPosition = real
    T.eq(lastTrip(ns).mode, "unknown_map") T.eq(lastTrip(ns).walking, nil)
  end)

  T.it("a destination replaced before arrival is an abandoned trip with no time", function()
    local game, ns = session()
    go(ns) game:advance(30)
    ns.Waypoints:Set(1412, 0.2, 0.2, "Elsewhere")
    local list = trips(ns)
    T.eq(list[#list].kind, "abandoned") T.eq(list[#list].seconds, nil)
  end)

  T.it("a reload or disconnect mid-trip is closed as interrupted at the next login, not lost or timed", function()
    local game, ns = session()
    go(ns) game:advance(30)
    local saved = game:logout()
    local g2 = mock.new({ savedVariables = saved, mapID = 1412, x = 0.5, y = 0.5 })
    local ns2 = g2:loadAddon()
    g2:fire("ADDON_LOADED", "Outrider") g2:fire("PLAYER_LOGIN")
    g2:fire("PLAYER_ENTERING_WORLD", false, true)
    local t = lastTrip(ns2)
    T.eq(t.kind, "interrupted") T.eq(t.interruptedBy, "reload") T.eq(t.seconds, nil)
    T.eq(ns2.Outcomes:Store().openTrip, nil)
  end)

  T.it("the summary counts every mode and lists only walking samples", function()
    local game, ns, R = session()
    go(ns) game:advance(50) arrive(ns)
    go(ns) game:fire("PLAYER_ENTERING_WORLD", false, false) game:advance(50) arrive(ns)
    local sum = R:Summary(ns.Outcomes:Store())
    T.eq(sum.byMode.ground, 1) T.eq(sum.byMode.transport, 1)
    T.eq(#sum.walking, 1)
  end)

  T.it("the 201st trip archives the oldest", function()
    local game, ns, R = session()
    for _ = 1, R.MAX + 1 do go(ns) arrive(ns) end
    T.eq(#trips(ns), R.MAX)
    T.ok(#ns.Archive:Rows("travelTrips") >= 1)
  end)
end)
