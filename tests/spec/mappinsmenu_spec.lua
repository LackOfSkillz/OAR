-- Show/hide Outrider pins from a "Pins" button on the world map (2026-11-17).
local T, mock = ...

T.describe("map pins menu", function()
  T.it("switches a group of pins or all of them off and on, for the world map and minimap", function()
    local game = mock.new({ mapID = 1412 })
    game.base.Outrider_DataMobs = { source = "test", maps = { [1412] = {
      { 701, "Slydris", 6, 6, 2, { 0.49, 0.52 } },
    } } }
    rawset(game.env, "Outrider_DataMobs", game.base.Outrider_DataMobs)
    local ns = game:loadAddon()
    game:login()
    local M = ns.MapPins
    local function rares()
      local n = 0
      for _, p in ipairs(M:PinsFor(1412)) do if p.kind == "rare" then n = n + 1 end end
      return n
    end
    T.eq(rares(), 1)
    M.map:Show()
    T.ok(M.button, "the Pins button is on the map")
    M:ToggleMenu()
    T.ok(M.menu:IsShown())
    T.eq(#M.menu.rows, #M.MENU + 1)
    M:SetGroup({ "rare" }, false)
    T.eq(rares(), 0)
    T.eq(M:GroupShown({ "rare" }), false)
    M:SetGroup({ "rare" }, true)
    T.eq(rares(), 1)
    M:SetAll(false)
    T.eq(#M:PinsFor(1412), 0, "all off")
    M:SetAll(true)
    T.eq(rares(), 1)
    T.eq(#ns.Errors.list, 0)
  end)
end)
