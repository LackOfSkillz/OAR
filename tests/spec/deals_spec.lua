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
    T.contains(G.frame.rows[1].stats:GetText(), "a vendor pays")
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
end)
