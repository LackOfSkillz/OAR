-- Out of ammo: warn once and point at the nearest vendor that sells ammo. Test data.
local T, mock = ...

T.describe("ammo vendor", function()
  T.it("nearest ammo finds a vendor whose goods include ammo; out of ammo sets the arrow there", function()
    local game = mock.new({ mapID = 1412, x = 0.5, y = 0.5, ammo = 38 })
    local ns = game:loadAddon()
    game:login()
    ns.db.global.pois = {
      ["npc-1-vendor"] = { kind = "vendor", mapID = 1412, x = 0.52, y = 0.5, name = "Baker", goods = { "food & drink" } },
      ["npc-2-vendor"] = { kind = "vendor", mapID = 1412, x = 0.60, y = 0.5, name = "Veena Vericloud", goods = { "ammo", "bags" } },
    }
    local p = ns.Nearest:Find("ammo")
    T.eq(p.name, "Veena Vericloud", "the baker is closer but sells no ammo")
    local ammo = ns.Modules:Get("Ammo")
    ammo.last = 38
    game.ammo = 0
    ammo:Evaluate()
    T.eq(ns.Waypoints.current.title, "Veena Vericloud")
    local warned
    for _, l in ipairs(ns.Log:Tail(20)) do if ns.Log:FormatLine(l):find("out of ammo", 1, true) then warned = true end end
    T.ok(warned)
    T.eq(#ns.Errors.list, 0)
  end)
end)
