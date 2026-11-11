-- Waypoints (P3-01) and coordinates (P3-10).
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  return game, ns
end

T.describe("waypoints", function()
  T.it("/ride way sets a Blizzard user waypoint on the current map and supertracks it", function()
    local game, ns = session()
    game:slash("way 50 60 test spot")
    T.eq(game.userWaypoint.uiMapID, 1412)
    T.eq(game.userWaypoint.x, 0.5)
    T.eq(game.userWaypoint.y, 0.6)
    T.ok(game.superTracked)
    T.eq(ns.Waypoints.current.backend, "blizzard")
    T.contains(game:chatText(), "waypoint test spot at 50.0, 60.0 (blizzard)")
  end)

  T.it("clears itself on arrival, and the arrival check stops", function()
    local game, ns = session()
    game:slash("way 60 37")
    game:advance(1.5)
    T.ok(ns.Waypoints.current, "100 yards away: still set")
    game.opts.x = 0.599
    game:advance(1.5)
    T.eq(ns.Waypoints.current, nil)
    T.eq(game.userWaypoint, nil)
    T.eq(ns.Timer.Pending(), 0)
  end)

  T.it("rejects bad input and clears with /ride way clear", function()
    local game, ns = session()
    T.no(ns.Waypoints:Set(1412, 2, 0.5))
    game:slash("way 10 10")
    game:slash("way clear")
    T.eq(ns.Waypoints.current, nil)
  end)

  T.it("/ride coords prints the map and two-decimal coordinates", function()
    local game = session()
    game:slash("coords")
    T.contains(game:chatText(), "Mulgore (map 1412): 46.00, 37.00")
  end)

  T.it("coords tick only while moving", function()
    local game, ns = session()
    T.eq(ns.Timer.Pending(), 0)
    game:fire("PLAYER_STARTED_MOVING")
    T.eq(ns.Timer.Pending(), 1)
    game:fire("PLAYER_STOPPED_MOVING")
    T.eq(ns.Timer.Pending(), 0)
  end)
end)
