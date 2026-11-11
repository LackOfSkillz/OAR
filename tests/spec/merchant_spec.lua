-- Merchant helper (P5-09). Items are test data.
local T, mock = ...

local function session()
  local game = mock.new()
  game.items = { [1] = { name = "Broken Fang", quality = 0, sell = 10 }, [2] = { name = "Linen Cloth", quality = 1, sell = 13 } }
  game.bags = { [0] = {} }
  for i = 1, 15 do game.bags[0][i] = 1 end
  game.bags[0][16] = 2
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  return game, ns
end

T.describe("merchant helper", function()
  T.it("shows the panel at a vendor and sells only greys, 12 per click", function()
    local game, ns = session()
    game:fire("MERCHANT_SHOW")
    local f = ns.Merchant.frame
    T.ok(f:IsShown())
    T.contains(f.sell.label:GetText(), "Sell junk (15,")
    f.sell.__scripts.OnClick(f.sell)
    T.eq(#game.sold, 12)
    for _, id in ipairs(game.sold) do T.eq(id, 1) end
    f.sell.__scripts.OnClick(f.sell)
    T.eq(#game.sold, 15)
    T.eq(game.bags[0][16], 2, "white item untouched")
  end)

  T.it("repairs on click and never on open", function()
    local game, ns = session()
    game.repairCost = 1234
    game:fire("MERCHANT_SHOW")
    T.eq(game.repaired, nil)
    T.contains(ns.Merchant.frame.repair.label:GetText(), "Repair (12s 34c)")
    ns.Merchant.frame.repair.__scripts.OnClick(ns.Merchant.frame.repair)
    T.ok(game.repaired)
    T.eq(#ns.Errors.list, 0)
  end)
end)
