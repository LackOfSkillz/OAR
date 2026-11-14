-- Node memory: a herb seen up or picked by Gary changes how its pin looks and reads.
local T, mock = ...

T.describe("node state", function()
  T.it("picked dims a node for 15 min, seen-up shows green for 5 min, then both expire", function()
    local game = mock.new({ mapID = 1412, now = 1794700000 })
    local ns = game:loadAddon()
    game:login()
    local L = ns.LootLog
    local pin = { kind = "herb", mapID = 1412, x = 0.500, y = 0.500, name = "Silverleaf (guide)" }
    T.eq(L:NodeState(1412, 0.5, 0.5), nil)
    L:MarkNode("herb", 1412, 0.503, 0.498, "up")
    T.eq((L:NodeState(1412, 0.5, 0.5)), "up")
    T.contains(L:StateLine(pin), "probably still up")
    L:MarkNode("herb", 1412, 0.501, 0.501, "picked")
    T.eq((L:NodeState(1412, 0.5, 0.5)), "picked")
    T.contains(L:StateLine(pin), "probably empty")
    T.eq(L:NodeState(1412, 0.53, 0.5), nil, "a node 3% away is a different node")
    game.now = game.now + 16 * 60
    T.eq(L:NodeState(1412, 0.5, 0.5), nil, "picked memory runs out")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a gathering pin is painted as a hollow outline, other pins keep their icon", function()
    local game = mock.new({ mapID = 1412 })
    local ns = game:loadAddon()
    game:login()
    local f = game.env.CreateFrame("Button", nil, game.env.UIParent)
    ns.MapPins.Decorate(f, 10)
    ns.MapPins.Paint(f, { kind = "herb", mapID = 1412, x = 0.5, y = 0.5 })
    T.ok(f.edges and #f.edges == 4, "outline drawn")
    ns.MapPins.Paint(f, { kind = "vendor", mapID = 1412, x = 0.5, y = 0.5 })
    T.ok(f.edges, "outline kept for reuse")
    T.eq(#ns.Errors.list, 0)
  end)
end)
