-- Map tab: pin filters and discovery controls (P3-09).
local T, mock = ...

local function session()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game:slash("")
  ns.Hub.frame.tabBar:Select("map")
  return game, ns, ns.Hub.byId.map.panel
end

T.describe("map tab", function()
  T.it("unticking a kind hides its pins for this character", function()
    local game, ns, p = session()
    ns.db.global.pois["npc-1-vendor"] = { id = "npc-1-vendor", kind = "vendor", mapID = 1412, x = 0.5, y = 0.5, name = "S", verified = false }
    if ns.MapPins then ns.MapPins:Invalidate() end -- placed directly, as the addon's own writers then do
    T.eq(#ns.MapPins:PinsFor(1412), 1)
    local vendor = p.checks[2]
    vendor.__scripts.OnClick(vendor)
    T.eq(#ns.MapPins:PinsFor(1412), 0)
  end)

  T.it("clear needs two clicks and empties places and NPCs", function()
    local game, ns, p = session()
    ns.db.global.pois["npc-1-vendor"] = { id = "npc-1-vendor", kind = "vendor", mapID = 1412, x = 0.5, y = 0.5, verified = false }
    if ns.MapPins then ns.MapPins:Invalidate() end -- placed directly, as the addon's own writers then do
    ns.db.global.discovered.npcs[1] = { name = "X" }
    p.clear.__scripts.OnClick(p.clear)
    T.ok(ns.db.global.pois["npc-1-vendor"], "first click only arms")
    p.clear.__scripts.OnClick(p.clear)
    T.eq(next(ns.db.global.pois), nil)
    T.eq(next(ns.db.global.discovered.npcs), nil)
    T.contains(p.counts:GetText(), "0 places and 0 NPCs")
  end)

  T.it("Discovery can be switched off here", function()
    local game, ns, p = session()
    p.disc.__scripts.OnClick(p.disc)
    T.no(ns.Modules:Get("Discovery").enabled)
    T.eq(#ns.Errors.list, 0)
  end)
end)
