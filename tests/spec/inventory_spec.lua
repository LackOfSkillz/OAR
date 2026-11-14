-- Inventory across characters (P5-01). Items are test data.
local T, mock = ...

T.describe("inventory", function()
  T.it("counts bags and bank per character and merges them in the tooltip", function()
    local game = mock.new()
    game.bags = { [0] = { 2318, 2318 }, [-1] = { 2318 } }
    game.counts = { [0] = { 8, 4 }, [-1] = { 3 } }
    local ns = game:loadAddon()
    game:login()
    game:fire("BANKFRAME_OPENED")
    local inv = ns.db.global.inventory["Torrant-Forever"]
    T.eq(inv.bags[2318], 12)
    T.eq(inv.bank[2318], 3)

    local g2 = mock.new({ name = "Lumen", class = "PRIEST", savedVariables = game:logout() })
    g2.bags = { [0] = { 2318 } }
    g2.counts = { [0] = { 4 } }
    local ns2 = g2:loadAddon()
    g2:login()
    local lines = ns2.Inventory:TooltipLines(2318)
    T.eq(lines[1], "You have 19 (Torrant 15, Lumen 4)")
    local detail = ns2.Inventory:TooltipLines(2318, true)
    T.eq(detail[2], "  Torrant: bags 12, bank 3")
  end)

  T.it("items nobody owns add no line; bag changes are throttled", function()
    local game = mock.new()
    game.bags = { [0] = { 2318 } }
    local ns = game:loadAddon()
    game:login()
    T.same(ns.Inventory:TooltipLines(9999), {})
    game.bags[0][2] = 2318
    for _ = 1, 10 do game:fire("BAG_UPDATE_DELAYED") end
    game:advance(2)
    T.eq(ns.db.global.inventory["Torrant-Forever"].bags[2318], 10)
    T.eq(#ns.Errors.list, 0)
  end)
end)
