-- Modules/Deals.lua  (Gary, 2026-11-20: "our arbitrage scan, so that we could
-- buy things from the auction house and sell them other places or to vendors
-- for more")
-- Read from the last full price scan (Prices:FullScan keeps the cheapest few
-- listings of every item):
--   * Vendor flips: listings whose price per unit is under what a vendor
--     pays for the item. Buy them, sell them at any vendor: a sure profit.
--   * Resale: listings well under the item's usual auction price (the median
--     of its daily lows over the last two weeks, at least 3 days seen), after
--     the auction house's 5% cut and the deposit. Not sure: it has to sell.
-- Each Buy carries a price cap (AHBuy skips a listing that costs more now),
-- and every purchase still waits for Gary's click on the confirm bar.
-- Read only otherwise: no search or purchase of its own.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Deals", {
  title = "Auction deals (vendor flips and resale)",
  phase = "P5",
  order = 78,
  defaults = { minProfit = 100 }, -- copper: a deal under 1 silver isn't worth the click
})
ns.Deals = M

M.CUT = 0.05
M.RESALE_UNDER = 0.6  -- now at most 60% of the usual price
M.MIN_DAYS = 3        -- usual price from at least 3 days seen
M.TOP = 40

local function info(id) return C.ItemInfo(id) end

-- Stackable goods are bought by quantity (commodities); the rest one listing at a time.
function M.IsCommodity(itemID)
  local st = C.Call("C_AuctionHouse.GetItemCommodityStatus", itemID)
  local enum = C.Resolve("Enum.ItemCommodityStatus")
  if type(st) == "number" and st > 0 then
    if type(enum) == "table" and enum.Commodity then return st == enum.Commodity end
    return st == 2
  end
  local i = info(itemID)
  return i and type(i.maxStack) == "number" and i.maxStack > 1 or false
end

function M.ItemKey(itemID)
  local key = C.Call("C_AuctionHouse.MakeItemKey", itemID)
  if type(key) == "table" then return key end
  return { itemID = itemID, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 }
end

-- What to queue for AHBuy: never more than `maxUnit` a unit.
function M.Action(d)
  if d.commodity then
    return { { name = d.name, itemID = d.itemID, qty = d.qty, commodity = true, maxUnit = d.maxUnit } }
  end
  return { { name = d.name, itemKey = M.ItemKey(d.itemID), maxUnit = d.maxUnit } }
end

function M:Scan() return ns.Prices and ns.Prices.lastScan end

-- { {itemID, name, qty, cost, unit, vendor, profit, commodity, maxUnit} } best profit first
function M:VendorFlips()
  local scan = self:Scan()
  local out, loading = {}, 0
  if not scan then return out, loading end
  local min = self:Settings().minProfit or 100
  for itemID, list in pairs(scan.items or {}) do
    local i = info(itemID)
    if not i then loading = loading + 1
    elseif type(i.sellPrice) == "number" and i.sellPrice > 0 and list[1] and list[1][1] < i.sellPrice then
      local commodity = M.IsCommodity(itemID)
      local qty, cost, top = 0, 0, 0
      for _, l in ipairs(list) do
        if l[1] < i.sellPrice then
          qty, cost, top = qty + l[2], cost + l[1] * l[2], l[1]
          if not commodity then break end -- one listing per click for single items
        end
      end
      local profit = i.sellPrice * qty - cost
      if profit >= min then
        out[#out + 1] = { itemID = itemID, name = i.name, qty = qty, cost = cost, unit = math.floor(cost / qty),
          vendor = i.sellPrice, profit = profit, commodity = commodity, maxUnit = top, kind = "flip" }
      end
    end
  end
  table.sort(out, function(a, b) if a.profit ~= b.profit then return a.profit > b.profit end return a.itemID < b.itemID end)
  while #out > M.TOP do table.remove(out) end
  return out, loading
end

-- Listings well under the usual price: profit after the cut and deposit if it sells at the usual price.
function M:Resale()
  local scan = self:Scan()
  local out = {}
  if not scan or not ns.Prices then return out end
  local min = self:Settings().minProfit or 100
  local H = ns.AuctionHelper
  for itemID, list in pairs(scan.items or {}) do
    local stats = ns.Prices:Statistics(itemID)
    local l = list[1]
    if stats and stats.count >= M.MIN_DAYS and l and l[1] <= stats.median * M.RESALE_UNDER then
      local i = info(itemID)
      if i then
        local qty = l[2]
        local deposit = H and H.Deposit and (H:Deposit(itemID, qty) or 0) or 0
        local back = math.floor(stats.median * qty * (1 - M.CUT)) - deposit
        local cost = l[1] * qty
        local profit = back - cost
        -- a vendor flip already covers what sells to a vendor for more
        if profit >= min and not (type(i.sellPrice) == "number" and i.sellPrice > l[1]) then
          out[#out + 1] = { itemID = itemID, name = i.name, qty = qty, cost = cost, unit = l[1], usual = math.floor(stats.median),
            days = stats.count, profit = profit, commodity = M.IsCommodity(itemID), maxUnit = l[1], kind = "resale" }
        end
      end
    end
  end
  table.sort(out, function(a, b) if a.profit ~= b.profit then return a.profit > b.profit end return a.itemID < b.itemID end)
  while #out > M.TOP do table.remove(out) end
  return out
end

-- How long ago the scan was, in words.
function M:Age()
  local scan = self:Scan()
  if not scan then return nil end
  local m = math.floor((time() - scan.at) / 60)
  return m < 1 and "just now" or (m == 1 and "1 minute ago") or string.format("%d minutes ago", m)
end

-- Shopping window cards: cards, status for "flips" | "resale"
function M:View(view)
  local money = ns.Prices.Money
  local age = self:Age()
  if not age then
    return {}, "Press Scan all prices (top right): Outrider reads every listing once, then shows what sells to a vendor for more, and what's listed well under its usual price."
  end
  local cards = {}
  if view == "flips" then
    local list, loading = self:VendorFlips()
    for _, d in ipairs(list) do
      cards[#cards + 1] = { itemID = d.itemID, item = { itemID = d.itemID }, title = d.name,
        sub = string.format("Buy %d at %s, a vendor pays %s each", d.qty, money(d.unit), money(d.vendor)),
        pill = "|cff7fff7f+" .. money(d.profit) .. "|r", price = d.cost, action = M.Action(d) }
    end
    local s = #cards > 0 and string.format("Sure profit: sell them at any vendor. From the price scan %s; listings sell fast, so a Buy skips any that cost more now.", age)
      or string.format("Nothing on the auction house sells to a vendor for more right now (price scan %s).", age)
    if loading > 0 then s = s .. string.format("  |cff8f96a6%d items still loading from the game.|r", loading) end
    return cards, s
  end
  for _, d in ipairs(self:Resale()) do
    cards[#cards + 1] = { itemID = d.itemID, item = { itemID = d.itemID }, title = d.name .. (d.qty > 1 and (" x" .. d.qty) or ""),
      sub = string.format("Usually %s (%d days seen), now %s: resell after the 5%% cut and deposit", money(d.usual), d.days, money(d.unit)),
      pill = "|cffffd100+" .. money(d.profit) .. "|r", price = d.cost, action = M.Action(d) }
  end
  return cards, #cards > 0 and string.format("Not sure: the profit comes once it sells again at its usual price. From the price scan %s.", age)
    or string.format("Nothing listed well under its usual price right now (price scan %s; prices need %d days of history).", age, M.MIN_DAYS)
end

function M:OnEnable()
  self:On("OTR_PRICES_SCAN", function(mod, _, what)
    if what == "done" then
      local flips = mod:VendorFlips()
      mod:Info("deals after the price scan: %d vendor flips, %d resale", #flips, #mod:Resale())
    end
  end)
end

function M:Activity()
  local age = self:Age()
  if not age then return "no price scan yet: Scan all prices at the auction house" end
  return string.format("%d vendor flips, %d resale (price scan %s)", #(self:VendorFlips()), #self:Resale(), age)
end
