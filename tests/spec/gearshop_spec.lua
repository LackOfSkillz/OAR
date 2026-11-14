-- Gear upgrades at the auction house: weapons (top 10) and armor (best per
-- slot), only what this class wears and what the gold covers; Buy goes
-- through the confirm bar (AHBuy), one confirmed click per purchase.
local T, mock = ...

local function session(money)
  local game = mock.new({ level = 15 })
  game.money = money or 100000
  game.items = {
    [101] = { name = "Old Bow", equipLoc = "INVTYPE_RANGED", class = 2, subclass = 2 },
    [301] = { name = "Worn Vest", equipLoc = "INVTYPE_CHEST", class = 4, subclass = 2 },
    [401] = { name = "Fine Vest", equipLoc = "INVTYPE_CHEST", class = 4, subclass = 2 },
    [402] = { name = "Okay Vest", equipLoc = "INVTYPE_CHEST", class = 4, subclass = 2 },
    [403] = { name = "Silk Robe", equipLoc = "INVTYPE_CHEST", class = 4, subclass = 1 },
    [404] = { name = "Golden Vest", equipLoc = "INVTYPE_CHEST", class = 4, subclass = 2 },
    [501] = { name = "Leather Cap", equipLoc = "INVTYPE_HEAD", class = 4, subclass = 2 },
    [601] = { name = "Great Bow", equipLoc = "INVTYPE_RANGED", class = 2, subclass = 2 },
    [602] = { name = "Holy Wand", equipLoc = "INVTYPE_RANGEDRIGHT", class = 2, subclass = 19 },
  }
  game.itemStats = {
    [101] = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 5 },
    [301] = { ITEM_MOD_AGILITY_SHORT = 2 },
    [401] = { ITEM_MOD_AGILITY_SHORT = 6 },
    [402] = { ITEM_MOD_AGILITY_SHORT = 4 },
    [403] = { ITEM_MOD_AGILITY_SHORT = 30 },
    [404] = { ITEM_MOD_AGILITY_SHORT = 40 },
    [501] = { ITEM_MOD_AGILITY_SHORT = 3 },
    [601] = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 9 },
    [602] = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 20 },
  }
  game.worn = { [18] = 101, [5] = 301 }
  game.ahListings = {
    [401] = { name = "Fine Vest", minPrice = 5000, class = 4, invType = 5 },
    [402] = { name = "Okay Vest", minPrice = 1000, class = 4, invType = 5 },
    [403] = { name = "Silk Robe", minPrice = 500, class = 4, invType = 5 },
    [404] = { name = "Golden Vest", minPrice = 250000, class = 4, invType = 5 },
    [501] = { name = "Leather Cap", minPrice = 800, class = 4, invType = 1 },
    [601] = { name = "Great Bow", minPrice = 3000, class = 2 },
    [602] = { name = "Holy Wand", minPrice = 200, class = 2 },
  }
  game.ahAuctions = { [401] = { { 9001, 5200 }, { 9002, 5000 } }, [501] = { { 9003, 800 } }, [601] = { { 9004, 3000 } } }
  local ns = game:loadAddon()
  game:login()
  game:fire("AUCTION_HOUSE_SHOW")
  return game, ns
end

local function search(game, ns, mode)
  ns.GearShop:Start(mode)
  local guard = 0
  while ns.GearShop.queue and guard < 30 do guard = guard + 1 game:fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED") end
  local by = {}
  for _, b in ipairs((ns.GearShop:Results())) do by[b.slotName] = by[b.slotName] or b by[b.itemID] = b end
  return by
end

T.describe("gear shop", function()
  T.it("armor: the best affordable piece of the class's own armor type per slot", function()
    local game, ns = session(100000) -- 10 gold
    local by = search(game, ns, "armor")
    T.eq(by.chest and by.chest.itemID, 401, "Fine Vest: best leather the gold covers")
    T.eq(by[403], nil, "no cloth for a hunter")
    T.eq(by[404], nil, "25 gold is more than 10 gold")
    T.eq(by.head and by.head.itemID, 501, "fills the empty head slot")
    local _, skipped = ns.GearShop:Results()
    T.eq(skipped, 1)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("weapons: only weapon types the class uses", function()
    local game, ns = session()
    local by = search(game, ns, "weapons")
    T.ok(by[601], "a bow for a hunter")
    T.eq(by[602], nil, "no wand for a hunter")
  end)

  T.it("Buy looks up the cheapest listing; the confirm click buys it", function()
    local game, ns = session()
    search(game, ns, "armor")
    local row
    for _, r in ipairs(ns.GearShop.frame.rows) do if r.item and r.item.itemID == 401 then row = r end end
    T.ok(row, "Fine Vest row")
    ns.AHBuy:Add({ name = row.item.name, itemKey = row.item.itemKey })
    game:fire("ITEM_SEARCH_RESULTS_UPDATED")
    T.contains(ns.AHBuy.frame.text:GetText(), "Fine Vest: 50s")
    ns.AHBuy:Confirm()
    T.eq(game.bought[1].id, 9002)
    T.eq(game.bought[1].price, 5000)
    T.eq(ns.AHBuy.current, nil)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("never buys past the gold carried", function()
    local game, ns = session(2000)
    ns.AHBuy:Add({ name = "Fine Vest", itemKey = { itemID = 401 } })
    game:fire("ITEM_SEARCH_RESULTS_UPDATED")
    ns.AHBuy:Confirm()
    T.eq(game.bought, nil)
    T.contains(game:chatText(), "more than you carry")
  end)

  T.it("stackable training goods: price quote for the amount, then confirm", function()
    local game, ns = session()
    ns.AHBuy:Add({ name = "Silverleaf", itemID = 765, qty = 20, commodity = true })
    T.eq(game.commodityStart.qty, 20)
    game:fire("COMMODITY_PRICE_UPDATED", 10, 200)
    T.contains(ns.AHBuy.frame.text:GetText(), "Silverleaf x20: 2s")
    ns.AHBuy:Confirm()
    T.eq(game.bought[1].commodity, 765)
    T.eq(game.bought[1].qty, 20)
  end)
end)
