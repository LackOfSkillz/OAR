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
    T.contains(f.sell.label:GetText(), "Sell approved (15,")
    f.sell.__scripts.OnClick(f.sell)
    T.eq(#game.sold, 12)
    for _, id in ipairs(game.sold) do T.eq(id, 1) end
    f.sell.__scripts.OnClick(f.sell)
    T.eq(#game.sold, 15)
    T.eq(game.bags[0][16], 2, "white item untouched")
  end)

  T.it("explicitly allowed items sell, while quest and keep items remain safe", function()
    local game, ns = session()
    game.items[3] = { name = "Old Dagger", quality = 1, sell = 100 }
    game.items[4] = { name = "Quest Relic", quality = 1, sell = 200 }
    game.items[5] = { name = "Family Trinket", quality = 1, sell = 300 }
    game.bags[0][17], game.bags[0][18], game.bags[0][19] = 3, 4, 5
    game.questItems = { [4] = true }
    game:slash("sell always 3")
    game:slash("sell always 4")
    game:slash("sell keep 5")
    local count = {}
    for _, c in ipairs(ns.Merchant:Junk()) do count[c.id] = (count[c.id] or 0) + 1 end
    T.eq(count[1], 15)
    T.eq(count[3], 1)
    T.eq(count[4], nil)
    T.eq(count[5], nil)
    game:fire("MERCHANT_SHOW")
    ns.Merchant:SellJunk()
    ns.Merchant:SellJunk()
    T.eq(game.bags[0][17], nil)
    T.eq(game.bags[0][18], 4)
    T.eq(game.bags[0][19], 5)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("sell once applies to only one stack and then clears", function()
    local game, ns = session()
    game.items[3] = { name = "Old Dagger", quality = 1, sell = 100 }
    for i = 1, 15 do game.bags[0][i] = nil end
    game.bags[0][17], game.bags[0][18] = 3, 3
    game:slash("sell once 3")
    T.eq(#ns.Merchant:Junk(), 2)
    local sold = ns.Merchant:SellJunk()
    T.eq(sold, 1)
    T.eq(game.bags[0][17], nil)
    T.eq(game.bags[0][18], 3)
    T.eq(ns.Merchant:Settings().sellOnce[3], nil)
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
