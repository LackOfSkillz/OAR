-- Modules/Prices.lua  (P5-05)
-- ns.Prices:Get(itemID) -> ahPrice (copper or nil), source, vendorPrice.
-- Sources in order: Auctionator API, TSM, our own history, vendor price.
-- Our history: the lowest price seen per item per day while Gary browses or
-- searches the auction house (modern C_AuctionHouse events), 14 days kept,
-- in ns.db.global.prices[itemID] = { {day, copper}, ... }. Reading only:
-- nothing is bought or posted. Item tooltips show AH and vendor value, and
-- warn when the AH value is below vendor (Forever cut many vendor prices).

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Prices", {
  title = "Prices (auction and vendor)",
  phase = "P5",
  order = 72,
  defaults = {},
})
ns.Prices = M

M.DAYS = 14

function M:OnInitialize()
  local g = ns.db.global
  g.prices = type(g.prices) == "table" and g.prices or {}
  self.db = g.prices
end

local function today() return math.floor(time() / 86400) end

function M:Record(itemID, copper, qty)
  if type(itemID) ~= "number" or type(copper) ~= "number" or copper <= 0 then return end
  -- tracked items also keep hourly samples (PriceHistory)
  local PH = ns.PriceHistory
  if PH and PH.enabled and PH.store then ns.Safe("prices:history", PH.Seen, PH, itemID, copper, qty) end
  local h = self.db[itemID]
  if not h then h = {} self.db[itemID] = h end
  local d = today()
  local last = h[#h]
  if last and last[1] == d then
    if copper < last[2] then last[2] = copper end
  else
    h[#h + 1] = { d, copper }
  end
  while #h > 0 and h[1][1] < d - self.DAYS do ns.Archive:Put("prices", { id = itemID, row = table.remove(h, 1) }) end
  self.seen = (self.seen or 0) + 1
end

-- DEEP-37: historical trend engine. The existing 14-day store records the
-- *minimum* price observed each day, NOT a representative market sample.
-- Median and volatility describe those daily lows; never claim true volume,
-- liquidity or an average sales price.
function M:Statistics(itemID)
  local history = self.db[tonumber(itemID)]
  if type(history) ~= "table" or #history == 0 then return nil end
  local prices, earliest, latest = {}, nil, nil
  for _, row in ipairs(history) do
    local d, price = tonumber(row[1]), tonumber(row[2])
    if d and price and price > 0 then
      prices[#prices + 1] = price
      earliest = math.min(earliest or d, d)
      latest = math.max(latest or d, d)
    end
  end
  if #prices == 0 then return nil end
  table.sort(prices)
  local n = #prices
  local median = n % 2 == 1 and prices[(n + 1) / 2] or
    (prices[n / 2] + prices[n / 2 + 1]) / 2
  local sum, variance = 0, 0
  for _, price in ipairs(prices) do sum = sum + price end
  local mean = sum / n
  for _, price in ipairs(prices) do variance = variance + (price - mean) ^ 2 end
  local std = math.sqrt(variance / n)
  return { itemID = tonumber(itemID), count = n, days = (latest - earliest) + 1,
    median = median, low = prices[1], high = prices[n], mean = mean,
    volatility = mean > 0 and std / mean or nil,
    source = "14-day daily lowest observed auctions; not transaction volume" }
end

function M:ShoppingLists()
  ns.db.char.shoppingLists = type(ns.db.char.shoppingLists) == "table" and ns.db.char.shoppingLists or {}
  return ns.db.char.shoppingLists
end
function M:ShoppingGroups()
  ns.db.char.shoppingGroups = type(ns.db.char.shoppingGroups) == "table" and ns.db.char.shoppingGroups or {}
  return ns.db.char.shoppingGroups
end
function M:ShoppingAdd(group, itemID, quantity, target)
  if type(group) ~= "string" or group == "" or #group > 60 then return false end
  itemID, quantity, target = tonumber(itemID), tonumber(quantity), tonumber(target)
  if not itemID or itemID < 1 or not quantity or quantity < 1 or quantity > 9999 then return false end
  local lists = self:ShoppingLists()
  local key = group:lower()
  lists[key] = type(lists[key]) == "table" and lists[key] or {}
  local count = 0 for _ in pairs(lists[key]) do count = count + 1 end
  if count >= 200 and not lists[key][itemID] then return false end
  lists[key][itemID] = { id = itemID, quantity = math.floor(quantity), target = target,
    at = time() }
  return true
end
function M:ShoppingRows(group)
  local list = self:ShoppingLists()[tostring(group or ""):lower()] or {}
  local result = {}
  for id, rule in pairs(list) do
    local seen = self:Statistics(id)
    local price = self:Get(id)
    local target = tonumber(rule.target)
    result[#result + 1] = { id = id, quantity = rule.quantity,
      price = price, target = target, median = seen and seen.median or nil,
      volatility = seen and seen.volatility or nil,
      buyCandidate = target and type(price) == "number" and price <= target or false }
  end
  table.sort(result, function(a, b) return a.id < b.id end)
  return result
end

ns.AddCommand("market", "market <itemID> | add <group> <id> <qty> [targetCopper] | list <group> | groups", function(arg)
  arg = tostring(arg or "")
  if arg == "groups" then
    local names = {}
    for key in pairs(M:ShoppingLists()) do names[#names + 1] = key end
    table.sort(names)
    ns.Print("shopping groups: %s", table.concat(names, ", "))
    return
  end
  local group, id, qty, target = arg:match("^add%s+(%S+)%s+(%d+)%s+(%d+)%s*(%d*)$")
  if group then
    ns.Print(M:ShoppingAdd(group, id, qty, target ~= "" and target or nil)
      and "shopping target saved" or "invalid shopping target")
    return
  end
  local list = arg:match("^list%s+(%S+)$")
  if list then
    for _, item in ipairs(M:ShoppingRows(list)) do
      ns.Print("item %d x%d: market %s, median daily low %s%s", item.id, item.quantity,
        M.Money(item.price), M.Money(item.median),
        item.buyCandidate and " (at or under target; check live AH)" or "")
    end
    return
  end
  local id = tonumber(arg)
  if id then
    local stats = M:Statistics(id)
    if not stats then ns.Print("no historical auction prices observed for item %d", id) return end
    ns.Print("item %d: daily-low median %s; min %s; max %s; volatility %.1f%% across %d observed days",
      id, M.Money(stats.median), M.Money(stats.low), M.Money(stats.high),
      (stats.volatility or 0) * 100, stats.count)
  else ns.Print("usage: /ride market <itemID> | add|list|groups") end
end)

-- Lowest price within the window (cheapest recent listing).
function M:History(itemID)
  local h = self.db[itemID]
  if not h or #h == 0 then return nil end
  local best
  for _, e in ipairs(h) do if not best or e[2] < best then best = e[2] end end
  return best
end

function M:Get(itemID)
  local vendor
  local info = C.ItemInfo(itemID)
  if info then vendor = info.sellPrice end
  local api = rawget(_G, "Auctionator")
  if api and api.API and api.API.v1 and api.API.v1.GetAuctionPriceByItemID then
    local ok, v = pcall(api.API.v1.GetAuctionPriceByItemID, "Outrider", itemID)
    if ok and v then return v, "Auctionator", vendor end
  end
  local tsm = rawget(_G, "TSM_API")
  if tsm and tsm.GetCustomPriceValue then
    local ok, v = pcall(tsm.GetCustomPriceValue, "DBMarket", "i:" .. itemID)
    if ok and v then return v, "TSM", vendor end
  end
  local own = self:History(itemID)
  if own then return own, "seen at AH", vendor end
  return nil, nil, vendor
end

function M.Money(copper)
  if not copper then return "?" end
  local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  if g > 0 then return string.format("%dg %ds", g, s) end
  if s > 0 then return string.format("%ds %dc", s, c) end
  return string.format("%dc", c)
end

-- Money with the game's coin icons (like Auctionator: "12 [g] 5 [s]"), for
-- on-screen UI; M.Money stays plain text for chat and logs.
local COIN = "|TInterface\\MoneyFrame\\UI-%sIcon:0:0:1:0|t"
function M.Coins(copper)
  copper = math.floor(tonumber(copper) or 0)
  local neg = copper < 0
  if neg then copper = -copper end
  local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  local out = {}
  if g > 0 then out[#out + 1] = "|cffffd100" .. g .. "|r" .. COIN:format("Gold") end
  if s > 0 or g > 0 then out[#out + 1] = s .. COIN:format("Silver") end
  if g == 0 then out[#out + 1] = c .. COIN:format("Copper") end
  return (neg and "-" or "") .. table.concat(out, " ")
end

function M:TooltipLines(itemID)
  local ah, source, vendor = self:Get(itemID)
  if not ah and not vendor then return {} end
  local parts = {}
  if ah then parts[#parts + 1] = "AH " .. M.Money(ah) end
  if vendor and vendor > 0 then parts[#parts + 1] = "vendor " .. M.Money(vendor) end
  local lines = { table.concat(parts, " | ") }
  if ah and vendor and vendor > 0 and ah < vendor then lines[#lines + 1] = "Sells for more at a vendor" end
  return lines
end

-- AH scans the player triggers by browsing or searching.
function M:OnBrowse()
  local results = C.Call("C_AuctionHouse.GetBrowseResults")
  if type(results) ~= "table" then return end
  for _, r in ipairs(results) do
    local id = r.itemKey and r.itemKey.itemID
    self:Record(id, C.Readable(r.minPrice), C.Readable(r.totalQuantity))
  end
  self:Debug("AH browse: %d results", #results)
end

function M:OnCommodity(_, itemID)
  local info = C.Call("C_AuctionHouse.GetCommoditySearchResultInfo", itemID, 1)
  -- you looked this item up: track its price history (PriceHistory)
  if ns.PriceHistory and ns.PriceHistory.enabled and ns.PriceHistory.store then ns.PriceHistory:Watch(itemID, "search") end
  local total = C.Call("C_AuctionHouse.GetCommoditySearchResultsQuantity", itemID)
  if type(info) == "table" then self:Record(itemID, C.Readable(info.unitPrice), C.Readable(total)) end
end

-- Full auction house scan (requirement 2026-11-14: no loss of functionality
-- when other addons are absent): Auctionator and TSM keep whole-market prices;
-- this does the same from one click. C_AuctionHouse.ReplicateItems returns
-- every listing; the cheapest buyout per unit of each item is recorded.
-- Blizzard allows it once every 15 minutes. Reading only.
M.SCAN_GAP, M.SCAN_CHUNK, M.SCAN_WAIT = 15 * 60, 1000, 60

-- seconds until the next full scan is allowed (0 = now)
function M:ScanWait()
  local last = ns.db.global.lastFullScan
  if not last then return 0 end
  return math.max(0, M.SCAN_GAP - (time() - last))
end

function M:FullScan()
  if not self.open then ns.Print("open the auction house first") return false end
  if self.scanning then return false end
  local wait = self:ScanWait()
  if wait > 0 then
    ns.Print("full price scan: Blizzard allows one every 15 minutes (%d min left)", math.ceil(wait / 60))
    return false
  end
  local ok = pcall(C_AuctionHouse.ReplicateItems)
  if not ok then ns.Print("full price scan isn't available on this client") return false end
  self.scanning = time()
  ns.db.global.lastFullScan = time()
  self:Info("full price scan started")
  ns.Events:Fire("OTR_PRICES_SCAN", "started")
  ns.Timer.After(M.SCAN_WAIT, function()
    if M.scanning then M.scanning = nil M:Info("full price scan: no answer") ns.Events:Fire("OTR_PRICES_SCAN", "failed") end
  end, "prices:scanwait")
  return true
end

-- The whole list arrived: read it in chunks so the game doesn't stutter.
function M:OnReplicate()
  if not self.scanning or self.reading then return end
  local n = C.Call("C_AuctionHouse.GetNumReplicateItems") or 0
  -- C.Call keeps five return values; the item id is the 17th, so call it directly
  local info = C.Resolve("C_AuctionHouse.GetReplicateItemInfo")
  if type(info) ~= "function" then self.scanning = nil return end
  self.reading = true
  -- also the few cheapest listings of each item (Deals: vendor flips, resale)
  local mins, cheap, qty, i, listings = {}, {}, {}, 0, 0
  local function step()
    local last = math.min(n - 1, i + M.SCAN_CHUNK - 1)
    for k = i, last do
      local ok, _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = pcall(info, k)
      if not ok then count = nil end
      count, buyout, itemID = C.Readable(count), C.Readable(buyout), C.Readable(itemID)
      if type(itemID) == "number" and type(buyout) == "number" and buyout > 0 and type(count) == "number" and count > 0 then
        local per = math.floor(buyout / count)
        if not mins[itemID] or per < mins[itemID] then mins[itemID] = per end
        M.KeepCheap(cheap, itemID, per, count)
        qty[itemID] = (qty[itemID] or 0) + count
        listings = listings + 1
      end
    end
    i = last + 1
    if i < n then ns.Timer.After(0, step, "prices:scanstep") return end
    local items = 0
    for id, p in pairs(mins) do M:Record(id, p, qty[id]) items = items + 1 end
    M.lastScan = { at = time(), items = cheap }
    M.scanning, M.reading = nil, nil
    M:Info("full price scan: %d listings, %d items priced", listings, items)
    ns.Print("price scan done: %d items priced", items)
    ns.Events:Fire("OTR_PRICES_SCAN", "done", items)
  end
  step()
end

-- The cheapest few listings of an item, cheapest first: { {per, count}, ... }.
M.KEEP = 6
function M.KeepCheap(cheap, itemID, per, count)
  local list = cheap[itemID]
  if not list then list = {} cheap[itemID] = list end
  if #list >= M.KEEP and per >= list[#list][1] then return end
  local at = #list + 1
  for k = 1, #list do if per < list[k][1] then at = k break end end
  table.insert(list, at, { per, count })
  if #list > M.KEEP then table.remove(list) end
end

function M:OnEnable()
  self:On("AUCTION_HOUSE_SHOW", function(mod) mod.open = true end)
  self:On("REPLICATE_ITEM_LIST_UPDATE", self.OnReplicate)
  self:On("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", self.OnBrowse)
  self:On("COMMODITY_SEARCH_RESULTS_UPDATED", self.OnCommodity)
  self:On("AUCTION_HOUSE_CLOSED", function(mod)
    mod.open = false
    if (mod.seen or 0) > 0 then mod:Info("auction house: recorded %d prices this visit", mod.seen) mod.seen = 0 end
  end)
end

-- AH and vendor value through the shared ordered block (P7-05)
-- How many are in the bag stack the mouse is over (bag buttons only), or nil.
function M.StackCount(tip)
  local owner = tip and tip.GetOwner and tip:GetOwner()
  if not (owner and owner.GetBagID and owner.GetID) then return nil end
  local okB, bag = pcall(owner.GetBagID, owner)
  local okS, slot = pcall(owner.GetID, owner)
  if not (okB and okS and bag and slot) then return nil end
  local n = C.ItemCountAt(bag, slot)
  n = tonumber(C.Readable(n))
  return n and n > 1 and n or nil
end

ns.TooltipLines:Add("item", "value", M, function(tip, data)
  local id = data and C.Readable(data.id)
  if type(id) ~= "number" then return nil end
  -- Vendor and Auction on their own rows, the amount right-aligned with coin
  -- icons (gallery idea from Auctionator, 2026-11-18)
  local ah, _, vendor = M:Get(id)
  if not ah and not (vendor and vendor > 0) then return nil end
  local out = {}
  if vendor and vendor > 0 then out[#out + 1] = { "Vendor", "goldText", right = M.Coins(vendor) } end
  if ah then out[#out + 1] = { "Auction", "goldText", right = M.Coins(ah) } end
  -- the whole stack under the mouse (Auctionator shows it too)
  local n = M.StackCount(tip)
  if n and ah then out[#out + 1] = { "Auction x" .. n, "goldText", right = M.Coins(ah * n) }
  elseif n and vendor and vendor > 0 then out[#out + 1] = { "Vendor x" .. n, "goldText", right = M.Coins(vendor * n) } end
  if ah and vendor and vendor > 0 and ah < vendor then out[#out + 1] = { "Sells for more at a vendor", "warn" } end
  return out
end)

function M:Activity()
  local n = 0
  for _ in pairs(self.db) do n = n + 1 end
  return string.format("%d items priced from the auction house; vendor prices from the game", n)
end
