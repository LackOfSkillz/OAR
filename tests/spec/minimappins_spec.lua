-- Minimap pins (P3-04): coordinate math and approach behaviour.
local T, mock = ...

local function near(a, b) return math.abs(a - b) < 1e-6 end

T.describe("minimap math", function()
  local Offset
  T.it("north is up, west is left, outside the radius is nil", function()
    local game = mock.new()
    local ns = game:loadAddon()
    Offset = ns.Modules:Get("MinimapPins").Offset
    local x, y = Offset(100, 0, 200, 70)
    T.ok(near(x, 0) and near(y, 35))
    x, y = Offset(0, 100, 200, 70)
    T.ok(near(x, -35) and near(y, 0), "a point to the west is left")
    T.eq(Offset(0, 250, 200, 70), nil)
  end)

  T.it("rotating minimap: facing west puts a point to the west straight up", function()
    local x, y = Offset(0, 100, 200, 70, math.pi / 2)
    T.ok(near(x, 0) and near(y, 35))
  end)
end)

T.describe("minimap pins", function()
  T.it("a known vendor shows when within the radius and hides when far", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    ns.Modules:SetEnabled("AutoCheck", false)
    ns.db.global.pois["npc-1-vendor"] = { id = "npc-1-vendor", kind = "vendor", mapID = 1412, x = 0.50, y = 0.37, name = "Smith", verified = false }
    local M = ns.Modules:Get("MinimapPins")
    M:Update()
    T.eq(#M.used, 1, "40 yards away with a 200 yard radius")
    game.opts.x = 0.10
    M:Update()
    T.eq(#M.used, 0, "400 yards away")
    T.eq(#ns.Errors.list, 0)
  end)
end)
