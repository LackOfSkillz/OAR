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
    game.bags[1] = { [1] = 3, [2] = 4, [3] = 5 }
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
    T.eq(game.bags[1][1], nil)
    T.eq(game.bags[1][2], 4)
    T.eq(game.bags[1][3], 5)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("sell once applies to only one stack and then clears", function()
    local game, ns = session()
    game.items[3] = { name = "Old Dagger", quality = 1, sell = 100 }
    for i = 1, 15 do game.bags[0][i] = nil end
    game.bags[1] = { [1] = 3, [2] = 3 }
    game:slash("sell once 3")
    T.eq(#ns.Merchant:Junk(), 2)
    local sold = ns.Merchant:SellJunk()
    T.eq(sold, 1)
    T.eq(game.bags[1][1], nil)
    T.eq(game.bags[1][2], 3)
    T.eq(ns.Merchant:Settings().sellOnce[3], nil)
  end)

  T.it("restocks only on click within a gold reserve; never on merchant open", function()
    local game, ns = session()
    game.items[8] = { name = "Arrows", quality = 1, buy = 200, bundle = 20 }
    game.items[9] = { name = "Bread", quality = 1, buy = 400, bundle = 5 }
    game.merchant = { 8, 9 }
    game.money = 30000
    game:slash("restock add 8 100")
    game:slash("restock add 9 15")
    game:slash("restock reserve 2")
    game:fire("MERCHANT_SHOW")
    T.eq(game.bought, nil, "opening a vendor never buys")
    local plan, price = ns.Merchant:RestockPlan()
    T.eq(#plan, 2)
    T.eq(price, 2200)
    ns.Merchant.frame.restock.__scripts.OnClick(ns.Merchant.frame.restock)
    T.eq(#game.bought, 2)
    T.eq(game.bought[1].count, 100)
    T.eq(game.bought[2].count, 15)
    T.eq(game.money, 27800)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("cannot spend reserved gold, buy restricted items, or purchase outside a vendor", function()
    local game, ns = session()
    game.items[8] = { name = "Arrows", quality = 1, buy = 2000, bundle = 20 }
    game.items[9] = { name = "Special", quality = 1, buy = 500, extended = true }
    game.merchant = { 8, 9 }
    game.money = 11000
    game:slash("restock add 8 200")
    game:slash("restock add 9 30")
    local count = ns.Merchant:Restock()
    T.eq(count, 0)
    game:fire("MERCHANT_SHOW")
    local plan = ns.Merchant:RestockPlan()
    T.eq(#plan, 0, "10g price exceeds free 1g budget; extended costs excluded")
    game:setCombat(true)
    T.eq(ns.Merchant:Restock(), 0)
    game:setCombat(false)
    T.eq(game.bought, nil)
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
