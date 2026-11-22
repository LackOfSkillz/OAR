-- Selling at the auction house (Gary, 2026-11-22: match Auctionator): one
-- click posts at just under the lowest price now, a low price needs a second
-- click, undercut auctions are marked and cancelled one click each.
local T, mock = ...

local function session()
  local game = mock.new({ level = 20 })
  game.items = {
    [2589] = { name = "Linen Cloth", quality = 1, sell = 13 },
    [2318] = { name = "Light Leather", quality = 1, sell = 15 },
    [7001] = { name = "Bloody Bracers", quality = 2, sell = 500 },
    [7002] = { name = "Soulbound Belt", quality = 2, sell = 400, bind = 1 },
    [7003] = { name = "Quest Rock", quality = 1, sell = 0 },
    [7004] = { name = "Broken Tooth", quality = 0, sell = 3 },
  }
  game.commodities = { [2589] = true, [2318] = true }
  game.bags = { [0] = { [1] = 2589, [2] = 2589, [3] = 7001, [4] = 7002, [5] = 7003, [6] = 7004, [7] = 2318 } }
  game.counts = { [0] = { [1] = 20, [2] = 7, [7] = 5 } }
  game.questItems = { [7003] = true }
  local ns = game:loadAddon()
  game:login()
  game:fire("AUCTION_HOUSE_SHOW")
  return game, ns
end

-- answer the sell module's lookups until its queue is empty
local function answer(game, ns)
  local S = ns.AuctionSell
  local guard = 0
  while S.looking and guard < 20 do
    guard = guard + 1
    local g = S.looking
    if g.commodity then game:fire("COMMODITY_SEARCH_RESULTS_UPDATED", g.itemID)
    else game:fire("ITEM_SEARCH_RESULTS_UPDATED", g.itemKey) end
    if S.looking == g then S.looking = nil end
    S:Pump()
  end
end

T.describe("selling at the auction house", function()
  T.it("reads typed prices like 1g 50s, 30s, 75c and a bare number as gold", function()
    local _, ns = session()
    local P = ns.AuctionSell.ParseMoney
    T.eq(P("1g 50s"), 15000)
    T.eq(P("30s"), 3000)
    T.eq(P("75c"), 75)
    T.eq(P("2"), 20000)
    T.eq(P("1.5g"), 15000)
    T.eq(P("3s20c"), 320)
    T.eq(P(""), nil)
    T.eq(P("lots"), nil)
    T.eq(P("5x"), nil)
  end)

  T.it("lists only what can go on the auction house, one card per item with the whole count", function()
    local _, ns = session()
    local list = ns.AuctionSell:Stacks()
    local by = {}
    for _, g in ipairs(list) do by[g.itemID] = g end
    T.ok(by[2589], "linen cloth")
    T.eq(by[2589].count, 27, "both stacks added up")
    T.eq(#by[2589].stacks, 2)
    T.ok(by[2589].commodity, "cloth is stackable goods")
    T.ok(by[7001] and not by[7001].commodity, "the bracers are one item")
    T.eq(by[7002], nil, "bound items can't be sold")
    T.eq(by[7003], nil, "quest items can't")
    T.eq(by[7004], nil, "grey items go to a vendor")
    ns.AuctionSell:Hidden()[2318] = true
    local after, hidden = ns.AuctionSell:Stacks()
    T.eq(hidden, 1, "right-click hides one")
    for _, g in ipairs(after) do T.ok(g.itemID ~= 2318) end
  end)

  T.it("prices just under the lowest someone else asks now, and keeps yours if you're already lowest", function()
    local game, ns = session()
    local S = ns.AuctionSell
    game.commodityList = { [2589] = { { 90, 40, 40 }, { 100, 200, 0, { "Seller" } }, { 120, 10, 0 } } }
    local list = S:Stacks()
    S:Look(list)
    answer(game, ns)
    local live = S:Live(2589)
    T.ok(live, "looked up")
    T.eq(live.low, 100, "your own 90s listing isn't someone else's price")
    T.eq(live.mine, 90)
    T.eq(live.lowOwner, "Seller")
    local linen
    for _, x in ipairs(list) do if x.itemID == 2589 then linen = x end end
    local p = S:Price(linen)
    T.eq(p.price, 90, "already the lowest: same price, no undercutting yourself")
    game.commodityList[2589] = { { 100, 200, 0 } }
    S.live = {}
    S:Look(list)
    answer(game, ns)
    local g
    for _, x in ipairs(list) do if x.itemID == 2589 then g = x end end
    T.eq(S:Price(g).price, 98, "2% under the lowest (the /ride undercut rule)")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("Post puts up the whole amount of stackable goods (Ctrl: one stack) and remembers the price", function()
    local game, ns = session()
    local S = ns.AuctionSell
    game.commodityList = { [2589] = { { 100, 200, 0 } } }
    local g
    for _, x in ipairs(S:Stacks()) do if x.itemID == 2589 then g = x end end
    S:Look({ g })
    answer(game, ns)
    S:Click(g, false)
    T.eq(#(game.posted or {}), 1, "posted")
    local p = game.posted[1]
    T.eq(p.kind, "commodity")
    T.eq(p.qty, 27)
    T.eq(p.price, 98)
    T.eq(p.duration, 2, "24 hours unless changed")
    T.eq(ns.db.global.postHistory[2589][1].unit, 98, "kept for next time")
    S:Click(g, true)
    T.eq(game.posted[2].qty, 20, "Ctrl-click: one stack")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a price under the floor or half the usual needs a second click", function()
    local game, ns = session()
    local S = ns.AuctionSell
    local g
    for _, x in ipairs(S:Stacks()) do if x.itemID == 7001 then g = x end end
    game.ahAuctions = { [7001] = { { 1, 200 } } } -- someone asks 2s, a vendor pays 5s
    S:Look({ g })
    answer(game, ns)
    local p = S:Price(g)
    T.ok(p.risky, "under the vendor price")
    S:Click(g, false)
    T.eq(#(game.posted or {}), 0, "first click only warns")
    S:Click(g, false)
    T.eq(#game.posted, 1, "second click posts")
    T.eq(game.posted[1].kind, "item")
    T.eq(game.posted[1].qty, 1)
  end)

  T.it("your own price for an item wins and is kept", function()
    local game, ns = session()
    local S = ns.AuctionSell
    S:SetPrice(7001, 25000)
    local g
    for _, x in ipairs(S:Stacks()) do if x.itemID == 7001 then g = x end end
    T.eq(S:Price(g).price, 25000)
    S:Click(g, false)
    T.eq(game.posted[1].price, 25000)
  end)

  T.it("my auctions: undercut ones are marked, and Cancel next takes one down", function()
    local game, ns = session()
    local S = ns.AuctionSell
    game.owned = {
      { auctionID = 501, itemKey = { itemID = 2589 }, buyoutAmount = 120, quantity = 20, status = 0, timeLeftSeconds = 7200 },
      { auctionID = 502, itemKey = { itemID = 7001 }, buyoutAmount = 30000, quantity = 1, status = 0 },
      { auctionID = 503, itemKey = { itemID = 2318 }, buyoutAmount = 50, quantity = 5, status = 1 },
    }
    game.commodityList = { [2589] = { { 100, 50, 0 }, { 120, 20, 20 } } }
    game.ahAuctions = { [7001] = { { 1, 40000 } } }
    S:CheckOwned()
    answer(game, ns)
    local by = {}
    for _, a in ipairs(S:Owned()) do by[a.auctionID] = a end
    T.eq(by[501].state, "undercut")
    T.eq(by[502].state, "lowest")
    T.eq(by[503].state, "sold")
    T.eq(#S:Undercuts(), 1)
    ns.AuctionHelper.open = true
    S:CancelNext()
    T.eq(game.cancelled and game.cancelled[1], 501)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("the shopping window shows Sell bags and My auctions with Post and Cancel buttons", function()
    local game, ns = session()
    local G = ns.GearShop
    game.owned = { { auctionID = 501, itemKey = { itemID = 2589 }, buyoutAmount = 120, quantity = 20, status = 0 } }
    G:Pick("sell")
    T.eq(G.mode, "sell")
    local f = G.frame
    local shown = 0
    for _, card in ipairs(f.rows) do if card:IsShown() and card.custom then shown = shown + 1 end end
    T.ok(shown >= 3, "a Post card per item")
    T.eq(f.rows[1].buy.label:GetText(), "Post")
    G:Pick("auctions")
    T.ok(game.ownedQueries and game.ownedQueries > 0, "asks the game for your auctions")
    T.eq(f.rows[1].buy.label:GetText(), "Cancel")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("the bound key posts the top item; nothing posts with the auction house closed", function()
    local game, ns = session()
    local S = ns.AuctionSell
    ns.db.global.sellPrices[2318] = 300
    ns.db.global.sellPrices[2589] = 200
    ns.db.global.sellPrices[7001] = 30000
    S:PostNext()
    T.eq(#(game.posted or {}), 1)
    game:fire("AUCTION_HOUSE_CLOSED")
    S:PostNext()
    T.eq(#game.posted, 1)
  end)
end)
