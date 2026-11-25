-- Optional private NPC pack (D10). Rows are test data.
local T, mock = ...

local function session(withPack)
  local game = mock.new()
  local ns
  if withPack then
    game.base.Outrider_DataNPC = { source = "test", maps = { [1412] = {
      { 9101, "vendor", 0.47, 0.37, "Pack Smith", "Weaponsmith", nil },
      { 9101, "repair", 0.47, 0.37, "Pack Smith", "Weaponsmith", nil },
      { 9102, "innkeeper", 0.48, 0.38, "Pack Inn", "Innkeeper", "Horde" },
      { 9103, "trainer", 0.49, 0.39, "Ally Teacher", "Mage Trainer", "Alliance" },
    } } }
    rawset(game.env, "Outrider_DataNPC", game.base.Outrider_DataNPC)
  end
  ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  return game, ns
end

T.describe("npc pack", function()
  T.it("works without the pack (no dependency)", function()
    local game, ns = session(false)
    T.eq(ns.NPCPack.count, 0)
    T.eq(#ns.MapPins:PinsFor(1412), 0)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("with the pack: one pin per NPC, best role, faction filtered, marked unverified", function()
    local game, ns = session(true)
    local pins = ns.MapPins:PinsFor(1412)
    T.eq(#pins, 2, "Alliance trainer hidden for a Horde player")
    local kinds = {}
    for _, p in ipairs(pins) do kinds[p.name] = p.kind end
    T.eq(kinds["Pack Smith"], "vendor")
    T.eq(kinds["Pack Inn"], "innkeeper")
    local _, second = ns.POI.Describe(pins[1].poi, "Vendor")
    T.contains(second, "unverified")
  end)

  T.it("/ride near uses the pack too", function()
    local game, ns = session(true)
    game:slash("near inn")
    T.eq(ns.Waypoints.current.title, "Pack Inn")
  end)

  T.it("an NPC Gary visited himself replaces the pack copy", function()
    local game, ns = session(true)
    ns.db.global.pois["npc-9101-vendor"] = { id = "npc-9101-vendor", kind = "vendor", mapID = 1412, x = 0.471, y = 0.371, npcID = 9101, name = "Pack Smith", verified = false }
    if ns.MapPins then ns.MapPins:Invalidate() end -- placed directly, as the addon's own writers then do
    local n = 0
    for _, p in ipairs(ns.MapPins:PinsFor(1412)) do if p.npcID == 9101 then n = n + 1 end end
    T.eq(n, 1)
  end)
end)
