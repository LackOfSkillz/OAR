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

function M:Record(itemID, copper)
  if type(itemID) ~= "number" or type(copper) ~= "number" or copper <= 0 then return end
  local h = self.db[itemID]
  if not h then h = {} self.db[itemID] = h end
  local d = today()
  local last = h[#h]
  if last and last[1] == d then
    if copper < last[2] then last[2] = copper end
  else
    h[#h + 1] = { d, copper }
  end
  while #h > 0 and h[1][1] < d - self.DAYS do table.remove(h, 1) end
  self.seen = (self.seen or 0) + 1
end

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
    self:Record(id, C.Readable(r.minPrice))
  end
  self:Debug("AH browse: %d results", #results)
end

function M:OnCommodity(_, itemID)
  local info = C.Call("C_AuctionHouse.GetCommoditySearchResultInfo", itemID, 1)
  if type(info) == "table" then self:Record(itemID, C.Readable(info.unitPrice)) end
end

-- Full auction house scan (Gary, 2026-11-14: "no loss of functionality
-- without the other addons"): Auctionator and TSM keep whole-market prices;
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
  local mins, i, listings = {}, 0, 0
  local function step()
    local last = math.min(n - 1, i + M.SCAN_CHUNK - 1)
    for k = i, last do
      local ok, _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = pcall(info, k)
      if not ok then count = nil end
      count, buyout, itemID = C.Readable(count), C.Readable(buyout), C.Readable(itemID)
      if type(itemID) == "number" and type(buyout) == "number" and buyout > 0 and type(count) == "number" and count > 0 then
        local per = math.floor(buyout / count)
        if not mins[itemID] or per < mins[itemID] then mins[itemID] = per end
        listings = listings + 1
      end
    end
    i = last + 1
    if i < n then ns.Timer.After(0, step, "prices:scanstep") return end
    local items = 0
    for id, p in pairs(mins) do M:Record(id, p) items = items + 1 end
    M.scanning, M.reading = nil, nil
    M:Info("full price scan: %d listings, %d items priced", listings, items)
    ns.Print("price scan done: %d items priced", items)
    ns.Events:Fire("OTR_PRICES_SCAN", "done", items)
  end
  step()
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
ns.TooltipLines:Add("item", "value", M, function(_, data)
  local id = data and C.Readable(data.id)
  if type(id) ~= "number" then return nil end
  local out = {}
  for _, l in ipairs(M:TooltipLines(id)) do out[#out + 1] = { l, "muted" } end
  return out
end)

function M:Activity()
  local n = 0
  for _ in pairs(self.db) do n = n + 1 end
  return string.format("%d items priced from the auction house; vendor prices from the game", n)
end
