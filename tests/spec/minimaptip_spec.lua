-- Minimap pin tooltips say what the pin is and why it's there (Gary,
-- 2026-11-22: "all it says is mini map pin").
local T, mock = ...

T.describe("minimap pin tooltips", function()
  T.it("the game's waypoint pin on the minimap gets Outrider's goal, distance and next step", function()
    local game = mock.new({ class = "DRUID", level = 10 })
    local ns = game:loadAddon()
    game:login()
    local J = ns.Journey
    local mm = rawget(game.env, "Minimap") or game.base.Minimap
    T.eq(J.MinimapTipLines(mm, "Map Pin"), nil, "no waypoint: the tooltip is left alone")
    ns.Waypoints:Set(100, 0.3, 0.5, "Tower")
    local lines = J.MinimapTipLines(mm, "Map Pin")
    T.ok(lines, "lines for the pin")
    T.contains(lines[1][1], "Tower")
    T.eq(J.MinimapTipLines(mm, "Elwynn Forest"), nil, "other minimap tooltips are left alone")
    T.eq(J.MinimapTipLines({}, "Map Pin"), nil, "only over the minimap")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("every kind of Outrider minimap pin has a plain reason line", function()
    local game = mock.new({ class = "DRUID", level = 10 })
    local ns = game:loadAddon()
    for kind in pairs(ns.MapPins.LABELS) do
      T.ok(ns.MinimapPins.WHY[kind], "a reason for " .. kind)
    end
  end)
end)
