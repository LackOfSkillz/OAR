-- Auction deals from the full price scan (Gary, 2026-11-20: buy from the
-- auction house, sell to vendors or elsewhere for more).
local T, mock = ...

local function session()
  local game = mock.new({ now = 1794700000 })
  game.money = 1000000
  game.items = {
    [10] = { name = "Cheap Junk", sell = 500, maxStack = 20 },      -- vendor pays 5s
    [11] = { name = "Fair Sword", sell = 100, maxStack = 1 },       -- vendor pays 1s
    [12] = { name = "Rare Cloak", sell = 50, maxStack = 1 },        -- usually 10g
    [13] = { name = "Tiny Flip", sell = 12, maxStack = 20 },        -- profit under 1s
  }
  -- full scan listings: { itemID, count, buyout }
  game.replicate = {
    { 10, 10, 2000 },   -- 10 at 2s each: vendor pays 5s each -> +30s
    { 10, 5, 4000 },    -- 5 at 8s each: over vendor price, left out
    { 11, 1, 5000 },    -- 50s, vendor 1s: no
    { 12, 1, 20000 },   -- 2g, usually 10g
    { 13, 5, 50 },      -- 10c each, vendor 12c: +10c total, under the 1s minimum
  }
  local ns = game:loadAddon()
  game:login()
  game:fire("AUCTION_HOUSE_SHOW")
  -- two weeks of history for the cloak at 10g
  for d = 1, 5 do ns.Prices.db[12] = ns.Prices.db[12] or {} table.insert(ns.Prices.db[12], { math.floor(game.env.time() / 86400) - 6 + d, 100000 }) end
  ns.Prices:FullScan()
  game:fire("REPLICATE_ITEM_LIST_UPDATE")
  game:advance(1)
  return game, ns
end

T.describe("auction deals", function()
  T.it("vendor flips: only listings under the vendor price, best profit first, small ones left out", function()
    local _, ns = session()
    local flips = ns.Deals:VendorFlips()
    T.eq(#flips, 1)
    T.eq(flips[1].name, "Cheap Junk")
    T.eq(flips[1].qty, 10, "the 8s listings cost more than a vendor pays")
    T.eq(flips[1].cost, 2000)
    T.eq(flips[1].profit, 3000)
    T.ok(flips[1].commodity, "stackable: bought by quantity")
    T.eq(flips[1].maxUnit, 200)
  end)

  T.it("resale: well under the usual price, after the cut and deposit", function()
    local _, ns = session()
    local list = ns.Deals:Resale()
    T.eq(#list, 1)
    T.eq(list[1].name, "Rare Cloak")
    T.eq(list[1].usual, 100000)
    T.ok(list[1].profit > 70000 and list[1].profit <= 75000, "10g less 5% less 2g, less any deposit: " .. list[1].profit)
  end)

  T.it("the shopping window's Profit section shows them with Buy all", function()
    local game, ns = session()
    local G = ns.GearShop
    G.open = true
    G:Pick("flips")
    T.contains(G.frame.rows[1].text:GetText(), "Cheap Junk")
    T.contains(G.frame.rows[1].stats:GetText(), "a vendor gives you")
    G:Pick("resale")
    T.contains(G.frame.rows[1].text:GetText(), "Rare Cloak")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a Buy never pays more than the deal: a gone listing is skipped", function()
    local game, ns = session()
    local d = ns.Deals:VendorFlips()[1]
    for _, e in ipairs(ns.Deals.Action(d)) do ns.AHBuy:Add(e) end
    game:fire("COMMODITY_PRICE_UPDATED", 400, 4000) -- now 4s each for the 10
    T.eq(ns.AHBuy.current, nil, "skipped")
    T.eq(game.bought, nil)
    T.contains(game:chatText(), "the cheap listings are gone")
    ns.AHBuy:Add(ns.Deals.Action(d)[1])
    game:fire("COMMODITY_PRICE_UPDATED", 200, 2000)
    ns.AHBuy:Confirm()
    T.eq(game.bought[1].qty, 10)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("works the lists out once per price scan, not on every redraw (lag at the auction house)", function()
    local _, ns = session()
    local D = ns.Deals
    local calls = 0
    local real = D.ComputeFlips
    D.ComputeFlips = function(self) calls = calls + 1 return real(self) end
    D.cache = nil
    local a = D:VendorFlips()
    local b = D:VendorFlips()
    T.eq(calls, 1, "the second call reuses the first")
    T.eq(#a, #b)
    ns.Prices.lastScan = { at = 1, items = ns.Prices.lastScan.items }
    D:VendorFlips()
    T.eq(calls, 2, "a new scan works it out again")
    D.ComputeFlips = real
  end)

  T.it("a bag's slot count is read from its tooltip once, not on every redraw", function()
    local game = mock.new()
    game.items = { [804] = { name = "Large Blue Sack" } }
    local reads = 0
    game.itemTips = setmetatable({}, { __index = function(_, id)
      if id == 804 then reads = reads + 1 return { "Large Blue Sack", "10 Slot Bag" } end
    end })
    local ns = game:loadAddon()
    game:login()
    local G = ns.GearShop
    T.eq(G.BagSlotsOf(804), 10)
    T.eq(G.BagSlotsOf(804), 10)
    T.eq(reads, 1)
  end)

  T.it("before any scan it says to press Scan all prices", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    local cards, status = ns.Deals:View("flips")
    T.eq(#cards, 0)
    T.contains(status, "Scan all prices")
  end)
  T.it("items still loading after the scan show up once their details arrive, and a reload keeps the deals", function()
    local game = mock.new({ now = 1794700000 })
    game.items = {
      [10] = { name = "Cheap Junk", sell = 500, maxStack = 20 },
      [12] = { name = "Rare Cloak", sell = 50, maxStack = 1 },
    }
    game.replicate = { { 10, 10, 2000 }, { 12, 1, 20000 } }
    local ns = game:loadAddon()
    game:login()
    game:fire("AUCTION_HOUSE_SHOW")
    for d = 1, 5 do ns.Prices.db[12] = ns.Prices.db[12] or {} table.insert(ns.Prices.db[12], { math.floor(game.env.time() / 86400) - 6 + d, 100000 }) end
    -- Gary's case: right after the scan the game hasn't loaded these items yet
    local real = ns.Compat.ItemInfo
    ns.Compat.ItemInfo = function() return nil end
    ns.Prices:FullScan()
    game:fire("REPLICATE_ITEM_LIST_UPDATE")
    game:advance(1)
    T.eq(#ns.Deals:VendorFlips(), 0, "no vendor price known yet")
    local resale = ns.Deals:Resale()
    T.eq(#resale, 1, "a resale deal is a deal by price alone")
    T.eq(resale[1].name, "item 12")
    -- the details arrive
    ns.Compat.ItemInfo = real
    game.now = game.now + 12
    game:fire("GET_ITEM_INFO_RECEIVED", 10, true)
    game:advance(12)
    local flips = ns.Deals:VendorFlips()
    T.eq(#flips, 1, "the flip appears once the vendor price is known")
    T.eq(ns.Deals:Resale()[1].name, "Rare Cloak")
    -- a /reload loses the scan list, not the deals
    ns.Prices.lastScan = nil
    T.eq(#ns.Deals:VendorFlips(), 1)
    T.eq(#ns.Deals:Resale(), 1)
    T.ok(ns.Deals:Age(), "says how old the scan is")
    T.eq(#ns.Errors.list, 0)
  end)
  T.it("each deal says in plain words what you pay, what you get back and what you keep", function()
    local _, ns = session()
    local D = ns.Deals
    local flip = D:VendorFlips()[1]
    local line = D.FlipLine(flip)
    T.contains(line, "Pay 2s 0c each here")
    T.contains(line, "a vendor gives you 5s 0c each")
    T.contains(line, "you keep 30s 0c")
    local steps = table.concat(D.FlipSteps(flip), "\n")
    T.contains(steps, "1. Buy 10 of them here for 20s 0c (2s 0c each).")
    T.contains(steps, "2. Sell them to any vendor for 50s 0c (5s 0c each).")
    local r = D:Resale()[1]
    T.contains(D.ResaleLine(r), "Pay 2g 0s")
    T.contains(D.ResaleLine(r), "sell it here again for 10g 0s")
    local rs = table.concat(D.ResaleSteps(r), "\n")
    T.contains(rs, "the auction house keeps 50s 0c (5%)")
    T.contains(rs, "Don't sell it to a vendor: they pay only 50c.")
    T.eq(#ns.Errors.list, 0)
  end)
  T.it("deals fit your gold: part of a stack you can afford first, the rest grayed at the bottom", function()
    local game, ns = session()
    local D = ns.Deals
    game.money = 1100 -- 11s: six of the 2s junk, not the 2g cloak
    local cards, status = D:View("flips")
    T.eq(#cards, 1)
    T.eq(cards[1].title, "Cheap Junk x5", "5 at 2s each is all 11s buys")
    T.eq(cards[1].price, 1000)
    T.eq(cards[1].action[1].qty, 5, "Buy takes the amount you can afford")
    T.contains(table.concat(cards[1].tip, "\n"), "You can afford 5 of the 10 listed")
    cards, status = D:View("resale")
    T.eq(#cards, 1)
    T.ok(cards[1].dim, "the cloak is grayed")
    T.eq(cards[1].action, nil, "no Buy on what you can't afford")
    T.contains(cards[1].sub, "you need")
    T.contains(status, "grayed out")
    game.money = 1000000
    cards = D:View("resale")
    T.ok(not cards[1].dim)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a market that dropped isn't a resale deal, and part of a cheap listing never is (Thorium arrows, 2026-11-23)", function()
    local function arrows(replicate, money)
      local game = mock.new({ now = 1794700000 })
      game.money = money
      game.items = { [18042] = { name = "Thorium Headed Arrow", sell = 10, maxStack = 200 } }
      game.commodities = { [18042] = true }
      game.replicate = replicate
      local ns = game:loadAddon()
      game:login()
      game:fire("AUCTION_HOUSE_SHOW")
      local today = math.floor(game.env.time() / 86400)
      ns.Prices.db[18042] = { { today - 2, 80 }, { today - 1, 79 } }
      ns.Prices:FullScan()
      game:fire("REPLICATE_ITEM_LIST_UPDATE")
      game:advance(1)
      return game, ns
    end
    -- the whole market at 35c: two sellers at 35c each
    local _, ns = arrows({ { 18042, 3400, 119000 }, { 18042, 1600, 56000 } }, 1000000)
    T.eq(#ns.Deals:Resale(), 0, "the next seller asks 35c too: nothing to sell again for more")
    -- one cheap listing, the next seller at 79c: a real deal when you buy it all...
    local _, ns2 = arrows({ { 18042, 200, 7000 }, { 18042, 500, 39500 } }, 1000000)
    local list = ns2.Deals:Resale()
    T.eq(#list, 1)
    T.eq(list[1].sellUnit, 78, "just under the next seller")
    -- ...but not when your gold only covers part of it: the rest still sells at 35c
    local _, ns3 = arrows({ { 18042, 200, 7000 }, { 18042, 500, 39500 } }, 3185)
    local cards = ns3.Deals:View("resale")
    T.eq(#cards, 0, "91 of 200 at 35c would have to compete with the other 109")
  end)
end)
