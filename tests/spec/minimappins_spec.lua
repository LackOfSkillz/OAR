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

T.describe("minimap pin hover", function()
  T.it("hovering a dot shows its name, kind and distance; clicking opens its card", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    ns.Modules:SetEnabled("AutoCheck", false)
    ns.db.global.pois["npc-1-vendor"] = { id = "npc-1-vendor", kind = "vendor", mapID = 1412, x = 0.50, y = 0.37, name = "Smith", verified = false }
    local M = ns.Modules:Get("MinimapPins")
    M:Update()
    local d = M.used[1]
    local tip = game.env.GameTooltip
    d.__scripts.OnEnter(d)
    T.eq(tip.__lines[1], "Smith")
    T.eq(tip.__lines[2], "Vendor, 40 yards")
    d.__scripts.OnClick(d)
    T.eq(ns.MapPins.card.title:GetText(), "Smith")
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("minimap pins direction", function()
  T.it("a place north-east of you is up-right, and the dot moves toward the centre as you walk to it", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    ns.Modules:SetEnabled("AutoCheck", false)
    -- player at map 0.46,0.37; place at 0.50 (east), 0.33 (north): map y grows south
    ns.db.global.pois["npc-2-vendor"] = { id = "npc-2-vendor", kind = "vendor", mapID = 1412, x = 0.50, y = 0.33, name = "NE", verified = false }
    local M = ns.Modules:Get("MinimapPins")
    M:Update()
    local _, _, _, x1, y1 = M.used[1]:GetPoint(1)
    T.ok(x1 > 0 and y1 > 0, "up and to the right")
    game.opts.x, game.opts.y = 0.47, 0.36 -- walk a quarter of the way toward it (still outside the clear centre)
    M:Update()
    local _, _, _, x2, y2 = M.used[1]:GetPoint(1)
    T.ok(x2 > 0 and x2 < x1 and y2 > 0 and y2 < y1, "closer to the centre")
  end)
end)

T.describe("minimap rare box", function()
  T.it("when a rare's alarm goes off, a blue box marks its nearest spawn spot for a few minutes", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    ns.Modules:SetEnabled("AutoCheck", false)
    ns.Data:Register("rare", "spec", { { npcID = 83001, name = "Spec Cat", mapID = 1412, verified = false,
      spawns = { { x = 0.47, y = 0.37 }, { x = 0.90, y = 0.90 } } } })
    local M = ns.MinimapPins
    ns.Events:Fire("OTR_RARE_SEEN", { npcID = 83001, name = "Spec Cat", how = "nameplate", mapID = 1412 })
    local box
    for _, d in ipairs(M.used) do if d.pin and d.pin.box then box = d end end
    T.ok(box, "blue box on the minimap")
    T.eq(box.pin.x, 0.47, "the near spawn spot, not the far one")
    T.eq(box.pin.box, M.BLUE)
    T.eq(box:GetWidth(), M.BOX)
    -- gone after a few minutes
    game:advance(M.LIVE + 2)
    for _, d in ipairs(M.used) do T.ok(not (d.pin and d.pin.box), "box expired") end
    -- a rare with no spawn spot near you: no box, no error
    ns.Events:Fire("OTR_RARE_SEEN", { npcID = 99999, name = "Nobody", how = "nameplate", mapID = 1412 })
    T.eq(M:MarkRare({ npcID = 83001, name = "Spec Cat" }) ~= nil, true)
    game.opts.x = 0.10
    T.eq(M:MarkRare({ npcID = 83001, name = "Spec Cat" }), nil)
    T.eq(#ns.Errors.list, 0)
  end)
end)
