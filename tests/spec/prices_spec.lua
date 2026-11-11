-- Prices (P5-05) and ledger (P5-08). Items and prices are test data.
local T, mock = ...

local function session()
  local game = mock.new()
  game.items = { [2318] = { name = "Light Leather", sell = 15 }, [2589] = { name = "Linen Cloth", sell = 13 } }
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("prices", function()
  T.it("records the lowest AH price seen per day and shows AH and vendor in tooltips", function()
    local game, ns = session()
    game.browse = { { itemKey = { itemID = 2318 }, minPrice = 250 }, { itemKey = { itemID = 2589 }, minPrice = 9 } }
    game:fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
    game.browse = { { itemKey = { itemID = 2318 }, minPrice = 220 } }
    game:fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
    local ah, src, vendor = ns.Prices:Get(2318)
    T.eq(ah, 220)
    T.eq(src, "seen at AH")
    T.eq(vendor, 15)
    T.same(ns.Prices:TooltipLines(2318), { "AH 2s 20c | vendor 15c" })
    T.eq(ns.Prices:TooltipLines(2589)[2], "Sells for more at a vendor")
  end)

  T.it("money formats as gold/silver/copper", function()
    local _, ns = session()
    T.eq(ns.Prices.Money(123456), "12g 34s")
    T.eq(ns.Prices.Money(250), "2s 50c")
  end)
end)

T.describe("ledger", function()
  T.it("books money changes to the open window and logs the session at logout", function()
    local game, ns = session()
    game.money = 123456
    game:fire("MERCHANT_SHOW")
    game.money = 123456 + 500
    game:fire("PLAYER_MONEY")
    game:fire("MERCHANT_CLOSED")
    game.money = 123456 + 500 - 100
    game:fire("PLAYER_MONEY")
    local L = ns.Ledger
    T.eq(L.book["vendor"].gain, 500)
    T.eq(L.book["loot & quests"].spend, 100)
    game:logout()
    T.eq(ns.db.char.ledger[1].net, 400)
    T.eq(#ns.Errors.list, 0)
  end)
end)
